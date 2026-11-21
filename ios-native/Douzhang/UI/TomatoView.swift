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
        let ink = GraphicsContext.Shading.color(Tokens.Tomato.ink.color)
        let round = StrokeStyle(lineWidth: stemLine, lineCap: .round)
        let bodyPath = Path(ellipseIn: body)
        layer.fill(bodyPath, with: .color(fill))
        layer.stroke(bodyPath, with: ink, lineWidth: bodyLine)
        drawShine(&layer)
        for side in sides {
            let leaf = leafPath(side: side)
            layer.fill(leaf, with: .color(Tokens.Tomato.leaf.color))
            layer.stroke(leaf, with: ink, lineWidth: leafLine)
        }
        layer.stroke(stemPath(), with: ink, style: round)
        drawFace(&layer, ink: ink)
    }

    private static func drawShine(_ layer: inout GraphicsContext) {
        var shine = Path()
        shine.move(to: CGPoint(x: 19, y: 44))
        shine.addCurve(
            to: CGPoint(x: 38, y: 21),
            control1: CGPoint(x: 21, y: 33),
            control2: CGPoint(x: 28, y: 25)
        )
        let white = Tokens.Tomato.shine.color.opacity(Tokens.Opacity.tomatoShine)
        let style = StrokeStyle(lineWidth: shineLine, lineCap: .round)
        layer.stroke(shine, with: .color(white), style: style)
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

    private static func stemPath() -> Path {
        var stem = Path()
        stem.move(to: CGPoint(x: middle, y: 11))
        stem.addLine(to: CGPoint(x: middle, y: 3.5))
        return stem
    }

    private static func drawFace(_ layer: inout GraphicsContext, ink: GraphicsContext.Shading) {
        let cheek = Tokens.Tomato.shine.color.opacity(Tokens.Opacity.tomatoCheek)
        for side in sides {
            let eyeX = middle + side * eyeOffset
            let eye = CGRect(
                x: eyeX - eyeRadius,
                y: eyeY - eyeRadius,
                width: eyeRadius * 2,
                height: eyeRadius * 2
            )
            layer.fill(Path(ellipseIn: eye), with: ink)
            let cheekX = middle + side * cheekOffset
            let blush = CGRect(
                x: cheekX - cheekSize.width / 2,
                y: cheekY - cheekSize.height / 2,
                width: cheekSize.width,
                height: cheekSize.height
            )
            layer.fill(Path(ellipseIn: blush), with: .color(cheek))
        }
        var mouth = Path()
        mouth.move(to: CGPoint(x: 43.5, y: 63))
        mouth.addQuadCurve(to: CGPoint(x: 56.5, y: 63), control: CGPoint(x: 50, y: 69.5))
        layer.stroke(mouth, with: ink, style: StrokeStyle(lineWidth: mouthLine, lineCap: .round))
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
