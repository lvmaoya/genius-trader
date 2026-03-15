import Foundation

final class CoinbaseCandlesService {
    private let session = URLSession(configuration: .default)

    func fetchHourlyTrend(productID: String, hours: Int = 24) async throws -> [Double] {
        let end = Date()
        let start = end.addingTimeInterval(TimeInterval(-hours * 3600))

        var components = URLComponents(string: "https://api.exchange.coinbase.com/products/\(productID)/candles")!
        components.queryItems = [
            URLQueryItem(name: "granularity", value: "3600"),
            URLQueryItem(name: "start", value: iso8601.string(from: start)),
            URLQueryItem(name: "end", value: iso8601.string(from: end))
        ]

        let (data, _) = try await session.data(from: components.url!)
        let candles = try JSONDecoder().decode([[Double]].self, from: data)

        let closes = candles
            .compactMap { bucket -> (time: Double, close: Double)? in
                guard bucket.count >= 5 else { return nil }
                return (time: bucket[0], close: bucket[4])
            }
            .sorted { $0.time < $1.time }
            .map(\.close)

        guard !closes.isEmpty else {
            return Array(repeating: 0.5, count: 12)
        }

        return normalize(closes)
    }

    private func normalize(_ values: [Double]) -> [Double] {
        guard let minValue = values.min(), let maxValue = values.max(), maxValue != minValue else {
            return Array(repeating: 0.5, count: values.count)
        }

        return values.map { ($0 - minValue) / (maxValue - minValue) }
    }

    private let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
