import SwiftUI

/// 番茄（描邊表情）：番茄堆、番茄架、選色、慶祝畫面共用。
/// 整顆畫在外接圓裡（100×100 的畫布，圓心 50,50、半徑 50＝物理算的那個圓），轉到哪個角度都不會超出去。
/// 路徑與線條粗細是圖的一部分（單位是那張 100×100 的畫布）；顏色從 Tokens 來。
enum TomatoArt {
    private static let middle: CGFloat = 50
    private static let body = CGRect(x: 6, y: 9, width: 88, height: 88)
    private static let bodyLine: CGFloat = 4
    private static let shineLine: CGFloat = 5
    private static let leafSize = CGSize(width: 24, height: 11)
    private static let leafY: CGFloat = 10
    private static let leafOffset: CGFloat = 13
    private static let leafTurn: CGFloat = 14
    private static let sides: [CGFloat] = [-1, 1]
    private static let leafLine: CGFloat = 3.5
    private static let stemLine: CGFloat = 4
    private static let eyeRadius: CGFloat = 3.8
    private static let eyeY: CGFloat = 55
    private static let eyeOffset: CGFloat = 13
    private static let mouthLine: CGFloat = 3.2
    private static let cheekSize = CGSize(width: 11, height: 6.4)
    private static let cheekY: CGFloat = 64
    private static let cheekOffset: CGFloat = 23

    // 形狀都在那張 100×100 的畫布上、大小交給 scaleBy，所以每種大小共用同一組。
    // 罐子醒著每一格每顆都要畫，第一次用到時建好就一直用（效能審查甲5）；每格只剩位移、旋轉、縮放
    static let bodyPath = Path(ellipseIn: body)
    static let shinePath = makeShine()
    static let leafPaths = sides.map(leafPath)
    static let stemPath = makeStem()
    static let eyePaths = sides.map(eyePath)
    static let cheekPaths = sides.map(cheekPath)
    static let mouthPath = makeMouth()

    // 番茄的顏色都是固定的 RGB，不分深淺模式，也一起先建好
    private static let ink = Tokens.Tomato.ink.color
    private static let leafColor = Tokens.Tomato.leaf.color
    private static let shineColor = Tokens.Tomato.shine.color.opacity(Tokens.Opacity.tomatoShine)
    private static let cheekColor = Tokens.Tomato.shine.color.opacity(Tokens.Opacity.tomatoCheek)
    private static let shineStyle = StrokeStyle(lineWidth: shineLine, lineCap: .round)
    private static let stemStyle = StrokeStyle(lineWidth: stemLine, lineCap: .round)
    private static let mouthStyle = StrokeStyle(lineWidth: mouthLine, lineCap: .round)
    private static let bodyColors = Dictionary(
        uniqueKeysWithValues: TomatoColor.allCases.map { ($0, Tokens.Tomato.body($0).color) }
    )

    /// 標籤的身體色（先建好的那一份）。
    static func bodyColor(_ color: TomatoColor) -> Color {
        bodyColors[color] ?? Tokens.Tomato.body(color).color
    }

    /// 在 center 畫一顆半徑 radius 的番茄，轉 angle 弧度（順時針為正），身體塗 fill。
    static func draw(
        _ context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        angle: Double,
        fill: Color
    ) {
        var layer = context
        layer.translateBy(x: center.x, y: center.y)
        layer.rotate(by: .radians(angle))
        layer.scaleBy(x: radius / middle, y: radius / middle)
        layer.translateBy(x: -middle, y: -middle)
        let inked = GraphicsContext.Shading.color(ink)
        layer.fill(bodyPath, with: .color(fill))
        layer.stroke(bodyPath, with: inked, lineWidth: bodyLine)
        layer.stroke(shinePath, with: .color(shineColor), style: shineStyle)
        for leaf in leafPaths {
            layer.fill(leaf, with: .color(leafColor))
            layer.stroke(leaf, with: inked, lineWidth: leafLine)
        }
        layer.stroke(stemPath, with: inked, style: stemStyle)
        for (eye, cheek) in zip(eyePaths, cheekPaths) {
            layer.fill(eye, with: inked)
            layer.fill(cheek, with: .color(cheekColor))
        }
        layer.stroke(mouthPath, with: inked, style: mouthStyle)
    }

