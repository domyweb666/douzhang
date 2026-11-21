import SwiftUI

/// 左右兩頁（番茄架、設定）的大標題。
struct PageTitle: View {
    var text: String

    var body: some View {
        Text(text)
            .font(Tokens.Fonts.largeTitle)
            .foregroundStyle(Tokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Tokens.Space.s)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 分段選擇的一個選項。
struct SegmentOption<Value: Hashable>: Identifiable {
    var value: Value
    var label: String

    var id: Value {
        value
    }
}

/// 分段選擇：幾個並排的膠囊，一次只能選一個。
/// 選中＝產品色淡底＋產品色字，另外加粗，不只靠顏色。
/// 換選項帶著動畫：跟著出現、消失、換掉的東西（設定的列、番茄架的檢視）看得出去哪了。
struct Segmented<Value: Hashable>: View {
    var options: [SegmentOption<Value>]
    var value: Value?
    var onChange: (Value) -> Void

    var body: some View {
        FlowRow(spacing: Tokens.Space.s) {
            ForEach(options) { option in
                let isOn = option.value == value
                let ink = isOn ? Tokens.Colors.accentText : Tokens.Colors.textPrimary
                Button {
                    Feel.change { onChange(option.value) }
                } label: {
                    Text(option.label)
                        .font(isOn ? Tokens.Fonts.chip : Tokens.Fonts.sub)
                        .foregroundStyle(ink)
                        .frame(minWidth: Tokens.Shape.tapMin, minHeight: Tokens.Shape.tapMin)
                        .padding(.horizontal, Tokens.Space.card)
                        .background(
                            isOn ? Tokens.Colors.soft : Tokens.Colors.fillButton,
                            in: Capsule()
                        )
                }
                .buttonStyle(FadeStyle())
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

/// 由左到右排，放不下就換行（分段選擇、番茄串、慶祝畫面那排小番茄）。
struct FlowRow: Layout {
    var spacing: CGFloat
    var centered = false

    private struct Line {
        var indexes: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func lines(_ sizes: [CGSize], maxWidth: CGFloat) -> [Line] {
        var lines = [Line()]
        for (index, size) in sizes.enumerated() {
            var line = lines.removeLast()
            let wider = line.indexes.isEmpty ? size.width : line.width + spacing + size.width
            if !line.indexes.isEmpty, wider > maxWidth {
                lines.append(line)
                line = Line()
            }
            line.width = line.indexes.isEmpty ? size.width : line.width + spacing + size.width
            line.height = max(line.height, size.height)
            line.indexes.append(index)
            lines.append(line)
        }
        return lines
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = lines(sizes, maxWidth: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        // 回報內容實際的寬：要撐滿的由呼叫端自己加 frame
        return CGSize(width: rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var top = bounds.minY
        for line in lines(sizes, maxWidth: bounds.width) {
            var left = bounds.minX + (centered ? (bounds.width - line.width) / 2 : 0)
            for index in line.indexes {
                let size = sizes[index]
                let point = CGPoint(x: left, y: top + line.height - size.height)
                subviews[index].place(at: point, proposal: ProposedViewSize(size))
                left += size.width + spacing
            }
            top += line.height + spacing
        }
    }
}

/// 一行輸入框：白底、細框，打字時框換產品色。出現時自己拿到游標。
struct LineInput: View {
    var placeholder: String
    @Binding var text: String
    var maxLength: Int
    var onSubmit: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .submitLabel(.done)
            .focused($focused)
            .onSubmit(onSubmit)
            .onChange(of: text) { _, next in
                if next.count > maxLength {
                    text = String(next.prefix(maxLength))
                }
            }
            .modifier(FieldChrome(focused: focused))
            .onAppear { focused = true }
    }
}

/// 輸入框的樣子：白底、細框、圓角，游標在裡面時框換產品色。
struct FieldChrome: ViewModifier {
    var focused: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Shape.radiusButton)
        let border = focused ? Tokens.Colors.accent : Tokens.Colors.fieldBorder
        return content
            .font(Tokens.Fonts.body)
            .foregroundStyle(Tokens.Colors.textPrimary)
            .tint(Tokens.Colors.accent)
            .padding(.horizontal, Tokens.Space.card)
            .padding(.vertical, Tokens.Space.m)
            .frame(minHeight: Tokens.Shape.field)
            .background(Tokens.Colors.card, in: shape)
            .overlay { shape.stroke(border, lineWidth: Tokens.Shape.hairline) }
    }
}
