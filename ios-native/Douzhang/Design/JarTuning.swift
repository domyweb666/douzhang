import Foundation

/// 番茄堆物理的數值。翻自 Expo 版 Tokens.js 的 motion.jarPhysics、beanTap、shape.beanRadius
/// 與 params.js 的 jar。手感是在真機上調出來的，搬過來改過底上的摩擦（QC-0008 第 59 筆），
/// 2026-11-27 為了掉落與滾動順一點又改了空氣阻力、摩擦、迭代次數（見各行）。
extension JarTuning {
    static let standard = JarTuning(
        gravity: 1100,
        // 原本 0.996：一秒只剩 62%，掉下來像掛著降落傘。現在一秒剩 94%，幾乎是自由落體
        airDamp: 0.9995,
        wallRest: 0.3,
        // 空氣阻力變小，底上的摩擦補回去：每步「空氣×摩擦」跟原本一樣（0.996×0.993），
        // 所以斜 5 度滾 400pt 還是 7.3 秒、斜 15 度 2.7 秒，放平後 80pt/s 約 1.2 秒停，歪不到 1 度不會自己爬。
        // 牆與開始鈕、分頁列也用這組（原本牆是每次碰到乘 0.97，一步碰好幾次，貼牆的像黏住）
        rollFric: 0.9895,
        rollStop: 15,
        beanRest: 1.25,
        // 原本 4：大小差很多的擠在一起推不開。一百顆照「可能碰到的那幾對」算，8 次也很省
        iterations: 8,
        // 一週一堆：一百顆在模擬裡一步要推 2000 對上下，比原本 40 顆全部配對還少；再多只放最近的
        maxBeans: 120,
        settleSteps: 360,
        pairSlack: 4,
        // 40 顆 25 分的面積約佔一支 iPhone 畫面的 28%，堆到開始鈕下緣附近；超過三成就全部縮小
        fillShare: 0.3,
        spin: SpinTuning(
            grip: 0.25,
            air: 0.995,
            touch: 0.5,
            // 原本 0.1（約慢 80 毫秒）。現在只有兩顆都沒貼著底互相帶時用
            smooth: 0.25,
            still: 8,
            sleep: 0.02,
            lean: 0.6
        ),
        radius: 28,
        sizeRefMinutes: 25,
        sizeMin: 0.5,
        sizeMax: 1.9,
        tapRadius: 110,
        tapUp: 650,
        tapSide: 5
    )

    /// 物理一步走多久（秒）。物理的數值有些是「每一步」的：步長固定，60Hz、120Hz 的螢幕手感才一樣。
    static let tick = JarWorld.frame / Double(Tokens.Motion.substeps)

    /// 畫面跟著螢幕刷新畫，最慢、最快、想要的格率：落在兩步之間的用內插補。
    static let framesMin: Float = 80
    static let framesMax: Float = 120

    /// 傾斜時重力每一步往新方向靠多少：走 substeps 步剛好等於每 1/60 秒靠 tiltSmooth。
    /// tiltSmooth 原本 0.15（慢 0.1 秒）壓原始加速度計的手抖；現在讀系統融合好的重力，改 0.4。
    static let tiltPull = 1 - pow(1 - Tokens.Motion.tiltSmooth, 1 / Double(Tokens.Motion.substeps))

    /// 醒著時傾斜感測器一秒讀幾次：一步 1/120 秒，讀太慢重力會一格一格跳
    static let tiltRate = 100.0

    /// 傾斜時重力至少幾 g（多米選的）：斜著拿手機時番茄照樣掉得乾脆。比 tiltFlat 還平就不保底
    static let tiltFloor = 0.85
    static let tiltFlat = 0.2

    /// 睡著之前那一整段加起來也不准走超過這麼遠（pt）。躺好的原地抖，淨移動都在 0.5 以內
    static let quietDrift = 1.0

    /// 番茄堆跟分頁列左右置中差不到這麼多（pt）才算停好在這一頁：滑到一半量到的框不拿來擺分頁列
    static let restAlign = 0.5
}
