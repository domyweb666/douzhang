import SwiftUI

/// 五顆番茄並排選色，選中的那顆外面一圈茄紫。
struct TomatoColorRow: View {
    var value: TomatoColor
    var onChange: (TomatoColor) -> Void

    var body: some View {
        HStack {
            ForEach(TomatoColor.allCases, id: \.self) { color in
                let isOn = color == value
                Button {
                    onChange(color)
                } label: {
                    TomatoView(color: color, size: Tokens.Shape.colorSwatch)
                        .frame(width: Tokens.Shape.tapPrimary, height: Tokens.Shape.tapPrimary)
                        .background(isOn ? Tokens.Colors.soft : .clear, in: Circle())
                        .overlay {
                            Circle().stroke(
                                isOn ? Tokens.Colors.accent : .clear,
                                lineWidth: Tokens.Shape.selectRing
                            )
                        }
                }
                .buttonStyle(FadeStyle())
                .accessibilityLabel(Words.tomatoColorName(color))
                .accessibilityAddTraits(isOn ? .isSelected : [])
                if color != TomatoColor.allCases.last {
                    Spacer(minLength: .zero)
                }
            }
        }
    }
}

/// 一個標籤的編輯：改名、番茄色、滾輪選長度、這個長度最近怎麼結束的那一行、最下面刪除（只剩一個時沒有）。
/// 改了立刻存，「好」只是關。
/// 主畫面的標籤半頁與設定頁共用。
struct TagEditor: View {
    @Environment(AppModel.self) private var model
    var type: TagType
    var canDelete: Bool
    var onClose: () -> Void

    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        SheetCard(title: type.name) {
            TextField(Words.typeNameA11y, text: $name)
                .submitLabel(.done)
                .focused($nameFocused)
                .modifier(FieldChrome(focused: nameFocused))
                .onSubmit(saveName)
                .onChange(of: nameFocused) { _, focused in
                    if !focused {
                        saveName()
                    }
                }
            TomatoColorRow(value: type.color) { model.setTypeColor(type.id, color: $0) }
                .padding(.top, Tokens.Space.m)
            lengthWheel
            lengthNote
            BigButton(label: Words.confirm) {
                saveName()
                onClose()
            }
            if canDelete {
                TextButton(label: Words.deleteThisType, tone: .danger) {
                    onClose()
                    Feel.change { model.removeType(type.id) }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.Space.s)
            }
        }
        .onAppear { name = type.name }
        // 清空存成「未命名」時，框裡要跟著顯示新名字
        .onChange(of: type.name) { _, next in name = next }
    }

    /// 系統的滾輪（滾動有系統的輕觸覺）。長度只能從刻度選。
    private var lengthWheel: some View {
        let selection = Binding(
            get: { type.len },
            set: { model.setTypeLen(type.id, len: $0) }
        )
        return Picker(Words.taskType, selection: selection) {
            ForEach(Params.typeLengths, id: \.self) { len in
                Text(Words.typeLen(len)).tag(len)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }

    /// 這個長度最近幾顆怎麼結束的。只列計數，長度要不要調她自己看；換了長度就從新長度重新數。
    private var lengthNote: some View {
        let outcome = Insights.lengthOutcome(model.state, type: type, now: TimeText.nowMillis())
        return Text(Words.lengthLine(outcome, len: type.len))
            .font(Tokens.Fonts.caption)
            .foregroundStyle(Tokens.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Tokens.Space.m)
    }

    private func saveName() {
        if name != type.name {
            model.renameType(type.id, name: name)
        }
    }
}

/// 標籤格裡的一格：小番茄、名字、長度。選中的有茄紫框與淡底。
struct TagCell: View {
    var type: TagType
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s) {
                TomatoView(color: type.color, size: Tokens.Shape.colorSwatch)
                VStack(alignment: .leading, spacing: .zero) {
                    Text(type.name)
                        .font(Tokens.Fonts.bodyStrong)
                        .foregroundStyle(Tokens.Colors.textPrimary)
                        .lineLimit(1)
                    Text(Words.typeLen(type.len))
                        .font(Tokens.Fonts.caption)
                        .foregroundStyle(Tokens.Colors.textSecondary)
                }
                Spacer(minLength: .zero)
            }
            .modifier(TagCellChrome(selected: selected))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(type.name)，\(Words.typeLen(type.len))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 標籤格每一格的外框與底。
struct TagCellChrome: ViewModifier {
    var selected: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Shape.radiusButton)
        return content
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.s)
            .frame(maxWidth: .infinity, minHeight: Tokens.Shape.tapPrimary)
            .background(selected ? Tokens.Colors.soft : Tokens.Colors.fillButton, in: shape)
            .overlay {
                shape.stroke(
                    selected ? Tokens.Colors.accent : .clear,
                    lineWidth: Tokens.Shape.selectRing
                )
            }
    }
}

/// 「這顆要做」：兩欄排開，點一個標籤就換成它並關掉。
/// 點「＋ 新標籤」：加一個、同一張半頁換成它的編輯，按好之後選中它。
struct TagPickSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var editingId: String?

    private let columns = [
        GridItem(.flexible(), spacing: Tokens.Space.s),
        GridItem(.flexible(), spacing: Tokens.Space.s),
    ]

    var body: some View {
        let settings = model.state.settings
        if let editingId, let type = settings.types.first(where: { $0.id == editingId }) {
            TagEditor(type: type, canDelete: settings.types.count > 1) {
                model.pickType(editingId)
                dismiss()
            }
        } else {
            SheetCard(title: Words.thisToDo) {
                LazyVGrid(columns: columns, spacing: Tokens.Space.s) {
                    ForEach(settings.types) { type in
                        TagCell(type: type, selected: type.id == settings.typeId) {
                            model.pickType(type.id)
                            dismiss()
                        }
                    }
                    Button {
                        Feel.change { editingId = model.addType() }
                    } label: {
                        Text(Words.newTag)
                            .font(Tokens.Fonts.bodyStrong)
                            .foregroundStyle(Tokens.Colors.accentText)
                            .modifier(TagCellChrome(selected: false))
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
    }
}
