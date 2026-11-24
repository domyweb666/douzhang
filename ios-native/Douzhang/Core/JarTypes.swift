import Foundation

/// 轉動的參數：只影響畫出來的角度，不回頭動位置與速度。
struct SpinTuning {
    /// 貼著底或別顆時，每一步往「滾動不打滑」靠多少（牆不帶轉）
    var grip: Double
    /// 半空中每一步留下多少轉速
    var air: Double
    /// 離底或別顆這麼近就算貼著（pt）
    var touch: Double
    /// 實際移動先平滑（每一步往新量到的靠多少），濾掉擠在堆裡原地來回抖的
    var smooth: Double
    /// 平滑後不到這個速度（pt/秒）當作沒動，躺好的才不會自己慢慢轉
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
    var wallFric: Double
    var beanRest: Double
    var iterations: Int
    var maxBeans: Int
    var settleSteps: Int
    var spin: SpinTuning
    /// 25 分那顆的半徑
    var radius: Double
    var sizeRefMinutes: Double
    var sizeMin: Double
    var sizeMax: Double
    var tapRadius: Double
    var tapUp: Double
    var tapSide: Double
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
    /// 這一步開始前的位置：轉動用「實際移動了多少」算
    var prevX = 0.0
    var prevY = 0.0
    /// 平滑過的實際移動速度
    var easedX = 0.0
    var easedY = 0.0
    /// 從上面掉進來、還沒落地的。落地那一幀要回報（啵＋觸覺）
    var fresh = false
    var angle = 0.0
    var spin = 0.0
}
