import Foundation

final class CoinbaseMarketCatalogService {
    private let session = URLSession(configuration: .default)

    func fetchMarketCatalog() async throws -> [MarketSearchItem] {
        async let currenciesTask = fetchCurrencies()
        async let productsTask = fetchProducts()

        let currencies = try await currenciesTask
        let products = try await productsTask

        return products
            .filter { product in
                product.quoteCurrencyID == "USD" &&
                product.status == "online" &&
                !product.tradingDisabled
            }
            .map { product in
                let name = currencies[product.baseCurrencyID] ?? product.baseCurrencyID
                return MarketSearchItem(
                    name: name,
                    code: product.baseCurrencyID,
                    productID: product.productID
                )
            }
            .sorted {
                if $0.code == $1.code {
                    return $0.productID < $1.productID
                }
                return $0.code < $1.code
            }
    }

    private func fetchProducts() async throws -> [CoinbaseProductPayload] {
        let url = URL(string: "https://api.exchange.coinbase.com/products")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([CoinbaseProductPayload].self, from: data)
    }

    private func fetchCurrencies() async throws -> [String: String] {
        let url = URL(string: "https://api.exchange.coinbase.com/currencies")!
        let (data, _) = try await session.data(from: url)
        let payload = try JSONDecoder().decode([CoinbaseCurrencyPayload].self, from: data)
        return Dictionary(uniqueKeysWithValues: payload.map { ($0.id, $0.name) })
    }
}

private struct CoinbaseProductPayload: Decodable {
    let productID: String
    let baseCurrencyID: String
    let quoteCurrencyID: String
    let status: String
    let tradingDisabled: Bool

    enum CodingKeys: String, CodingKey {
        case productID = "id"
        case baseCurrencyID = "base_currency"
        case quoteCurrencyID = "quote_currency"
        case status
        case tradingDisabled = "trading_disabled"
    }
}

private struct CoinbaseCurrencyPayload: Decodable {
    let id: String
    let name: String
}
