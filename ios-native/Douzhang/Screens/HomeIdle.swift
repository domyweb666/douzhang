import SwiftUI

/// 標籤膠囊：小番茄＋「專注・25 分」。待機時可點（開標籤半頁，後面多一個 ›）；計時中、休息只是標示。
struct TagChip: View {
    var type: TagType
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { chip }.buttonStyle(PressStyle())
        } else {
            chip
        }
    }

    private var chip: some View {
        HStack(spacing: Tokens.Space.xs) {
            TomatoView(color: type.color, size: Tokens.Shape.blockIcon)
            Text(Words.tagLabel(type, more: action != nil))
                .font(Tokens.Fonts.chip)
                .foregroundStyle(Tokens.Colors.accentText)
        }
        .frame(minHeight: Tokens.Shape.tapMin)
        .padding(.horizontal, Tokens.Space.card)
        .background(Tokens.Colors.soft, in: Capsule())
    }
}

/// 時間下面的小字（休息的小標與那句、提早做完的提醒）。
struct HomeCaption: View {
    var text: String

    var body: some View {
        Text(text)
            .font(Tokens.Fonts.sub)
            .foregroundStyle(Tokens.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.top, Tokens.Space.xs)
    }
}

/// 待機：標籤膠囊、大時間、背景音、開始鈕；最下面留給番茄堆。
/// 開發版在設定開了「測試模式」，開始鈕就直接開一顆 5 秒的測試番茄。
struct HomeIdle: View {
    @Environment(AppModel.self) private var model
    var type: TagType
    var onTag: () -> Void
    var onSound: () -> Void

    var body: some View {
        VStack(spacing: .zero) {
            TagChip(type: type, action: onTag)
                .padding(.top, Tokens.Space.m)
            Text(TimeText.mmss(type.len * Params.msPerMinute))
                .font(Tokens.Fonts.clockFocus)
                .foregroundStyle(Tokens.Colors.textPrimary)
            CompactButton(label: Words.ambienceChip(model.state.settings.ambience), action: onSound)
                .padding(.top, Tokens.Space.m)
            Spacer(minLength: .zero)
            if model.state.settings.demo {
                BigButton(label: Words.startTest(Machine.devType.len)) {
                    model.start(typeId: Machine.devTypeId)
                }
            } else {
                BigButton(label: Words.startLabel(type.len)) { model.start() }
            }
            Spacer()
                .frame(height: Tokens.Shape.pileRoom + Tokens.Shape.tabClearance)
        }
    }
}
