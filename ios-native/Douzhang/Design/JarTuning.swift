import Foundation

/// 番茄堆物理的數值。翻自 Expo 版 Tokens.js 的 motion.jarPhysics、beanTap、shape.beanRadius
/// 與 params.js 的 jar。手感是在真機上調出來的，搬過來一個數字都沒動。
extension JarTuning {
    static let standard = JarTuning(
        gravity: 1100,
        airDamp: 0.996,
        wallRest: 0.3,
        wallFric: 0.97,
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
}
