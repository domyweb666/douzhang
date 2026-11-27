import Foundation

/// 鎖定畫面與動態島那張卡的字。擴充不編 Words：這些字由 app 抄進卡片（Core/LivePlan）。
/// 「休息完了」「開始」用原本的 restDone、start。
extension Words {
    /// 響了、還沒收下：卡片上的大字
    static let liveRipe = "熟了"
    /// 休息中：倒數旁邊那行；我自己決定的休息不倒數，大字寫這個
    static let liveResting = "休息中"
}
