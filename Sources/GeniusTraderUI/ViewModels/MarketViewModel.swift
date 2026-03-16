import Foundation

@MainActor
/// 市场页的页面级 ViewModel。
/// 负责三件事：
/// 1. 维护自选列表与搜索结果。
/// 2. 驱动实时行情与趋势数据。
/// 3. 在启动时恢复上次保存的自选列表。
public final class MarketViewModel: ObservableObject {
    @Published public var searchText = ""
    @Published public var menuItems: [MenuItem] = []
    @Published public private(set) var allItems: [MarketItem] = []
    @Published public private(set) var marketCatalog: [MarketSearchItem] = []
    /// 自选列表的真实顺序来源。`items` 只是基于它映射出来的展示数组。
    @Published private var watchlistProductIDs: [String] = []

    private let dataStream = CoinbaseTickerStream()
    private let marketCatalogService = CoinbaseMarketCatalogService()
    private let candlesService = CoinbaseCandlesService()
    private var hourlyTrendByProductID: [String: [Double]] = [:]

    public init() {
        // 启动时先恢复本地保存的自选顺序，这样 UI 能尽快拿到“上次的自选列表”。
        watchlistProductIDs = MarketSelectionStore.loadWatchlistProductIDs()
        configureMenuItems()
        configureRealtimeStream()
        // 恢复自选后立刻补订阅与趋势数据，即使目录还没加载完成，也先把基础状态建起来。
        restoreWatchlistState()
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
        // 展示数组始终以“自选顺序”为准，避免实时数据更新打乱用户当前看到的顺序。
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
        // 用户刚添加成功就立即落盘，避免异常退出时丢失这次操作。
        persistWatchlist()
        if !allItems.contains(where: { $0.productID == item.productID }) {
            allItems.append(
                MarketItem(
                    name: item.name,
                    code: item.code,
                    productID: item.productID,
                    price: 0,
                    changePercentage: 0,
                    isRising: true,
                    high24h: 0,
                    low24h: 0,
                    volume24h: 0,
                    trend: hourlyTrendByProductID[item.productID] ?? Array(repeating: 0.5, count: 12)
                )
            )
        }
        Task {
            await loadHourlyTrend(for: item.productID)
        }
        updateSubscriptions()
    }

    /// 从自选列表移除一个币种，并同步更新本地持久化与实时订阅。
    public func removeFromWatchlist(productID: String) {
        guard let index = watchlistProductIDs.firstIndex(of: productID) else { return }

        watchlistProductIDs.remove(at: index)
        persistWatchlist()

        allItems.removeAll { $0.productID == productID }
        hourlyTrendByProductID.removeValue(forKey: productID)
        updateSubscriptions()
    }

    public func clearWatchlist() {
        watchlistProductIDs.removeAll()
        MarketSelectionStore.clearWatchlistProductIDs()
        allItems.removeAll()
        hourlyTrendByProductID.removeAll()
        // 自选为空时断开订阅，减少无意义的 websocket 流量。
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
        // 只更新当前页面已经展示的币种，未展示的数据不进入页面状态。
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
            high24h: update.high24h,
            low24h: update.low24h,
            volume24h: update.volume24h,
            trend: hourlyTrendByProductID[update.productID] ?? current.trend
        )
    }

    private func loadMarketCatalog() async {
        do {
            marketCatalog = try await marketCatalogService.fetchMarketCatalog()
            // 市场目录回来后，补上那些启动时还无法构造占位数据的自选项。
            restoreMissingItemsFromCatalog()
        } catch {
            print("Failed to load market catalog: \(error.localizedDescription)")
        }
    }

    private func updateSubscriptions() {
        let productIDs = watchlistProductIDs
        if productIDs.isEmpty {
            dataStream.disconnect()
        } else {
            // websocket 订阅集合始终与当前自选列表保持一致。
            dataStream.connect(productIDs: productIDs)
        }
    }

    /// 在实时价格还没回来时，先用目录数据构造一个占位项，让列表稳定显示。
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
            high24h: 0,
            low24h: 0,
            volume24h: 0,
            trend: hourlyTrendByProductID[productID] ?? Array(repeating: 0.5, count: 12)
        )
    }

    private func loadHourlyTrend(for productID: String) async {
        do {
            let trend = try await candlesService.fetchHourlyTrend(productID: productID)
            hourlyTrendByProductID[productID] = trend

            // 趋势数据回来后，回写到当前展示项，避免列表里一直显示默认 sparkline。
            if let index = allItems.firstIndex(where: { $0.productID == productID }) {
                let current = allItems[index]
                allItems[index] = MarketItem(
                    name: current.name,
                    code: current.code,
                    productID: current.productID,
                    price: current.price,
                    changePercentage: current.changePercentage,
                    isRising: current.isRising,
                    high24h: current.high24h,
                    low24h: current.low24h,
                    volume24h: current.volume24h,
                    trend: trend
                )
            }
        } catch {
            print("Failed to load hourly candles for \(productID): \(error.localizedDescription)")
        }
    }

    /// 基于已持久化的自选列表恢复页面状态。
    /// 先恢复占位数据，再异步拉趋势，最后恢复 websocket 订阅。
    private func restoreWatchlistState() {
        for productID in watchlistProductIDs where !allItems.contains(where: { $0.productID == productID }) {
            if let item = placeholderItem(for: productID) {
                allItems.append(item)
            }

            Task {
                await loadHourlyTrend(for: productID)
            }
        }

        updateSubscriptions()
    }

    /// 市场目录拉取完成后，把之前无法构造的占位项补齐。
    private func restoreMissingItemsFromCatalog() {
        let missingProductIDs = watchlistProductIDs.filter { productID in
            !allItems.contains(where: { $0.productID == productID })
        }

        for productID in missingProductIDs {
            if let item = placeholderItem(for: productID) {
                allItems.append(item)
            }
        }
    }

    /// 持久化自选列表的统一出口，后续若替换存储方案，只需要改这里。
    private func persistWatchlist() {
        MarketSelectionStore.saveWatchlistProductIDs(watchlistProductIDs)
    }
}
