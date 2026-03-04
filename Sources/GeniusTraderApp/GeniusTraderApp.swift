import AppKit
import SwiftUI

func resourceImage(named: String) -> Image? {
    for ext in ["pdf", "png", "jpg", "jpeg"] {
        if let url = Bundle.module.url(forResource: named, withExtension: ext),
           let img = NSImage(contentsOf: url) {
            return Image(nsImage: img)
        }
    }
    return nil
}

@main
struct GeniusTraderApp: App {
    var body: some Scene {
        MenuBarExtra(
            "盯币",
            image: (resourceImage(named: "MenuBarIcon")?.renderingMode(.template)) ?? Image(systemName: "bitcoinsign.circle")
        ) {
            MenuContentView()
                .frame(width: 300)
        }
        Settings {
            PreferencesView()
        }
    }
}

struct MenuContentView: View {
    @AppStorage("coinSymbols") private var coinSymbols: String = "BTC,ETH"
    @State private var newSymbol: String = ""
    @State private var prices: [String: CoinPrice] = [:]
    @State private var isLoading: Bool = false
    @State private var lastUpdated: Date?
    @State private var isAdding: Bool = false
    @State private var hoveredSymbol: String?

    private var coins: [String] {
        coinSymbols
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let logo = resourceImage(named: "AppLogo") {
                    logo
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 16, height: 16)
                }
                Text("Genius Trader")
                    .font(.headline)
                Spacer()
                Button {
                    isAdding.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }

            if isAdding {
                HStack {
                    TextField("添加币种，如 BTC", text: $newSymbol)
                    Button("添加") {
                        addSymbol()
                    }
                    .disabled(newSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if !coins.isEmpty {
                ForEach(coins, id: \.self) { symbol in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(symbol)
                                    .font(.body)
                                if let price = prices[symbol]?.usd {
                                    Text(formatPrice(price))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(isLoading ? "加载中" : "暂无价格")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if let change = prices[symbol]?.usd24hChange {
                                Text(formatChange(change))
                                    .font(.caption)
                                    .foregroundColor(change >= 0 ? .green : .red)
                            }
                            Spacer()
                            Button("移除") {
                                remove(symbol: symbol)
                            }
                            .buttonStyle(.borderless)
                        }
                        if hoveredSymbol == symbol {
                            HStack {
                                if let change = prices[symbol]?.usd24hChange {
                                    Text("24h \(formatChange(change))")
                                } else {
                                    Text("24h 暂无数据")
                                }
                                Spacer()
                                if let lastUpdated {
                                    Text("更新 \(formatTime(lastUpdated))")
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .onHover { hovering in
                        hoveredSymbol = hovering ? symbol : nil
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Button("偏好设置") { openPreferences() }
                Button("关于") { NSApp.orderFrontStandardAboutPanel(nil) }
                Button("退出") { NSApp.terminate(nil) }
            }

            if let lastUpdated {
                Text("更新于 \(formatTime(lastUpdated))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .task {
            await refreshPrices()
        }
        .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await refreshPrices()
            }
        }
    }

    private func addSymbol() {
        let symbol = newSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !symbol.isEmpty else { return }
        var current = coins
        guard !current.contains(symbol) else {
            newSymbol = ""
            return
        }
        current.append(symbol)
        coinSymbols = current.joined(separator: ",")
        newSymbol = ""
        Task {
            await refreshPrices()
        }
    }

    private func remove(symbol: String) {
        let updated = coins.filter { $0 != symbol }
        coinSymbols = updated.joined(separator: ",")
        Task {
            await refreshPrices()
        }
    }

    private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func refreshPrices() async {
        guard !isLoading else { return }
        let symbols = coins.map { $0.lowercased() }.joined(separator: ",")
        guard !symbols.isEmpty else {
            prices = [:]
            lastUpdated = Date()
            return
        }
        isLoading = true
        defer { isLoading = false }
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")
        components?.queryItems = [
            URLQueryItem(name: "symbols", value: symbols),
            URLQueryItem(name: "vs_currencies", value: "usd"),
            URLQueryItem(name: "include_24hr_change", value: "true")
        ]
        guard let url = components?.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([String: CoinPrice].self, from: data)
            var mapped: [String: CoinPrice] = [:]
            for (key, value) in decoded {
                mapped[key.uppercased()] = value
            }
            prices = mapped
            lastUpdated = Date()
        } catch {
            lastUpdated = Date()
        }
    }

    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func formatChange(_ value: Double) -> String {
        String(format: "%+.2f%%", value)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct CoinPrice: Decodable {
    let usd: Double?
    let usd24hChange: Double?

    enum CodingKeys: String, CodingKey {
        case usd
        case usd24hChange = "usd_24h_change"
    }
}

struct PreferencesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("偏好设置")
                .font(.headline)
            Text("当前版本暂无可配置项")
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 320)
    }
}
