import Foundation

/// 一週的番茄放不放得下：全部番茄的面積加起來，跟罐子能裝的比。
enum JarFit {
    /// 放得下回 1；放不下回一個比 1 小的倍數，全部半徑乘上它之後面積加起來剛好是罐子的 share。
    /// 全部一起縮、不是只縮新的：大小是分鐘數換的，一起縮才看得出哪顆長哪顆短。
    static func scale(radii: [Double], width: Double, height: Double, share: Double) -> Double {
        let room = width * height * share
        let area = radii.reduce(0) { $0 + Double.pi * $1 * $1 }
        guard room > 0, area > room else { return 1 }
        return (room / area).squareRoot()
    }
}

/// 傾斜手機時番茄堆的重力往哪邊、多大。
enum JarPull {
    /// 讀數（單位 g，裝置座標）換成番茄堆的重力。斜著拿（往後仰四十度左右）時，往螢幕下面的那份只剩六成多，
    /// 番茄掉得軟綿綿：方向照讀數，大小至少 tiltFloor 倍。幾乎平放時不保底，放在桌上不會一點點歪就整堆衝過去。
    static func gravity(x: Double, y: Double) -> (x: Double, y: Double) {
        let size = hypot(x, y)
        let boost = size < JarTuning.tiltFlat ? 1 : max(size, JarTuning.tiltFloor) / size
        let scale = boost * Tokens.Motion.tiltPerG
        return (x: x * scale, y: -y * scale)
    }
}
