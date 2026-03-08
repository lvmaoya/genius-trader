import Foundation

public struct MarketItem: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let price: Double
    public let changePercentage: Double
    public let isRising: Bool
    public let trend: [Double]

    public init(name: String, price: Double, changePercentage: Double, isRising: Bool, trend: [Double]) {
        self.name = name
        self.price = price
        self.changePercentage = changePercentage
        self.isRising = isRising
        self.trend = trend
    }
}

public struct MenuItem: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let code: String

    public init(title: String, code: String) {
        self.title = title
        self.code = code
    }
}
