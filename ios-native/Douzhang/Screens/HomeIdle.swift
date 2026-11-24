import SwiftUI

/// 標籤膠囊：小番茄＋「專注・25 分」。計時中點了改在做什麼；休息只是標示。
/// 計時中填了在做什麼，標籤名就換成那句；太長截斷那句，長度照樣看得到。
struct TagChip: View {
    var type: TagType
    var doing = ""
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { chip }.buttonStyle(PressStyle())
        } else {
            chip
        }
    }

    private var chip: some View {
        HStack(spacing: Tokens.Layout.tight) {
            TomatoView(color: type.color, size: Tokens.Shape.blockIcon)
            if doing.isEmpty {
                Text(Words.tagLabel(type)).lineLimit(1)
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
        .padding(.horizontal, Tokens.Layout.cardPad)
        .background(Tokens.Colors.soft, in: Capsule())
    }
}

/// 置中的小字（標過提早做完、鈴響後很久才回來、作廢後那一行）。
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

/// 待機：「在做什麼」那句與大時間一組，下面一排背景音、開始、標籤；最下面留給番茄堆。
/// 剛作廢並選了原因回來時，開始鈕上面多一行事實（這週同一個原因第幾顆），不接建議。
/// 開發版在設定開了「測試模式」，開始鈕就直接開一顆 5 秒的測試番茄。
/// 空白處的點擊要落到後面的番茄堆，所以這裡的容器不加 contentShape。
struct HomeIdle: View {
    @Environment(AppModel.self) private var model
    var type: TagType
    var onTag: () -> Void
    var onDoing: () -> Void
    var onTime: () -> Void
    var onSound: () -> Void

    var body: some View {
        VStack(spacing: .zero) {
            VStack(spacing: Tokens.Layout.group) {
                doingButton
                timeButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) { voidLine }
            .padding(.top, Tokens.Layout.pageTop)
            shutter
            Spacer()
                .frame(height: Tokens.Home.pileRoom + Tokens.Layout.bottomClear)
        }
        // 這一頁不捲動：字再放大，那句會壓到大時間
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background { IdleLineReset() }
    }

    /// 那句右邊有一支筆：左邊補一樣寬的空，那句才是真的置中。
    private var doingButton: some View {
        let doing = model.state.doing
        let isBlank = doing.isEmpty
        return Button(action: onDoing) {
            HStack(spacing: Tokens.Layout.item) {
                Text(isBlank ? Words.doing : doing)
                    .font(isBlank ? Tokens.Fonts.section : Tokens.Fonts.title)
                    .foregroundStyle(
                        isBlank ? Tokens.Colors.textSecondary : Tokens.Colors.textPrimary
                    )
                    .lineLimit(1)
                LineIconView(kind: .pencil, size: Tokens.Home.sideIcon)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
            .padding(.leading, Tokens.Home.sideIcon + Tokens.Layout.item)
            .frame(minHeight: Tokens.Shape.tapMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Words.doing)
        .accessibilityValue(doing)
    }

    /// 右邊的上下箭頭同樣在左邊補一樣寬的空。
    private var timeButton: some View {
        Button(action: onTime) {
            HStack(spacing: Tokens.Layout.tight) {
                Text(TimeText.mmss(type.len * Params.msPerMinute))
                    .font(Tokens.Fonts.clockFocus)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(Tokens.Home.shrink)
                    // 換標籤時長度的數字滾過去
                    .modifier(NumberChange(value: type.len))
                LineIconView(kind: .updown, size: Tokens.Home.sideIcon)
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
            .padding(.leading, Tokens.Home.sideIcon + Tokens.Layout.tight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Words.lengthA11y)
        .accessibilityValue(Words.typeLen(type.len))
        .accessibilityHint(Words.dialHint)
    }

    /// 疊在開始鈕上方的空白處，不佔版面：出現、消失時大時間不會跳。
    @ViewBuilder private var voidLine: some View {
        if let line = model.idleLine {
            HomeCaption(text: line)
                .padding(.bottom, Tokens.Layout.group)
                .allowsHitTesting(false)
        }
    }

    /// 開始鈕在正中，左右兩顆圓鈕平分剩下的寬。
    private var shutter: some View {
        let settings = model.state.settings
        return HStack(spacing: Tokens.Layout.group) {
            RoundIconButton(
                face: .line(.music),
                label: Words.ambienceChip(settings.ambience),
                a11yLabel: Words.ambienceTitle,
                a11yValue: Words.ambienceKind(settings.ambience),
                action: onSound
            )
            .frame(maxWidth: .infinity)
            if settings.demo {
                StartButton(label: Words.startTest(Machine.devType.len)) {
                    model.start(typeId: Machine.devTypeId)
                }
            } else {
                StartButton(label: Words.start) { model.start() }
            }
            RoundIconButton(
                face: .tomato(type.color),
                label: type.name,
                a11yLabel: Words.taskType,
                a11yValue: type.name,
                action: onTag
            )
            .frame(maxWidth: .infinity)
        }
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
