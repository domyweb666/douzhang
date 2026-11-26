import SwiftUI

/// 分頁列的三個圖示（線條畫）。座標是 24×24 畫布上的圖形本身，不是版面數字。
struct TabIcon: Shape {
    var page: Page

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch page {
        case .rack: drawRack(&path)
        case .home: drawHome(&path)
        case .settings: drawSettings(&path)
        }
        let scale = rect.width / Tokens.Shape.tabIcon
        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }

    private func line(
        _ path: inout Path,
        _ fromX: CGFloat,
        _ fromY: CGFloat,
        _ toX: CGFloat,
        _ toY: CGFloat
    ) {
        path.move(to: CGPoint(x: fromX, y: fromY))
        path.addLine(to: CGPoint(x: toX, y: toY))
    }

    /// 番茄架：一週的格子
    private func drawRack(_ path: inout Path) {
        let frame = CGRect(x: 3, y: 5, width: 18, height: 16)
        path.addRoundedRect(in: frame, cornerSize: CGSize(width: 3, height: 3))
        line(&path, 3, 10, 21, 10)
        line(&path, 8, 3, 8, 7)
        line(&path, 16, 3, 16, 7)
    }

    /// 主畫面：一顆番茄
    private func drawHome(_ path: inout Path) {
        path.addEllipse(in: CGRect(x: 5, y: 7, width: 14, height: 14))
        line(&path, 12, 7, 12, 3.5)
        path.move(to: CGPoint(x: 8.5, y: 6))
        path.addLine(to: CGPoint(x: 12, y: 7.5))
        path.addLine(to: CGPoint(x: 15.5, y: 6))
    }

    /// 設定：兩條滑桿
    private func drawSettings(_ path: inout Path) {
        line(&path, 4, 7, 13, 7)
        line(&path, 17, 7, 20, 7)
        line(&path, 4, 17, 7, 17)
        line(&path, 11, 17, 20, 17)
        path.addEllipse(in: CGRect(x: 13, y: 5, width: 4, height: 4))
        path.addEllipse(in: CGRect(x: 7, y: 15, width: 4, height: 4))
    }
}

/// 下面的懸浮膠囊分頁列（照 Domy 的樣子）。選中的那格有產品色淡底。
struct TabBar: View {
    @Binding var page: Page?
    /// 膠囊在螢幕上的框（不含下面留的空）
    var onFrame: (CGRect) -> Void

    private let tabs: [(page: Page, label: String)] = [
        (.rack, Words.rack),
        (.home, Words.home),
        (.settings, Words.settings),
    ]

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            ForEach(tabs, id: \.page) { tab in
                let isOn = tab.page == page
                Button {
                    withAnimation(Tokens.Motion.transition) { page = tab.page }
                } label: {
                    VStack(spacing: Tokens.Space.xs / 2) {
                        TabIcon(page: tab.page)
                            .stroke(style: iconStroke)
                            .frame(width: Tokens.Shape.tabIcon, height: Tokens.Shape.tabIcon)
                        Text(tab.label)
                            .font(Tokens.Fonts.tab)
                            .fontWeight(isOn ? .semibold : .medium)
                            .lineLimit(1)
                    }
                    .foregroundStyle(isOn ? Tokens.Colors.accentText : Tokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(isOn ? Tokens.Colors.soft : .clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(FadeStyle())
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(Tokens.Space.xs * 1.5)
        .frame(width: Tokens.Shape.tabBarWidth, height: Tokens.Shape.tabBar)
        .background { plate }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            onFrame(frame)
        }
        .padding(.bottom, Tokens.Shape.tabBarBottom)
        .haptic(.selection, trigger: page)
    }

    /// 影子只掛在膠囊底上：掛在整組內容上的話，圖示與字也要一起算影子，滑動時每一格都算一次。
    private var plate: some View {
        Capsule()
            .fill(Tokens.Colors.card)
            .shadow(
                color: Tokens.Colors.shadow.opacity(Tokens.Shape.tabShadow.opacity),
                radius: Tokens.Shape.tabShadow.radius,
                y: Tokens.Shape.tabShadow.y
            )
    }

    private var iconStroke: StrokeStyle {
        StrokeStyle(lineWidth: Tokens.Shape.tabIconLine, lineCap: .round, lineJoin: .round)
    }
}
