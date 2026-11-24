import Foundation

/// 一份資料裡有幾天收過番茄、一共幾顆：匯入前的確認框要先講。只有作廢的日子不算。
struct BeanTally: Equatable {
    let days: Int
    let beans: Int

    init(_ state: AppState) {
        let counts = state.days.values.map(\.beans.count).filter { $0 > 0 }
        days = counts.count
        beans = counts.reduce(0, +)
    }
}
