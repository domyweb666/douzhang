import SwiftUI

/// 設定頁的「節奏」那一區：休息怎麼結束、短休息、長休息、休息完自動開始。
/// 「我自己決定」的休息沒有長度，短休息、長休息、自動開始三列收起來。
struct SettingsRhythm: View {
    @Environment(AppModel.self) private var model
    var onOpen: (SettingsSheet) -> Void

    private let modes = [
        SegmentOption(value: RestMode.auto, label: Words.restModeAuto),
        SegmentOption(value: RestMode.own, label: Words.restModeSelf),
    ]

    var body: some View {
        let settings = model.state.settings
        SettingsSection(title: Words.rhythm, footer: footer(settings)) {
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Text(Words.restRow)
                    .font(Tokens.Fonts.body)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                Segmented(options: modes, value: settings.restMode) { mode in
                    model.update { $0.restMode = mode }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Tokens.Space.m)
            if settings.restMode == .auto {
                SettingsDivider()
                SettingsRow(label: Words.restShortRow, value: RestWords.short(settings.restShort)) {
                    onOpen(.restShort)
                }
                SettingsDivider()
                SettingsRow(label: Words.restLongRow, value: RestWords.long(settings)) {
                    onOpen(.restLong)
                }
                SettingsDivider()
                SettingsToggle(label: Words.autoNextRow, isOn: settings.autoNext) { isOn in
                    model.update { $0.autoNext = isOn }
                }
            }
        }
    }

    /// 卡片下的說明：休息怎麼算（看得到那幾列時才講）。
    private func footer(_ settings: AppSettings) -> String {
        if settings.restMode == .own { return Words.restSelfSub }
        var lines: [String] = []
        if settings.restShort == .auto { lines.append(Words.restShortAutoSub) }
        if settings.restLongEvery > 0 {
            lines.append(Words.restLongSub(settings.restLongEvery, settings.restLongMinutes))
        }
        lines.append(Words.autoNextSub)
        return lines.joined(separator: "\n")
    }
}

/// 休息那幾列右邊的值怎麼寫。
enum RestWords {
    static func short(_ value: RestShort) -> String {
        switch value {
        case .auto: Words.restShortAuto
        case let .minutes(fixed): Words.minutes(fixed)
        }
    }

    static func long(_ settings: AppSettings) -> String {
        settings.restLongEvery > 0
            ? Words.restLongValue(settings.restLongEvery, settings.restLongMinutes)
            : Words.restLongOff
    }

    static func every(_ count: Int) -> String {
        count > 0 ? Words.restLongEvery(count) : Words.restLongOff
    }
}

/// 短休息半頁：滾輪選「跟著長度」或固定幾分。
struct RestShortSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let selection = Binding(
            get: { model.state.settings.restShort },
            set: { model.setRestShort($0) }
        )
        SheetCard(title: Words.restShortRow) {
            Picker(Words.restShortRow, selection: selection) {
                ForEach(Params.restShortOptions, id: \.self) { option in
                    Text(RestWords.short(option)).tag(option)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            BigButton(label: Words.confirm) { dismiss() }
        }
    }
}

/// 長休息半頁：左邊每幾顆（含「關」）、右邊幾分，兩個滾輪並排。
struct RestLongSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let every = Binding(
            get: { model.state.settings.restLongEvery },
            set: { model.setRestLongEvery($0) }
        )
        let minutes = Binding(
            get: { model.state.settings.restLongMinutes },
            set: { model.setRestLongMinutes($0) }
        )
        SheetCard(title: Words.restLongRow) {
            HStack(spacing: .zero) {
                Picker(Words.restLongRow, selection: every) {
                    ForEach(Params.restLongEveryOptions, id: \.self) { count in
                        Text(RestWords.every(count)).tag(count)
                    }
                }
                Picker(Words.restLongRow, selection: minutes) {
                    ForEach(Params.restLongMinuteOptions, id: \.self) { count in
                        Text(Words.minutes(count)).tag(count)
                    }
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            BigButton(label: Words.confirm) { dismiss() }
        }
    }
}
