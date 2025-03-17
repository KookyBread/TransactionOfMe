//
//  TransactionListView.swift
//  TransactionOfMe
//
//  Created by 刘弨 on 2025/3/17.
//

import SwiftUI

struct TransactionListView: View {
    @StateObject var transactionService = TransactionViewModel()
    @State var transactions: [Transaction] = []
    
    var body: some View {
        NavigationView {
            VStack{
                if transactionService.isLoading == true {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    List(transactions) { transaction in
                        HStack{
                            VStack(alignment: .leading){
                                HStack{
                                    if transaction.productID == "Me.LifeTimeRro"{
                                        Circle()
                                            .frame(width:8)
                                            .foregroundStyle(Color.green)
                                        Text(getMemberShipName(productID: transaction.productID))
                                            .font(.system(size: 14))
                                            .fontDesign(.rounded)
                                            .fontWeight(.semibold)
                                    } else {
                                        Text(getMemberShipName(productID: transaction.productID))
                                            .font(.system(size: 14))
                                            .fontDesign(.rounded)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.gray.opacity(0.3))
                                    }
                                    Spacer(minLength: 10)
                                }
                                Text("购买时间: \(transaction.purchaseDate.formatted(.dateTime.year().month().day().weekday()))")
                                    .foregroundStyle(Color.gray.opacity(0.3))
                                    .font(.system(size: 10))
                            }
                            Spacer(minLength: 10)
                            if transaction.productID == "Me.LifeTimeRro"{
                                Text("\(transaction.price ?? 0.0, specifier: "%.2f") \(transaction.currency ?? "")")
                                    .font(.system(size: 14))
                                    .fontDesign(.rounded)
                                    .fontWeight(.semibold)
                            } else {
                                Text("\(transaction.price ?? 0.0, specifier: "%.2f") \(transaction.currency ?? "")")
                                    .font(.system(size: 14))
                                    .fontDesign(.rounded)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.gray.opacity(0.3))
                            }
                        }
                    }
                }
            }
            .navigationTitle("交易记录")
            .task {
                transactions = await transactionService.fetchTransactions()
            }
            .refreshable {
                Task{
                    transactions = await transactionService.fetchTransactions()
                }
            }
        }
    }
    
    func getMemberShipName(productID:String) -> String{
        switch productID{
        case "Me.LifeTimeRro":
            return "永久会员"
        case "Me.Monthly.Pro":
            return "月度"
        default:
            return "年度"
        }
    }
}

#Preview {
    TransactionListView()
}
