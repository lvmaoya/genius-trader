import SwiftUI

@main
struct GeniusTraderApp: App {
    var body: some Scene {
        WindowGroup {
            CryptoDashboardView()
                .frame(minWidth: 980, minHeight: 680)
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

    var body: some View {
        VStack(spacing: 18) {
            header
            addBar
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.watchedAssets) { asset in
                        CryptoRowView(asset: asset, quote: viewModel.quotes[asset.id]) {
                            viewModel.removeAsset(asset)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.09, blue: 0.16), Color(red: 0.1, green: 0.12, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .task {
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Crypto Watch")
                    .font(.system(size: 34, weight: .bold))
                Text("添加币种，实时查看价格与波动")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("立即刷新") {
                Task {
                    await viewModel.refreshQuotes()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var addBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                TextField("输入币种代号或名称，例如 btc / solana", text: $viewModel.queryText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task {
                        await viewModel.addAsset()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("添加币种")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            if !viewModel.message.isEmpty {
                Text(viewModel.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct CryptoRowView: View {
    let asset: CryptoAsset
    let quote: CryptoQuote?
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.name)
                        .font(.headline)
                    Text(asset.symbol)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    if let quote {
                        Text(quote.price, format: .currency(code: "USD"))
                            .font(.title3.weight(.semibold))
                        Text(changeText(for: quote))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(changeColor(for: quote))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(changeColor(for: quote).opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Text("加载中...")
                            .foregroundStyle(.secondary)
                    }
                }
                Button("移除", action: onRemove)
                    .buttonStyle(.bordered)
            }

            if isHovering {
                HoverDetailPanel(quote: quote)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func changeText(for quote: CryptoQuote) -> String {
        guard let value = quote.change24h else { return "24h --" }
        let signal = value >= 0 ? "+" : ""
        return "\(signal)\(String(format: "%.2f", value))%"
    }

    private func changeColor(for quote: CryptoQuote) -> Color {
        guard let value = quote.change24h else { return .gray }
        return value >= 0 ? .green : .red
    }
}

struct HoverDetailPanel: View {
    let quote: CryptoQuote?

    var body: some View {
        VStack(spacing: 8) {
            metricRow(title: "24h 最高", value: priceText(quote?.high24h))
            metricRow(title: "24h 最低", value: priceText(quote?.low24h))
            metricRow(title: "市值", value: compactText(quote?.marketCap))
            metricRow(title: "24h 成交量", value: compactText(quote?.volume24h))
            metricRow(title: "更新时间", value: timeText(quote?.updatedAt))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.2))
        )
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }

    private func priceText(_ value: Double?) -> String {
        guard let value else { return "--" }
        return value.formatted(.currency(code: "USD"))
    }

    private func compactText(_ value: Double?) -> String {
        guard let value else { return "--" }
        return value.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(2))
        )
    }

    private func timeText(_ value: Date?) -> String {
        guard let value else { return "--" }
        return value.formatted(date: .omitted, time: .standard)
    }
}
