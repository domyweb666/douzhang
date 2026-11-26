import SwiftUI

/// 畫藤：綠色、墨色描邊，跟番茄同一套畫風。
enum JarVineArt {
    /// 一截藤。果子還掛著就畫到蒂頭，斷了就畫到縮回去的那一端。time 是這截藤走到哪一刻。
    static func draw(_ context: inout GraphicsContext, vine: JarVine, time: Double) {
        let pose = vine.pose(at: time)
        let rest = vine.rest(at: time)
        let length = (pose.y / cos(pose.angle) - vine.radius * JarHang.stemShare) * rest
        // 斷了之後邊縮邊擺回正下方
        let angle = pose.angle * rest
        guard length > 0 else { return }
        let green = min(JarHang.vineMax, max(JarHang.vineMin, vine.radius * JarHang.vineShare))
        let ink = green * JarHang.inkShare
        // 往上多畫一截，圓頭才不會露在螢幕頂
        let top = CGPoint(x: vine.pivotX, y: -green)
        let tip = CGPoint(x: vine.pivotX + length * sin(angle), y: length * cos(angle))
        var path = Path()
        path.move(to: top)
        path.addQuadCurve(
            to: tip,
            control: CGPoint(
                x: vine.pivotX + length * sin(angle) * (0.5 - JarHang.bend),
                y: length / 2
            )
        )
        stroke(&context, path, color: Tokens.Tomato.ink.color, width: green + ink * 2)
        stroke(&context, path, color: Tokens.Tomato.vine.color, width: green)
    }

    private static func stroke(
        _ context: inout GraphicsContext,
        _ path: Path,
        color: Color,
        width: Double
    ) {
        let style = StrokeStyle(lineWidth: width, lineCap: .round)
        context.stroke(path, with: .color(color), style: style)
    }
}
