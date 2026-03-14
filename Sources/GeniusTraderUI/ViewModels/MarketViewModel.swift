import Foundation

public final class MarketViewModel: ObservableObject {
    @Published public var searchText = ""
    @Published public var items: [MarketItem] = []
    @Published public var menuItems: [MenuItem] = []

    public init() {
        loadMockData()
    }

    private func loadMockData() {
        let trendUp = [0.2, 0.3, 0.25, 0.4, 0.35, 0.5, 0.45, 0.6, 0.55, 0.8]
        let trendDown = [0.8, 0.7, 0.75, 0.6, 0.65, 0.5, 0.55, 0.4, 0.45, 0.2]
        let trendVolatile = [0.4, 0.6, 0.3, 0.7, 0.4, 0.8, 0.5, 0.6, 0.4, 0.5]

        items = [
            MarketItem(name: "自选股", code: "000001", price: 5.41, changePercentage: -1.50, isRising: false, trend: trendDown),
            MarketItem(name: "聚飞光电", code: "300303", price: 32.5, changePercentage: -2.20, isRising: true, trend: trendVolatile),
            MarketItem(name: "BTC", code: "BTC", price: 567222, changePercentage: -2.35, isRising: true, trend: trendUp),
            MarketItem(name: "BNB", code: "BNB", price: 52341, changePercentage: -2.35, isRising: true, trend: trendVolatile),
            MarketItem(name: "国华金科", code: "000002", price: 4567.01, changePercentage: -2.20, isRising: true, trend: trendDown),
            MarketItem(name: "国华理财", code: "000003", price: 9343, changePercentage: -2.20, isRising: true, trend: trendUp),
            MarketItem(name: "比亚迪", code: "002594", price: 23.12, changePercentage: -2.20, isRising: false, trend: trendDown),
            MarketItem(name: "聚飞光电", code: "300303", price: 32.5, changePercentage: -2.20, isRising: true, trend: trendVolatile),
            MarketItem(name: "聚飞光电", code: "300303", price: 32.5, changePercentage: -2.20, isRising: true, trend: trendUp),
            MarketItem(name: "聚飞光电", code: "300303", price: 32.5, changePercentage: -2.20, isRising: true, trend: trendDown),
            MarketItem(name: "聚飞光电", code: "300303", price: 32.5, changePercentage: -2.20, isRising: true, trend: trendVolatile),
            MarketItem(name: "聚飞光电", code: "300303", price: 32.5, changePercentage: -2.20, isRising: true, trend: trendUp),
            MarketItem(name: "聚飞光电", code: "300303", price: 32.5, changePercentage: -2.20, isRising: true, trend: trendDown),
            MarketItem(name: "聚飞光电", code: "300303", price: 32.5, changePercentage: -2.35, isRising: true, trend: trendVolatile)
        ]

        menuItems = [
            MenuItem(title: "高榜", code: "⌘ 1"),
            MenuItem(title: "板块全览", code: "⌘ 2"),
            MenuItem(title: "关于", code: "⌘ 3"),
            MenuItem(title: "退出", code: "⌘ Q")
        ]
    }
}
