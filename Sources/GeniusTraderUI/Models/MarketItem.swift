import Foundation

public struct MarketItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let code: String
    public let productID: String
    public let price: Double
    public let changePercentage: Double
    public let isRising: Bool
    public let trend: [Double]

    public init(name: String, code: String, productID: String, price: Double, changePercentage: Double, isRising: Bool, trend: [Double]) {
        self.id = productID
        self.name = name
        self.code = code
        self.productID = productID
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
