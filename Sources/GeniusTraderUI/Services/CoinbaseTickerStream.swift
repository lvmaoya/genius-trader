import Foundation

struct CoinbaseTickerUpdate {
    let productID: String
    let lastPrice: Double
    let changePercentage: Double
    let high24h: Double
    let low24h: Double
    let volume24h: Double
}

final class CoinbaseTickerStream {
    var onTicker: ((CoinbaseTickerUpdate) -> Void)?

    private let session = URLSession(configuration: .default)
    private let decoder = JSONDecoder()
    private var webSocketTask: URLSessionWebSocketTask?
    private var subscribedProductIDs: [String] = []
    private var isManualDisconnect = false

    func connect(productIDs: [String]) {
        let normalized = Array(Set(productIDs)).sorted()
        guard !normalized.isEmpty else { return }

        subscribedProductIDs = normalized
        isManualDisconnect = false
        disconnectCurrentTask()

        let task = session.webSocketTask(with: URL(string: "wss://ws-feed.exchange.coinbase.com")!)
        webSocketTask = task
        task.resume()

        receiveNextMessage()
        sendSubscribe(productIDs: normalized)
    }

    func disconnect() {
        isManualDisconnect = true
        subscribedProductIDs = []
        disconnectCurrentTask()
    }

    private func disconnectCurrentTask() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func sendSubscribe(productIDs: [String]) {
        let request = CoinbaseSubscribeRequest(
            type: "subscribe",
            productIDs: productIDs,
            channels: [.init(name: "ticker", productIDs: productIDs)]
        )

        guard
            let data = try? JSONEncoder().encode(request),
            let text = String(data: data, encoding: .utf8)
        else {
            return
        }

        webSocketTask?.send(.string(text)) { [weak self] error in
            guard let self, let error, !self.isManualDisconnect else { return }
            print("Coinbase subscribe failed: \(error.localizedDescription)")
            self.scheduleReconnect()
        }
    }

    private func receiveNextMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handle(message)
                self.receiveNextMessage()
            case .failure(let error):
                guard !self.isManualDisconnect else { return }
                print("Coinbase receive failed: \(error.localizedDescription)")
                self.scheduleReconnect()
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            decodePayload(from: Data(text.utf8))
        case .data(let data):
            decodePayload(from: data)
        @unknown default:
            break
        }
    }

    private func decodePayload(from data: Data) {
        guard let payload = try? decoder.decode(CoinbaseTickerPayload.self, from: data) else {
            return
        }

        guard payload.type == "ticker",
              let productID = payload.productID,
              let priceString = payload.price,
              let lastPrice = Double(priceString)
        else {
            return
        }

        let openPrice = Double(payload.open24h ?? "") ?? lastPrice
        let high24h = Double(payload.high24h ?? "") ?? lastPrice
        let low24h = Double(payload.low24h ?? "") ?? lastPrice
        let volume24h = Double(payload.volume24h ?? "") ?? 0
        let changePercentage: Double
        if openPrice == 0 {
            changePercentage = 0
        } else {
            changePercentage = ((lastPrice - openPrice) / openPrice) * 100
        }

        onTicker?(
            CoinbaseTickerUpdate(
                productID: productID,
                lastPrice: lastPrice,
                changePercentage: changePercentage,
                high24h: high24h,
                low24h: low24h,
                volume24h: volume24h
            )
        )
    }

    private func scheduleReconnect() {
        let productIDs = subscribedProductIDs
        guard !productIDs.isEmpty else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, !self.isManualDisconnect else { return }
            self.connect(productIDs: productIDs)
        }
    }
}

private struct CoinbaseSubscribeRequest: Encodable {
    let type: String
    let productIDs: [String]
    let channels: [Channel]

    struct Channel: Encodable {
        let name: String
        let productIDs: [String]

        enum CodingKeys: String, CodingKey {
            case name
            case productIDs = "product_ids"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case productIDs = "product_ids"
        case channels
    }
}

private struct CoinbaseTickerPayload: Decodable {
    let type: String?
    let productID: String?
    let price: String?
    let open24h: String?
    let high24h: String?
    let low24h: String?
    let volume24h: String?

    enum CodingKeys: String, CodingKey {
        case type
        case productID = "product_id"
        case price
        case open24h = "open_24h"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case volume24h = "volume_24h"
    }
}
