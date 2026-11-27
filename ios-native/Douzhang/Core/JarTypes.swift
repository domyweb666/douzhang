import Foundation

/// 轉動的參數：只影響畫出來的角度，不回頭動位置與速度。
struct SpinTuning {
    /// 兩顆都沒貼著底的互相帶時，每一步往「滾動不打滑」靠多少（牆不帶轉）
    var grip: Double
    /// 半空中每一步留下多少轉速
    var air: Double
    /// 離底或別顆這麼近就算貼著（pt）
    var touch: Double
    /// 兩顆互相帶時，實際移動先平滑（每一步往新量到的靠多少），濾掉擠在堆裡原地來回抖的
    var smooth: Double
    /// 移動慢於這個（pt/秒）轉動跟著漸弱（照速度的平方），躺好的才不會自己慢慢轉、停下來也不是一刀切
    var still: Double
    /// 轉速小於這個（弧度/秒）就歸零
    var sleep: Double
    /// 開機安置與剛掉進來的那顆，一開始最多歪這麼多（弧度）
    var lean: Double
}

/// 番茄堆物理吃的一包數字。數值在 Design/JarTuning.swift，這裡不寫死。
struct JarTuning {
    var gravity: Double
    var airDamp: Double
    var wallRest: Double
    /// 在底上滾、貼著牆或擋路的東西滑：每一步留下多少，再固定扣多少（pt/秒²）
    var rollFric: Double
    var rollStop: Double
    var beanRest: Double
    var iterations: Int
    /// 最多畫幾顆：再多只放最近的。上限看效能，不看罐子放不放得下（放不下由 fillShare 等比縮小）
    var maxBeans: Int
    var settleSteps: Int
    /// 每一步開頭找「可能碰到的那幾對」時多看這麼遠（pt）：同一步裡互相推開還會再移動一點
    var pairSlack: Double
    /// 番茄加起來的面積最多佔罐子的幾成，超過就全部等比縮小（留給堆疊的空隙也算在裡面）
    var fillShare: Double
    var spin: SpinTuning
    /// 25 分那顆的半徑
    var radius: Double
    var sizeRefMinutes: Double
    var sizeMin: Double
    var sizeMax: Double
    var tapRadius: Double
    var tapUp: Double
    var tapSide: Double

    /// 貼著東西滾或滑一步之後還剩多快。要兩種一起：只照比例扣，快停的時候會拖很久，
    /// 手機放在歪一點點的桌上也會一直慢慢爬；只扣固定的，輕輕一斜推不動。
    func rolled(_ velocity: Double, seconds: Double) -> Double {
        let kept = velocity * rollFric
        let stop = rollStop * seconds
        return abs(kept) <= stop ? 0 : kept - (kept < 0 ? -stop : stop)
    }
}

/// 番茄堆裡的一顆要畫成什麼樣：多長（決定大小）、哪個標籤色。
struct JarBean: Equatable {
    var len: Double
    var color: TomatoColor
}

/// 堆裡的一顆。angle 是弧度、順時針為正，只給畫用。
struct JarBody: Equatable {
    var id: Int
    var x: Double
    var y: Double
    var radius: Double
    var velX = 0.0
    var velY = 0.0
    /// 這一步開始前的位置與角度：轉動用「實際移動了多少」算，畫面在前後兩步之間補
    var prevX = 0.0
    var prevY = 0.0
    var prevAngle = 0.0
    /// 平滑過的實際移動速度
    var easedX = 0.0
    var easedY = 0.0
    /// 從上面掉進來、還沒落地的。落地那一幀要回報（啵＋觸覺）
    var fresh = false
    var angle = 0.0
    var spin = 0.0

    /// 這一步從這裡開始走。
    mutating func markStep() {
        prevX = x
        prevY = y
        prevAngle = angle
    }

    /// 畫面落在前後兩步之間時畫在哪裡：0＝這一步開始前，1＝走完。
    func between(_ blend: Double) -> JarBody {
        var shown = self
        shown.x = prevX + (x - prevX) * blend
        shown.y = prevY + (y - prevY) * blend
        shown.angle = prevAngle + (angle - prevAngle) * blend
        return shown
    }
}
