import Foundation

@MainActor
public final class MarketViewModel: ObservableObject {
    @Published public var searchText = ""
    @Published public var menuItems: [MenuItem] = []
    @Published public private(set) var allItems: [MarketItem] = []
    @Published public private(set) var marketCatalog: [MarketSearchItem] = []
    @Published private var watchlistProductIDs: [String] = []

    private let dataStream = CoinbaseTickerStream()
    private let marketCatalogService = CoinbaseMarketCatalogService()
    private let candlesService = CoinbaseCandlesService()
    private var hourlyTrendByProductID: [String: [Double]] = [:]

    public init() {
        configureMenuItems()
        configureRealtimeStream()
        Task {
            await loadMarketCatalog()
        }
    }

    private func configureMenuItems() {
        menuItems = [
            MenuItem(title: "清空", code: "⌘ 1"),
            MenuItem(title: "设置", code: "⌘ 2"),
            MenuItem(title: "退出", code: "⌘ Q")
        ]
    }

    public var items: [MarketItem] {
        watchlistProductIDs.compactMap { productID in
            if let item = allItems.first(where: { $0.productID == productID }) {
                return item
            }
            return placeholderItem(for: productID)
        }
    }

    public var isSearching: Bool {
        !searchKeyword.isEmpty
    }

    public var searchResults: [MarketSearchItem] {
        guard isSearching else { return [] }
        return marketCatalog.filter { item in
            item.name.localizedCaseInsensitiveContains(searchKeyword) ||
            item.code.localizedCaseInsensitiveContains(searchKeyword)
        }
    }

    public func isInWatchlist(_ item: MarketSearchItem) -> Bool {
        watchlistProductIDs.contains(item.productID)
    }

    public func addToWatchlist(_ item: MarketSearchItem) {
        guard !isInWatchlist(item) else { return }
        watchlistProductIDs.insert(item.productID, at: 0)
        if !allItems.contains(where: { $0.productID == item.productID }) {
            allItems.append(
                MarketItem(
                    name: item.name,
                    code: item.code,
                    productID: item.productID,
                    price: 0,
                    changePercentage: 0,
                    isRising: true,
                    trend: hourlyTrendByProductID[item.productID] ?? Array(repeating: 0.5, count: 12)
                )
            )
        }
        Task {
            await loadHourlyTrend(for: item.productID)
        }
        updateSubscriptions()
    }

    public func clearWatchlist() {
        watchlistProductIDs.removeAll()
        allItems.removeAll()
        hourlyTrendByProductID.removeAll()
        dataStream.disconnect()
    }

    public func watchlistItem(for item: MarketSearchItem) -> MarketItem? {
        items.first(where: { $0.productID == item.productID })
    }

    private var searchKeyword: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func configureRealtimeStream() {
        dataStream.onTicker = { [weak self] update in
            guard let self else { return }
            Task { @MainActor in
                self.apply(update: update)
            }
        }
    }

    private func apply(update: CoinbaseTickerUpdate) {
        guard let index = allItems.firstIndex(where: { $0.productID == update.productID }) else {
            return
        }

        let current = allItems[index]

        allItems[index] = MarketItem(
            name: current.name,
            code: current.code,
            productID: update.productID,
            price: update.lastPrice,
            changePercentage: update.changePercentage,
            isRising: update.changePercentage >= 0,
            trend: hourlyTrendByProductID[update.productID] ?? current.trend
        )
    }

    private func loadMarketCatalog() async {
        do {
            marketCatalog = try await marketCatalogService.fetchMarketCatalog()
        } catch {
            print("Failed to load market catalog: \(error.localizedDescription)")
        }
    }

    private func updateSubscriptions() {
        let productIDs = watchlistProductIDs
        if productIDs.isEmpty {
            dataStream.disconnect()
        } else {
            dataStream.connect(productIDs: productIDs)
        }
    }

    private func placeholderItem(for productID: String) -> MarketItem? {
        guard let catalogItem = marketCatalog.first(where: { $0.productID == productID }) else {
            return nil
        }

        return MarketItem(
            name: catalogItem.name,
            code: catalogItem.code,
            productID: catalogItem.productID,
            price: 0,
            changePercentage: 0,
            isRising: true,
            trend: hourlyTrendByProductID[productID] ?? Array(repeating: 0.5, count: 12)
        )
    }

    private func loadHourlyTrend(for productID: String) async {
        do {
            let trend = try await candlesService.fetchHourlyTrend(productID: productID)
            hourlyTrendByProductID[productID] = trend

            if let index = allItems.firstIndex(where: { $0.productID == productID }) {
                let current = allItems[index]
                allItems[index] = MarketItem(
                    name: current.name,
                    code: current.code,
                    productID: current.productID,
                    price: current.price,
                    changePercentage: current.changePercentage,
                    isRising: current.isRising,
                    trend: trend
                )
            }
        } catch {
            print("Failed to load hourly candles for \(productID): \(error.localizedDescription)")
        }
    }
}
