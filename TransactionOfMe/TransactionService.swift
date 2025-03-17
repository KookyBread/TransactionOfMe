//  TransactionService.swift
//  TransactionOfMe
//
//  Created by 刘弨 on 2025/3/17.
//

import Foundation

class TransactionViewModel: ObservableObject {
    @Published var isLoading: Bool = true

    func fetchTransactions() async -> [Transaction] {
        await MainActor.run{
            self.isLoading = true
        }
        guard let url = URL(string: "https://www.mehealthapp.cn/api/getAllTransactions") else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let decodedData = try decoder.decode([Transaction].self, from: data)
            await MainActor.run{
                self.isLoading = false
            }
            return decodedData.sorted { $0.purchaseDate > $1.purchaseDate }
        } catch {
            print("请求或解析错误: \(error.localizedDescription)")
            await MainActor.run{
                self.isLoading = false
            }
            return []
        }
    }
}

struct Transaction: Identifiable, Codable {
    let id: Int64
    let productID: String
    let purchaseDate: Date
    let expirationDate: Date?
    let revocationDate: Date?
    let price: Double?
    let currency: String?
    let environment: String
    let appleSignID: String

    enum CodingKeys: String, CodingKey {
        case transactionID, productID, purchaseDate, expirationDate, revocationDate, price, currency, environment, appleSignID
    }

    // 自定义初始化（Decodable）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 处理 transactionID，避免 0
        let transactionID = try container.decode(Int64.self, forKey: .transactionID)
        self.id = transactionID > 0 ? transactionID : Int64(Date().timeIntervalSince1970)

        self.productID = try container.decode(String.self, forKey: .productID)

        // 解析 GMT 格式日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        if let dateString = try? container.decode(String.self, forKey: .purchaseDate),
           let date = dateFormatter.date(from: dateString) {
            self.purchaseDate = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .purchaseDate, in: container, debugDescription: "Invalid date format")
        }

        self.expirationDate = (try? container.decodeIfPresent(String.self, forKey: .expirationDate))
            .flatMap { dateFormatter.date(from: $0) }
        self.revocationDate = (try? container.decodeIfPresent(String.self, forKey: .revocationDate))
            .flatMap { dateFormatter.date(from: $0) }

        // 解析 price
        if let priceString = try? container.decodeIfPresent(String.self, forKey: .price),
           let priceValue = Double(priceString) {
            self.price = priceValue
        } else {
            self.price = try? container.decodeIfPresent(Double.self, forKey: .price)
        }

        // 解析 currency，去掉 "Optional()"
        if let rawCurrency = try? container.decodeIfPresent(String.self, forKey: .currency) {
            self.currency = rawCurrency.replacingOccurrences(of: "Optional(", with: "").replacingOccurrences(of: ")", with: "")
        } else {
            self.currency = nil
        }

        // 解析 environment，去掉 "Environment(rawValue: )"
        if let rawEnvironment = try? container.decodeIfPresent(String.self, forKey: .environment) {
            self.environment = rawEnvironment
                .replacingOccurrences(of: "Environment(rawValue: \"", with: "")
                .replacingOccurrences(of: "\")", with: "")
        } else {
            self.environment = ""
        }

        self.appleSignID = try container.decode(String.self, forKey: .appleSignID)
    }

    // **手动实现 Encodable**
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .transactionID)
        try container.encode(productID, forKey: .productID)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        try container.encode(dateFormatter.string(from: purchaseDate), forKey: .purchaseDate)
        try container.encodeIfPresent(expirationDate.map { dateFormatter.string(from: $0) }, forKey: .expirationDate)
        try container.encodeIfPresent(revocationDate.map { dateFormatter.string(from: $0) }, forKey: .revocationDate)

        if let price = price {
            try container.encode(String(format: "%.2f", price), forKey: .price)
        }

        try container.encodeIfPresent(currency, forKey: .currency)
        try container.encode(environment, forKey: .environment)
        try container.encode(appleSignID, forKey: .appleSignID)
    }
}
