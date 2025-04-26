//
//  TransactionListView.swift
//  TransactionOfMe
//
//  Created by 刘弨 on 2025/3/17.
//

import SwiftUI

struct TransactionListView: View {
    @StateObject private var transactionService = TransactionViewModel()
    @State private var transactions: [Transaction] = []
    
    // 默认时间范围设置为过去一年，避免未来数据
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var selectedProductID: String = "All"
    
    private let productIDOptions = [
        "Me.LifeTimeRro": "永久会员",
        "Me.Monthly.Pro": "月度",
        "Me.Annual.Pro": "年度",
        "All": "全部"
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                HStack{
                    ScrollView(.horizontal) {
                        HStack{
                            Picker("会员类型", selection: $selectedProductID) {
                                ForEach(productIDOptions.keys.sorted(), id: \.self) { key in
                                    Text(productIDOptions[key] ?? key).tag(key)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            DatePicker("开始时间", selection: $startDate, in: ...endDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "zh_CN")) // 强制使用中文
                            DatePicker("结束时间", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "zh_CN")) // 强制使用中文
                        }
                    }
                    .scrollIndicators(.hidden)
                    Button("筛选") {
                        Task {
                            fetchFilteredTransactions()
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
                HStack{
                    let month = transactions.filter{$0.productID == "Me.Monthly.Pro" && $0.price != 0}
                    let year = transactions.filter{$0.productID == "Me.Annual.Pro" && $0.price != 0}
                    let lifeTime = transactions.filter{$0.productID == "Me.LifeTimeRro" && $0.price != 0}
                    Text("共有记录：\(transactions.count) 条(月度\(month.count)，年度\(year.count)，永久\(lifeTime.count))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gray)
                    let money = (Double(lifeTime.count) * 68) + (Double(year.count) * 48) + (Double(month.count) * 5)
                    Divider()
                        .frame(height:10)
                    Text("收入： 约\(money * 0.85, specifier: "%.1f")元")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gray)
                }
                
                if transactionService.isLoading {
                    VStack{
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    .frame(maxWidth:.infinity,maxHeight: .infinity)
                } else if let error = transactionService.errorMessage {
                    VStack {
                        Text(error)
                            .foregroundStyle(.red)
                            .padding()
                        Button("重试") {
                            Task {
                                fetchFilteredTransactions()
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(maxWidth:.infinity,maxHeight: .infinity)
                } else if transactions.isEmpty {
                    VStack{
                    Text("暂无交易记录")
                        .foregroundStyle(.gray)
                    }
                    .frame(maxWidth:.infinity,maxHeight: .infinity)
                } else {
                    List(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                    .padding(.top,0)
                }
            }
            .navigationTitle("交易记录")
            .task {
                fetchFilteredTransactions()
            }
            .refreshable {
                fetchFilteredTransactions()
            }
        }
    }
    
    private func fetchFilteredTransactions() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // 与 MySQL DATETIME 兼容
        let startTime = dateFormatter.string(from: startDate)
        let endTime = dateFormatter.string(from: endDate)
        
        print("筛选参数 - startTime: \(startTime), endTime: \(endTime), productID: \(selectedProductID)")
        
        Task {
            if selectedProductID == "All"{
                transactions = await transactionService.fetchTransactions(
                    startTime: startTime,
                    endTime: endTime
                )
            } else {
                transactions = await transactionService.fetchTransactions(
                    startTime: startTime,
                    endTime: endTime,
                    productID: selectedProductID
                )
            }
        }
    }
}

// TransactionRow 保持不变
struct TransactionRow: View {
    let transaction: Transaction
    private var isLifetime: Bool { transaction.productID == "Me.LifeTimeRro" }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    if isLifetime {
                        Circle()
                            .frame(width: 8)
                            .foregroundStyle(.green)
                    }
                    Text(getMembershipName(productID: transaction.productID))
                        .font(.system(size: 14, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(isLifetime ? Color.primary : Color.gray.opacity(0.3))
                    Spacer(minLength: 10)
                }
                Text("购买时间: \(transaction.purchaseDate.formatted(.dateTime.year().month().day().weekday()))")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray.opacity(0.3))
            }
            Spacer(minLength: 10)
            Text("\(transaction.price ?? 0.0, specifier: "%.2f") \(transaction.currency ?? "")")
                .font(.system(size: 14, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(isLifetime ? Color.primary : Color.gray.opacity(0.3))
        }
    }
    
    private func getMembershipName(productID: String) -> String {
        switch productID {
        case "Me.LifeTimeRro": return "永久会员"
        case "Me.Monthly.Pro": return "月度"
        default: return "年度"
        }
    }
}

#Preview {
    TransactionListView()
}
