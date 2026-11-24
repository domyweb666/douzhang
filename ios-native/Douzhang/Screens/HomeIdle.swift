import SwiftUI

/// 標籤膠囊：小番茄＋「專注・25 分」。待機點了換標籤（後面多一個 ›）；計時中點了改在做什麼；休息只是標示。
/// 計時中填了在做什麼，標籤名就換成那句；太長截斷那句，長度照樣看得到。
struct TagChip: View {
    var type: TagType
    var doing = ""
    /// 後面多一個 ›
    var more = false
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
            if doing.isEmpty {
                Text(Words.tagLabel(type, more: more))
            } else {
                HStack(spacing: .zero) {
                    Text(doing).lineLimit(1)
                    Text(Words.lenTail(type.len)).fixedSize()
                }
            }
        }
        .font(Tokens.Fonts.chip)
        .foregroundStyle(Tokens.Colors.accentText)
        .frame(minHeight: Tokens.Shape.tapMin)
        .padding(.horizontal, Tokens.Space.card)
        .background(Tokens.Colors.soft, in: Capsule())
    }
}

/// 置中的小字（提早做完的提醒、鈴響頁的標籤、作廢後那一行）。
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

/// 待機：標籤膠囊、在做什麼、大時間、背景音、開始鈕；最下面留給番茄堆。
/// 剛作廢並選了原因回來時，開始鈕上面多一行事實（這週同一個原因第幾顆），不接建議。
/// 開發版在設定開了「測試模式」，開始鈕就直接開一顆 5 秒的測試番茄。
struct HomeIdle: View {
    @Environment(AppModel.self) private var model
    var type: TagType
    var onTag: () -> Void
    var onDoing: () -> Void
    var onTime: () -> Void
    var onSound: () -> Void

    var body: some View {
        VStack(spacing: .zero) {
            TagChip(type: type, more: true, action: onTag)
                .padding(.top, Tokens.Space.m)
            CompactButton(label: Words.doingChip(model.state.doing), action: onDoing)
                .lineLimit(1)
                .padding(.top, Tokens.Layout.item)
            Button(action: onTime) {
                Text(TimeText.mmss(type.len * Params.msPerMinute))
                    .font(Tokens.Fonts.clockFocus)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    // 換標籤時長度的數字滾過去
                    .modifier(NumberChange(value: type.len))
            }
            .buttonStyle(PressStyle())
            .accessibilityHint(Words.dialHint)
            CompactButton(label: Words.ambienceChip(model.state.settings.ambience), action: onSound)
                .padding(.top, Tokens.Space.m)
            Spacer(minLength: .zero)
            if let line = model.idleLine {
                HomeCaption(text: line)
                    .padding(.bottom, Tokens.Space.m)
            }
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
        .background { IdleLineReset() }
    }
}

/// 滑到別頁就收掉作廢後那一行，回來不會還在。看不見、點不到；自己一個 View，
/// 因為左右滑到一半 page 就會換，讀它的只有這一小塊，待機那頁才不用在滑的時候整塊重算。
struct IdleLineReset: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Color.clear
            .frame(width: .zero, height: .zero)
            .allowsHitTesting(false)
            .onChange(of: model.page) { _, page in
                if page != .home {
                    model.idleLine = nil
                }
            }
    }
}