    private static func makeShine() -> Path {
        var shine = Path()
        shine.move(to: CGPoint(x: 19, y: 44))
        shine.addCurve(
            to: CGPoint(x: 38, y: 21),
            control1: CGPoint(x: 21, y: 33),
            control2: CGPoint(x: 28, y: 25)
        )
        return shine
    }

    /// side −1 左、1 右。兩片葉子以中線對稱，各往外轉一點。
    private static func leafPath(side: CGFloat) -> Path {
        let centerX = middle + side * leafOffset
        let rect = CGRect(
            x: centerX - leafSize.width / 2,
            y: leafY - leafSize.height / 2,
            width: leafSize.width,
            height: leafSize.height
        )
        let turn = CGAffineTransform(translationX: centerX, y: leafY)
            .rotated(by: side * leafTurn * .pi / 180)
            .translatedBy(x: -centerX, y: -leafY)
        return Path(ellipseIn: rect).applying(turn)
    }

    private static func makeStem() -> Path {
        var stem = Path()
        stem.move(to: CGPoint(x: middle, y: 11))
        stem.addLine(to: CGPoint(x: middle, y: 3.5))
        return stem
    }

    private static func eyePath(side: CGFloat) -> Path {
        let eyeX = middle + side * eyeOffset
        let eye = CGRect(
            x: eyeX - eyeRadius,
            y: eyeY - eyeRadius,
            width: eyeRadius * 2,
            height: eyeRadius * 2
        )
        return Path(ellipseIn: eye)
    }

    private static func cheekPath(side: CGFloat) -> Path {
        let cheekX = middle + side * cheekOffset
        let blush = CGRect(
            x: cheekX - cheekSize.width / 2,
            y: cheekY - cheekSize.height / 2,
            width: cheekSize.width,
            height: cheekSize.height
        )
        return Path(ellipseIn: blush)
    }

    private static func makeMouth() -> Path {
        var mouth = Path()
        mouth.move(to: CGPoint(x: 43.5, y: 63))
        mouth.addQuadCurve(to: CGPoint(x: 56.5, y: 63), control: CGPoint(x: 50, y: 69.5))
        return mouth
    }
}

/// 一顆番茄。純裝飾，讀屏略過。
struct TomatoView: View {
    var fill: Color
    var size: CGFloat

    init(fill: Color, size: CGFloat) {
        self.fill = fill
        self.size = size
    }

    /// 標籤的番茄色。
    init(color: TomatoColor, size: CGFloat) {
        self.init(fill: Tokens.Tomato.body(color).color, size: size)
    }

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            TomatoArt.draw(
                &context,
                center: center,
                radius: canvasSize.width / 2,
                angle: 0,
                fill: fill
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 計時中在長的那顆：每一格直接從時間算大小，不用動畫補，所以回前景、換到聚焦模式都不會追一段。
/// 位子固定是全熟大小、整顆等比縮放：改 frame 會每次對到像素，一格一格跳。
/// 再做一下的那段已經熟了，減少動態時也不長：都固定全熟大小，不必每格重算。
struct GrowingTomato: View {
    var run: FocusRun
    var fill: Color
    /// 全熟大小
    var size: CGFloat
    /// 畫面時鐘
    var now: Millis

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let still = reduceMotion || run.flowed
        // 只在背景停：回前景的過場（inactive）就要開始算，露出來的第一格才是對的大小
        let paused = still || scenePhase == .background
        TimelineView(.animation(minimumInterval: Grow.redraw(run), paused: paused)) { timeline in
            TomatoView(fill: fill, size: size)
                .scaleEffect(still ? 1 : scale(at: timeline.date))
        }
    }

    /// 兩個時刻取晚的：TimelineView 停著的時候它的時刻會留在過去，番茄不能縮回去。
    private func scale(at frame: Date) -> CGFloat {
        let time = max(now, frame.timeIntervalSince1970 * Params.msPerSecond)
        return CGFloat(Grow.scale(Grow.progress(.focus(run), now: time)))
    }
}
