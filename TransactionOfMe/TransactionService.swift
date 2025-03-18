//  TransactionService.swift
//  TransactionOfMe
//
//  Created by 刘弨 on 2025/3/17.
//

import Foundation

class TransactionViewModel: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? // 新增错误消息状态
    
    func fetchTransactions(startTime: String? = nil, endTime: String? = nil, productID: String? = nil) async -> [Transaction] {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil // 重置错误消息
        }

        var urlComponents = URLComponents(string: "https://www.mehealthapp.cn/api/getAllTransactions")!
        var queryItems: [URLQueryItem] = []

        if let startTime = startTime {
            queryItems.append(URLQueryItem(name: "start_time", value: startTime))
        }
        if let endTime = endTime {
            queryItems.append(URLQueryItem(name: "end_time", value: endTime))
        }
        if let productID = productID {
            queryItems.append(URLQueryItem(name: "productID", value: productID))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            print("错误：无法构建有效的 URL")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "无效的 URL"
            }
            return []
        }

        print("请求接口的地址: \(url)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
//            if let jsonString = String(data: data, encoding: .utf8) {
//                print("接口返回的 JSON 数据: \(jsonString)")
//            } else {
//                print("无法将数据转换为字符串")
//            }

            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // 尝试解析为 [Transaction]
            do {
                let decodedData = try decoder.decode([Transaction].self, from: data)
                await MainActor.run {
                    self.isLoading = false
                }
                return decodedData.sorted { $0.purchaseDate > $1.purchaseDate }
            } catch {
                // 如果解析 [Transaction] 失败，尝试解析 ErrorResponse
                if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = errorResponse.error
                    }
                    return []
                } else {
                    throw error // 如果都不是，抛出原始错误
                }
            }
        } catch {
            print("请求或解析错误: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "请求失败: \(error.localizedDescription)"
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
        case id = "transactionID"
        case productID
        case purchaseDate
        case expirationDate
        case revocationDate
        case price
        case currency
        case environment
        case appleSignID
    }

    // 自定义解码（仅处理非日期字段的特殊逻辑）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 处理 transactionID，设置默认值
        let transactionID = try container.decode(Int64.self, forKey: .id)
        id = transactionID > 0 ? transactionID : Int64(Date().timeIntervalSince1970)

        productID = try container.decode(String.self, forKey: .productID)
        purchaseDate = try container.decode(Date.self, forKey: .purchaseDate)
        expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
        revocationDate = try container.decodeIfPresent(Date.self, forKey: .revocationDate)

        // 解析 price
        price = try container.decodeIfPresent(String.self, forKey: .price)
            .flatMap { Double($0) } ?? container.decodeIfPresent(Double.self, forKey: .price)

        // 解析 currency，去除 "Optional()"
        currency = try container.decodeIfPresent(String.self, forKey: .currency)?
            .replacingOccurrences(of: "Optional(", with: "")
            .replacingOccurrences(of: ")", with: "")

        // 解析 environment，去除 "Environment(rawValue: )"
        environment = try container.decode(String.self, forKey: .environment)
            .replacingOccurrences(of: "Environment(rawValue: \"", with: "")
            .replacingOccurrences(of: "\")", with: "")

        appleSignID = try container.decode(String.self, forKey: .appleSignID)
    }

    // 自定义编码
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(productID, forKey: .productID)
        try container.encode(purchaseDate, forKey: .purchaseDate)
        try container.encodeIfPresent(expirationDate, forKey: .expirationDate)
        try container.encodeIfPresent(revocationDate, forKey: .revocationDate)
        try container.encodeIfPresent(price.map { String(format: "%.2f", $0) }, forKey: .price)
        try container.encodeIfPresent(currency, forKey: .currency)
        try container.encode(environment, forKey: .environment)
        try container.encode(appleSignID, forKey: .appleSignID)
    }
}


// 错误响应模型
struct ErrorResponse: Codable {
    let error: String
}
