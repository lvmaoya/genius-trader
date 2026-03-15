import Foundation

public struct MarketSearchItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let code: String
    public let productID: String

    public init(name: String, code: String, productID: String) {
        self.id = productID
        self.name = name
        self.code = code
        self.productID = productID
    }
}
