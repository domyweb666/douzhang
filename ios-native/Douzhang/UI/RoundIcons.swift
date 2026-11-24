import SwiftUI

/// 主畫面的小圖示（線條畫，跟分頁列同一套）。座標是 24×24 畫布上的圖形本身，不是版面數字。
struct LineIcon: Shape {
    enum Kind {
        case music, pencil, focus, updown
    }

    var kind: Kind

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch kind {
        case .music: drawMusic(&path)
        case .pencil: drawPencil(&path)
        case .focus: drawFocus(&path)
        case .updown: drawUpdown(&path)
        }
        let scale = rect.width / Tokens.Shape.tabIcon
        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }

    private func circle(_ path: inout Path, x: CGFloat, y: CGFloat, radius: CGFloat) {
        let side = radius * 2
        path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: side, height: side))
    }

    /// 背景音：兩個音符
    private func drawMusic(_ path: inout Path) {
        path.addLines([
            CGPoint(x: 9, y: 18),
            CGPoint(x: 9, y: 6),
            CGPoint(x: 19, y: 4),
            CGPoint(x: 19, y: 16),
        ])
        circle(&path, x: 6.5, y: 18, radius: 2.5)
        circle(&path, x: 16.5, y: 16, radius: 2.5)
    }

    /// 記一筆、改在做什麼：一支筆
    private func drawPencil(_ path: inout Path) {
        path.addLines([
            CGPoint(x: 4, y: 20),
            CGPoint(x: 5, y: 16),
            CGPoint(x: 16, y: 5),
            CGPoint(x: 19, y: 8),
            CGPoint(x: 8, y: 19),
        ])
        path.closeSubpath()
    }

    /// 聚焦：四個角圍著一個圓
    private func drawFocus(_ path: inout Path) {
        let near: CGFloat = 4
        let far: CGFloat = 20
        for x in [near, far] {
            for y in [near, far] {
                corner(&path, tip: CGPoint(x: x, y: y))
            }
        }
        circle(&path, x: 12, y: 12, radius: 3)
    }

    /// 一個角：從直的那段轉圓角到橫的那段，兩段都往中間伸。
    private func corner(_ path: inout Path, tip: CGPoint) {
        let reach: CGFloat = 5
        let middle = Tokens.Shape.tabIcon / 2
        let end = CGPoint(x: tip.x < middle ? tip.x + reach : tip.x - reach, y: tip.y)
        path.move(to: CGPoint(x: tip.x, y: tip.y < middle ? tip.y + reach : tip.y - reach))
        path.addArc(tangent1End: tip, tangent2End: end, radius: 2)
        path.addLine(to: end)
    }

    /// 可以改長度：上下兩個箭頭
    private func drawUpdown(_ path: inout Path) {
        path.addLines([CGPoint(x: 8, y: 9), CGPoint(x: 12, y: 5), CGPoint(x: 16, y: 9)])
        path.addLines([CGPoint(x: 8, y: 15), CGPoint(x: 12, y: 19), CGPoint(x: 16, y: 15)])
    }
}

/// 畫好線條、定好大小的圖示；顏色跟著外面的 foregroundStyle。純裝飾，讀屏略過。
struct LineIconView: View {
    var kind: LineIcon.Kind
    var size = Tokens.Shape.tabIcon

    var body: some View {
        // 圖縮小，線也跟著縮，粗細的感覺才一樣
        let line = Tokens.Shape.tabIconLine * size / Tokens.Shape.tabIcon
        LineIcon(kind: kind)
            .stroke(style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// 圓鈕：白圓裡一個圖示，下面一行小字（現在的值或名字）。圓跟字都按得到。
/// 寬由呼叫端給；字太長就截斷，讀屏念的是 a11yLabel 與 a11yValue。
struct RoundIconButton: View {
    enum Face {
        case line(LineIcon.Kind)
        case tomato(TomatoColor)
    }

    var face: Face
    var label: String
    var a11yLabel: String
    var a11yValue = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Tokens.Layout.item) {
                icon
                    .frame(width: Tokens.Home.round, height: Tokens.Home.round)
                    .background(Tokens.Colors.card, in: Circle())
                Text(label)
                    .font(Tokens.Fonts.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(Tokens.Colors.textPrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        // 一欄的寬是固定的，字再放大三個字就放不下；讀屏念得到整句
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(a11yLabel)
        .accessibilityValue(a11yValue)
    }

    @ViewBuilder private var icon: some View {
        switch face {
        case let .line(kind): LineIconView(kind: kind)
        case let .tomato(color): TomatoView(color: color, size: Tokens.Home.roundTomato)
        }
    }
}

/// 待機的開始鈕：一顆大圓，產品色底。字放不進圓裡（測試模式那句）就縮。
struct StartButton: View {
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Tokens.Fonts.title)
                .lineLimit(1)
                .minimumScaleFactor(Tokens.Home.shrink)
                .foregroundStyle(Tokens.Colors.onAccent)
                .padding(.horizontal, Tokens.Layout.cardPad)
                .frame(width: Tokens.Home.start, height: Tokens.Home.start)
                .background(Tokens.Colors.accent, in: Circle())
                // 圓外面的四個角要讓番茄堆接到點擊
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
    }
}
