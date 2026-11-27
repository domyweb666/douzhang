import Foundation

/// 果子掉下來之前掛在藤上的那一段（QC-0008 第 58 筆）：垂下來、越晃越大、藤斷、剩下的藤縮回去。
enum JarHang {
    /// 果子中心停在螢幕頂往下這麼遠：動態島下面、標題上面。支點在螢幕頂，所以也是擺長
    static let reach = 120.0
    /// 支點左右隨機多少；同時掛兩顆時，兩顆邊到邊至少隔多少
    static let spread = 40.0
    static let gap = 40.0
    /// 還沒垂下來時藏在螢幕頂上面，藏半徑的幾倍
    static let hidden = 1.2
    /// 垂下來、斷了之後藤縮回去各多久（秒）
    static let growTime = 0.3
    static let retractTime = 0.3
    /// 擺到多大（弧度）：從這麼小一路到這麼大，換成左右是 6、33pt
    static let swayFrom = 0.05
    static let swayTo = 0.28
    /// 晃得多快（弧度/秒）：照擺長的自然頻率 √(g/L)，一個來回約 2 秒。
    /// 原本 0.9 秒晃 1.25 個來回，等於用八倍重力在甩，斷了卻用一倍重力掉，前後兩段的快慢接不起來
    static let swing = (JarTuning.standard.gravity / reach).squareRoot()
    /// 晃到哪個相位斷：一邊、另一邊，快到頂之前。停在頂會直直掉，過了中間斷會被甩去撞牆；
    /// 這裡斷開時橫向約 64pt/秒，落地時偏出去大約 75pt
    static let swayEnd = 1.5 * Double.pi - 0.5
    /// 晃多久（秒）、從開始垂到藤斷一共多久
    static let swayTime = swayEnd / swing
    static let cutAt = growTime + swayTime

    /// 藤的綠色有多粗（半徑的幾成，夾在最細最粗之間）、描邊是綠色的幾成
    static let vineShare = 0.12
    static let vineMin = 2.0
    static let vineMax = 5.0
    static let inkShare = 0.5
    /// 果子的蒂頭在中心往上半徑的幾成（跟著番茄那張圖）
    static let stemShare = 0.93
    /// 藤彎多少：晃的時候中間稍微落後，不是一根硬棒子
    static let bend = 0.15
}
