import SwiftUI
import AppKit

@main
struct GeniusTraderApp: App {
    var body: some Scene {
        MenuBarExtra {
            CryptoDashboardView()
                .frame(minWidth: 480, minHeight: 640)
        } label: {
            if let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "bitcoinsign.circle")
                    .font(.system(size: 14, weight: .regular))
            }
        }
    }
}

struct CryptoAsset: Identifiable, Hashable {
    let id: String
    let symbol: String
    let name: String
}

struct CryptoQuote: Hashable {
    let price: Double
    let change24h: Double?
    let high24h: Double?
    let low24h: Double?
    let marketCap: Double?
    let volume24h: Double?
    let updatedAt: Date
}

actor CryptoAPIClient {
    private struct SearchResponse: Decodable {
        let coins: [Coin]
    }

    private struct Coin: Decodable {
        let id: String
        let symbol: String
        let name: String
    }

    private struct QuotePayload: Decodable {
        let usd: Double?
        let usd24hChange: Double?
        let usd24hVol: Double?
        let usdMarketCap: Double?
        let usd24hHigh: Double?
        let usd24hLow: Double?
        let lastUpdatedAt: Int?

        enum CodingKeys: String, CodingKey {
            case usd
            case usd24hChange = "usd_24h_change"
            case usd24hVol = "usd_24h_vol"
            case usdMarketCap = "usd_market_cap"
            case usd24hHigh = "usd_24h_high"
            case usd24hLow = "usd_24h_low"
            case lastUpdatedAt = "last_updated_at"
        }
    }

    func searchAsset(keyword: String) async throws -> CryptoAsset? {
        guard let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.coingecko.com/api/v3/search?query=\(encoded)") else {
            return nil
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        let normalized = keyword.lowercased()
        let selected = response.coins.first(where: { $0.symbol.lowercased() == normalized })
            ?? response.coins.first(where: { $0.name.lowercased() == normalized })
            ?? response.coins.first
        guard let selected else { return nil }
        return CryptoAsset(
            id: selected.id,
            symbol: selected.symbol.uppercased(),
            name: selected.name
        )
    }

    func fetchQuotes(ids: [String]) async throws -> [String: CryptoQuote] {
        guard !ids.isEmpty else { return [:] }
        let idQuery = ids.joined(separator: ",")
        guard let encoded = idQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(
                string: "https://api.coingecko.com/api/v3/simple/price?ids=\(encoded)&vs_currencies=usd&include_24hr_change=true&include_24hr_vol=true&include_market_cap=true&include_last_updated_at=true&include_24hr_high=true&include_24hr_low=true"
              ) else {
            return [:]
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode([String: QuotePayload].self, from: data)
        var result: [String: CryptoQuote] = [:]
        for (id, payload) in decoded {
            guard let usd = payload.usd else { continue }
            let timestamp = TimeInterval(payload.lastUpdatedAt ?? Int(Date().timeIntervalSince1970))
            result[id] = CryptoQuote(
                price: usd,
                change24h: payload.usd24hChange,
                high24h: payload.usd24hHigh,
                low24h: payload.usd24hLow,
                marketCap: payload.usdMarketCap,
                volume24h: payload.usd24hVol,
                updatedAt: Date(timeIntervalSince1970: timestamp)
            )
        }
        return result
    }
}

@MainActor
final class CryptoViewModel: ObservableObject {
    @Published var watchedAssets: [CryptoAsset] = [
        .init(id: "bitcoin", symbol: "BTC", name: "Bitcoin"),
        .init(id: "ethereum", symbol: "ETH", name: "Ethereum"),
        .init(id: "solana", symbol: "SOL", name: "Solana")
    ]
    @Published var quotes: [String: CryptoQuote] = [:]
    @Published var queryText = ""
    @Published var isLoading = false
    @Published var message = ""

    private let apiClient = CryptoAPIClient()
    private var autoRefreshTask: Task<Void, Never>?

    deinit {
        autoRefreshTask?.cancel()
    }

    func startAutoRefresh() {
        guard autoRefreshTask == nil else { return }
        autoRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshQuotes()
                try? await Task.sleep(for: .seconds(12))
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    func addAsset() async {
        let input = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        do {
            isLoading = true
            defer { isLoading = false }
            guard let asset = try await apiClient.searchAsset(keyword: input) else {
                message = "没有找到币种：\(input)"
                return
            }
            if watchedAssets.contains(where: { $0.id == asset.id }) {
                message = "\(asset.symbol) 已在列表中"
                return
            }
            watchedAssets.insert(asset, at: 0)
            queryText = ""
            message = "已添加 \(asset.symbol)"
            await refreshQuotes()
        } catch {
            message = "添加失败，请稍后重试"
        }
    }

    func removeAsset(_ asset: CryptoAsset) {
        watchedAssets.removeAll(where: { $0.id == asset.id })
        quotes.removeValue(forKey: asset.id)
    }

    func refreshQuotes() async {
        do {
            let ids = watchedAssets.map(\.id)
            let latest = try await apiClient.fetchQuotes(ids: ids)
            quotes = latest
        } catch {
            message = "价格更新失败，请检查网络"
        }
    }
}

struct CryptoDashboardView: View {
    @StateObject private var viewModel = CryptoViewModel()
    @State private var selectedAssetID: String?

    var body: some View {
        VStack(spacing: 0) {
            actionBar
            columnHeader
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.watchedAssets) { asset in
                        CompactCryptoRowView(
                            asset: asset,
                            quote: viewModel.quotes[asset.id],
                            isSelected: selectedAssetID == asset.id
                        ) {
                            selectedAssetID = asset.id
                        } onRemove: {
                            viewModel.removeAsset(asset)
                        }
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 420, height: 620)
        .background(Color.white)
        .task {
            viewModel.startAutoRefresh()
            await viewModel.refreshQuotes()
            if selectedAssetID == nil {
                selectedAssetID = viewModel.watchedAssets.first?.id
            }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .onChange(of: viewModel.watchedAssets) { assets in
            guard !assets.isEmpty else {
                selectedAssetID = nil
                return
            }
            if let selectedAssetID,
               assets.contains(where: { $0.id == selectedAssetID }) {
                return
            }
            selectedAssetID = assets.first?.id
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            TextField("添加币种，如 btc / solana", text: $viewModel.queryText)
                .textFieldStyle(.roundedBorder)
            Button("添加") {
                Task {
                    await viewModel.addAsset()
                    if selectedAssetID == nil {
                        selectedAssetID = viewModel.watchedAssets.first?.id
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button("刷新") {
                Task { await viewModel.refreshQuotes() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("名称")
                .frame(width: 150, alignment: .leading)
            Text("分时")
                .frame(width: 120, alignment: .center)
            Text("最新")
                .frame(width: 80, alignment: .trailing)
            Text("涨幅")
                .frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

struct CompactCryptoRowView: View {
    let asset: CryptoAsset
    let quote: CryptoQuote?
    let isSelected: Bool
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(asset.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(asset.symbol)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)

            MiniTrendView(quote: quote, isSelected: isSelected)
                .frame(width: 120, height: 24)

            Text(lastPriceText)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 80, alignment: .trailing)

            Text(changeText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(changeColor)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color(red: 0.08, green: 0.46, blue: 0.94) : Color.white)
        .foregroundStyle(isSelected ? .white : .primary)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("移除", role: .destructive) {
                onRemove()
            }
        }
    }

    private var lastPriceText: String {
        guard let price = quote?.price else { return "--" }
        if price >= 1000 {
            return price.formatted(.number.precision(.fractionLength(2)))
        }
        if price >= 1 {
            return price.formatted(.number.precision(.fractionLength(3)))
        }
        return price.formatted(.number.precision(.fractionLength(6)))
    }

    private var changeText: String {
        guard let value = quote?.change24h else { return "--" }
        let signal = value >= 0 ? "+" : ""
        return "\(signal)\(String(format: "%.2f", value))%"
    }

    private var changeColor: Color {
        guard let value = quote?.change24h else {
            return isSelected ? .white : .secondary
        }
        if isSelected {
            return .white
        }
        return value >= 0 ? Color(red: 0.12, green: 0.62, blue: 0.24) : Color(red: 0.9, green: 0.18, blue: 0.2)
    }
}

struct MiniTrendView: View {
    let quote: CryptoQuote?
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let points = trendPoints(width: size.width, height: size.height)
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(strokeColor, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        }
    }

    private var strokeColor: Color {
        guard let change = quote?.change24h else {
            return isSelected ? .white : .gray
        }
        if isSelected {
            return .white
        }
        return change >= 0 ? Color(red: 0.12, green: 0.62, blue: 0.24) : Color(red: 0.9, green: 0.18, blue: 0.2)
    }

    private func trendPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let baseline = [0.24, 0.52, 0.44, 0.58, 0.49, 0.61, 0.56, 0.63, 0.55, 0.69, 0.64, 0.74]
        let seed = max(0.05, min(0.95, normalizedSeed))
        let variation = baseline.enumerated().map { index, value in
            let shift = sin(Double(index) * 0.75 + seed * 3.2) * 0.08
            return max(0.08, min(0.92, value + shift))
        }
        let count = variation.count
        return variation.enumerated().map { index, value in
            let x = CGFloat(index) * (width / CGFloat(max(1, count - 1)))
            let y = height - CGFloat(value) * height
            return CGPoint(x: x, y: y)
        }
    }

    private var normalizedSeed: Double {
        guard let quote else { return 0.33 }
        let low = quote.low24h ?? quote.price * 0.9
        let high = quote.high24h ?? quote.price * 1.1
        guard high > low else { return 0.5 }
        return (quote.price - low) / (high - low)
    }
}
