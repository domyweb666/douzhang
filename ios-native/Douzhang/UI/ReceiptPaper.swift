import SwiftUI
import UIKit

/// 鈴響頁收據的紙：上面兩個圓角，下緣一排鋸齒。鋸齒的寬會微調，讓一整排剛好放滿。
struct ReceiptPaper: Shape {
    func path(in rect: CGRect) -> Path {
        let tooth = Tokens.Bell.tooth
        let radius = Tokens.Shape.radiusCard
        let edge = rect.maxY - tooth
        let count = max(1, Int((rect.width / (tooth * 2)).rounded()))
        let half = rect.width / CGFloat(count) / 2
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let rightEdge = CGPoint(x: rect.maxX, y: edge)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: edge))
        path.addArc(tangent1End: topLeft, tangent2End: topRight, radius: radius)
        path.addArc(tangent1End: topRight, tangent2End: rightEdge, radius: radius)
        path.addLine(to: rightEdge)
        for index in 0 ..< count {
            let right = rect.maxX - CGFloat(index) * half * 2
            path.addLine(to: CGPoint(x: right - half, y: rect.maxY))
            path.addLine(to: CGPoint(x: right - half * 2, y: edge))
        }
        path.closeSubpath()
        return path
    }
}

/// 收據中間那兩條虛線。
struct DashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// 一條一條的橫線，每條在一行字的底下。
struct RuledLines: Shape {
    var pitch: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard pitch > 0 else { return path }
        let count = Int((rect.height / pitch).rounded())
        for line in stride(from: 1, through: count, by: 1) {
            let lineY = rect.minY + CGFloat(line) * pitch
            path.move(to: CGPoint(x: rect.minX, y: lineY))
            path.addLine(to: CGPoint(x: rect.maxX, y: lineY))
        }
        return path
    }
}

/// 每一行釘成一樣高、會折行的字。不用 Text：它只調得到行距，中文字的行高又跟英文不一樣，
/// 折兩三行之後字就離開線了（筆記本那張紙也是同一個原因）。
struct RuledText: UIViewRepresentable {
    var text: String
    var color: Color
    var pitch: CGFloat
    /// 最多幾行，最後一行結尾「…」
    var lines: Int

    func makeUIView(context _: Context) -> UILabel {
        let label = UILabel()
        label.isAccessibilityElement = false
        return label
    }

    func updateUIView(_ label: UILabel, context _: Context) {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = pitch
        style.maximumLineHeight = pitch
        let ink: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor(color),
            .paragraphStyle: style,
        ]
        label.attributedText = NSAttributedString(string: text, attributes: ink)
        label.numberOfLines = lines
        // 放字之後才設：字帶的段落樣式會把它蓋回折行不加「…」。不寫進段落樣式：那樣每段只剩一行
        label.lineBreakMode = .byTruncatingTail
    }

    /// 不寫這個的話只認一行的寬，長句不會折行。
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView label: UILabel,
        context _: Context
    ) -> CGSize? {
        let most = CGFloat.greatestFiniteMagnitude
        let room = min(proposal.width ?? most, most)
        let fit = label.sizeThatFits(CGSize(width: room, height: most))
        return CGSize(width: min(fit.width, room), height: fit.height)
    }
}
