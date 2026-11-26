import Foundation

/// 番茄堆物理的數值。翻自 Expo 版 Tokens.js 的 motion.jarPhysics、beanTap、shape.beanRadius
/// 與 params.js 的 jar。手感是在真機上調出來的，搬過來只改過底上的摩擦（QC-0008 第 59 筆）。
extension JarTuning {
    static let standard = JarTuning(
        gravity: 1100,
        airDamp: 0.996,
        wallRest: 0.3,
        wallFric: 0.97,
        // 原本底也用 0.97：一秒剩 2.6%，斜 5 度要 17 秒才滾過 400pt，像黏在膠上。
        // 這組：斜 5 度 7.3 秒、斜 15 度 2.7 秒，放平後 80pt/s 約 1.2 秒看起來就停，歪不到 1 度不會自己爬
        rollFric: 0.993,
        rollStop: 15,
        beanRest: 1.25,
        iterations: 4,
        maxBeans: 40,
        settleSteps: 360,
        spin: SpinTuning(
            grip: 0.25,
            air: 0.995,
            touch: 0.5,
            smooth: 0.1,
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

    /// 多久重畫一次（秒）：每一個螢幕刷新都畫，最快到 120Hz，落在兩步之間的用內插補。
    /// 比一步少一點：剛好一步時，螢幕時刻差一點點就會多等一格。
    static let redraw = tick * 0.9

    /// 傾斜時重力每一步往新方向靠多少：走 substeps 步剛好等於每 1/60 秒靠 tiltSmooth。
    static let tiltPull = 1 - pow(1 - Tokens.Motion.tiltSmooth, 1 / Double(Tokens.Motion.substeps))

    /// 睡著之前那一整段加起來也不准走超過這麼遠（pt）。躺好的原地抖，淨移動都在 0.5 以內
    static let quietDrift = 1.0

    /// 番茄堆跟分頁列左右置中差不到這麼多（pt）才算停好在這一頁：滑到一半量到的框不拿來擺分頁列
    static let restAlign = 0.5
}
