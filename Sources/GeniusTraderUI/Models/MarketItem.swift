import Foundation

public struct MarketItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let code: String
    public let productID: String
    public let price: Double
    public let changePercentage: Double
    public let isRising: Bool
    public let high24h: Double
    public let low24h: Double
    public let volume24h: Double
    public let trend: [Double]

    public init(name: String, code: String, productID: String, price: Double, changePercentage: Double, isRising: Bool, high24h: Double, low24h: Double, volume24h: Double, trend: [Double]) {
        self.id = productID
        self.name = name
        self.code = code
        self.productID = productID
        self.price = price
        self.changePercentage = changePercentage
        self.isRising = isRising
        self.high24h = high24h
        self.low24h = low24h
        self.volume24h = volume24h
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
