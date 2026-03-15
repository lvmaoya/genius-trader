import Foundation

/// 市场模块的轻量持久化入口。
/// 目前统一用 UserDefaults 保存：
/// 1. 上次点击选中的币种。
/// 2. 自选列表的 productID 顺序。
enum MarketSelectionStore {
    private static let selectedMarketItemIDKey = "market.selectedItemID"
    private static let watchlistProductIDsKey = "market.watchlistProductIDs"

    /// 读取上次点击选中的币种。
    static func loadSelectedItemID() -> String? {
        UserDefaults.standard.string(forKey: selectedMarketItemIDKey)
    }

    /// 保存当前点击选中的币种。
    static func saveSelectedItemID(_ id: String) {
        UserDefaults.standard.set(id, forKey: selectedMarketItemIDKey)
    }

    /// 清理已经失效的选中项。
    static func clearSelectedItemID() {
        UserDefaults.standard.removeObject(forKey: selectedMarketItemIDKey)
    }

    /// 读取自选列表顺序；如果之前从未保存过，则返回空数组。
    static func loadWatchlistProductIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: watchlistProductIDsKey) ?? []
    }

    /// 保存整个自选列表，并保留用户当前看到的顺序。
    static func saveWatchlistProductIDs(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: watchlistProductIDsKey)
    }

    /// 清空已保存的自选列表。
    static func clearWatchlistProductIDs() {
        UserDefaults.standard.removeObject(forKey: watchlistProductIDsKey)
    }
}
