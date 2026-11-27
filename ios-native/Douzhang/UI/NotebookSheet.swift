import SwiftUI
import UIKit

/// 專注筆記的筆記本：整頁橫線紙，打開就能寫很多行，右上打勾關掉。
/// 每個字都寫回呼叫端的 text，存不存由呼叫端決定：鈴響頁每字都存，所以下滑關掉也不會少字；
/// 番茄架「改這顆的字」寫回它的草稿，按「好」才存。
struct NotebookSheet: View {
    @Binding var text: String

    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var pitch = Tokens.Notebook.line

    var body: some View {
        VStack(spacing: .zero) {
            HStack {
                Text(Words.noteTitle)
                    .font(Tokens.Fonts.section)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: .zero)
                doneButton
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .padding(.top, Tokens.Layout.section)
            PaperEditor(text: $text, pitch: pitch)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) { placeholder }
                .padding(.top, Tokens.Layout.item)
        }
        .background(Tokens.Colors.card.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Tokens.Shape.radiusSheet)
    }

    /// 右上的打勾。圖示的右緣對齊紙上的線，多出來的點擊範圍往外伸進頁邊。
    private var doneButton: some View {
        Button { dismiss() } label: {
            LineIconView(kind: .check)
                .foregroundStyle(Tokens.Colors.accentText)
                .frame(width: Tokens.Shape.tapMin, height: Tokens.Shape.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(FadeStyle())
        .accessibilityLabel(Words.confirm)
        .padding(.trailing, (Tokens.Shape.tabIcon - Tokens.Shape.tapMin) / 2)
    }

    /// 還沒寫字時坐在第一條線上的提示。
    @ViewBuilder private var placeholder: some View {
        if text.isEmpty {
            Text(Words.notePlaceholder)
                .font(Tokens.Fonts.body)
                .foregroundStyle(Tokens.Colors.textTertiary)
                .lineLimit(1)
                .frame(height: pitch, alignment: .bottom)
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// 橫線紙上的輸入框。不用 TextEditor：它只調得到行距，中文字的行高又跟英文不一樣，
/// 字會越寫越離開線。這裡把每一行釘成一樣高，字才會一行一行坐在線上。
struct PaperEditor: UIViewRepresentable {
    @Binding var text: String
    var pitch: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> PaperTextView {
        let view = PaperTextView(frame: .zero, textContainer: nil)
        view.setUp()
        view.delegate = context.coordinator
        view.rule(pitch: pitch)
        view.show(text)
        return view
    }

    func updateUIView(_ view: PaperTextView, context: Context) {
        context.coordinator.text = $text
        view.rule(pitch: pitch)
        // 注音還在組字時不動，不然會被打斷
        if view.markedTextRange == nil, view.text != text {
            view.show(text)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            let typed: String = textView.text ?? ""
            let kept = String(typed.prefix(Params.noteMaxChars))
            text.wrappedValue = kept
            guard let paper = textView as? PaperTextView,
                  paper.markedTextRange == nil else { return }
            if kept == typed {
                paper.keepInk()
            } else {
                paper.show(kept)
            }
        }
    }
}

/// 每行一樣高的輸入框，橫線畫在字後面、跟著一起捲。放上畫面就拿游標。
final class PaperTextView: UITextView {
    private let lines = PaperLines()
    private var pitch: CGFloat = 0

    private var ink: [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = pitch
        style.maximumLineHeight = pitch
        return [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor(Tokens.Colors.textPrimary),
            .paragraphStyle: style,
        ]
    }

    func setUp() {
        let margin = Tokens.Layout.screenMargin
        backgroundColor = .clear
        tintColor = UIColor(Tokens.Colors.accent)
        textContainerInset = UIEdgeInsets(top: 0, left: margin, bottom: margin, right: margin)
        textContainer.lineFragmentPadding = 0
        alwaysBounceVertical = true
        keyboardDismissMode = .interactive
        accessibilityLabel = Words.noteTitle
        lines.isUserInteractionEnabled = false
        lines.isOpaque = false
        lines.backgroundColor = .clear
        lines.contentMode = .redraw
        insertSubview(lines, at: 0)
    }

    /// 換行高（系統字級變了）：線與已經寫的字一起換。
    func rule(pitch next: CGFloat) {
        guard next != pitch else { return }
        pitch = next
        lines.pitch = next
        show(text ?? "")
    }

    /// 整段換成這些字，游標在最後。
    func show(_ next: String) {
        attributedText = NSAttributedString(string: next, attributes: ink)
        keepInk()
    }

    /// 刪到空的之後系統會忘記行高，接著打的字就不在線上：每次改完都再給一次。
    func keepInk() {
        typingAttributes = ink
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            _ = becomeFirstResponder()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = max(contentSize.height, bounds.height)
        lines.frame = CGRect(x: 0, y: 0, width: bounds.width, height: height)
    }

    /// 游標照字的高度，不要跟一整行一樣高。
    override func caretRect(for position: UITextPosition) -> CGRect {
        let full = super.caretRect(for: position)
        let height = min(full.height, UIFont.preferredFont(forTextStyle: .body).lineHeight)
        return CGRect(x: full.minX, y: full.maxY - height, width: full.width, height: height)
    }
}

/// 一條一條的橫線，每條在一行字的底下。
final class PaperLines: UIView {
    var pitch: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }

    override func draw(_: CGRect) {
        guard pitch > 0, let context = UIGraphicsGetCurrentContext() else { return }
        let margin = Tokens.Layout.screenMargin
        let width = bounds.width - margin * 2
        context.setFillColor(UIColor(Tokens.Colors.separator).cgColor)
        var lineY = pitch
        while lineY <= bounds.height {
            let line = CGRect(x: margin, y: lineY, width: width, height: Tokens.Shape.hairline)
            context.fill(line)
            lineY += pitch
        }
    }
}
