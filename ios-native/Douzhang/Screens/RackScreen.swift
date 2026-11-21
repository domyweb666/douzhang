import SwiftUI

/// 番茄架上面那一半看什麼：行事曆或分析。
enum RackMode: Hashable {
    case calendar, stats
}

/// 點開看收據的那一天。
struct OpenDay: Identifiable {
    var id: String
}

/// 番茄架（左右滑三頁的左邊那頁）：時間帳本。
/// 標題右邊切「行事曆｜分析」。行事曆有天／3 天／週／月四種檢視，分析有日／週／月。
/// 兩邊共用同一個選中的日子與同一列 ‹ 這一段 ›。
/// 換一段用 ‹ › 不用左右滑：這頁本身在左右滑的分頁裡，再滑一層會搶手勢。
/// 沒番茄的日子不寫 0、沒有連續數字。
struct RackScreen: View {
    @Environment(AppModel.self) private var model
    @State private var mode = LaunchOptions.rackMode
    @State private var view = LaunchOptions.rackView
    @State private var range = StatsRange.week
    /// 選中的日子；空的＝還沒選過，就是今天
    @State private var picked = ""
    @State private var openDay: OpenDay?

    private let modes = [
        SegmentOption(value: RackMode.calendar, label: Words.rackModeCalendar),
        SegmentOption(value: RackMode.stats, label: Words.rackModeStats),
    ]

    private let views = [
        SegmentOption(value: RackView.day, label: Words.viewDay),
        SegmentOption(value: RackView.three, label: Words.viewThree),
        SegmentOption(value: RackView.week, label: Words.viewWeek),
        SegmentOption(value: RackView.month, label: Words.viewMonth),
    ]

    private let ranges = [
        SegmentOption(value: StatsRange.day, label: Words.rangeDay),
        SegmentOption(value: StatsRange.week, label: Words.viewWeek),
        SegmentOption(value: StatsRange.month, label: Words.viewMonth),
    ]

    private var selected: String {
        picked.isEmpty ? model.todayKey : picked
    }

    /// 日／週／月跟天／週／月是同一組，換一段的算法共用
    private var period: RackView {
        mode == .calendar ? view : range.view
    }

    var body: some View {
        let isEmpty = !Receipt.hasAnyRecord(model.state)
        VStack(alignment: .leading, spacing: .zero) {
            HStack(alignment: .bottom) {
                PageTitle(text: Words.rack)
                if !isEmpty {
                    Segmented(options: modes, value: mode) { mode = $0 }.fixedSize()
                }
            }
            if isEmpty {
                empty
            } else {
                filled
            }
        }
        // 空狀態時裡面沒有會撐滿的東西：整塊貼齊最上面，不然標題會掉到畫面中間
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.bottom, Tokens.Shape.tabClearance)
        .sheet(item: $openDay) { day in
            DaySheet(dayKey: day.id, day: model.state.days[day.id])
        }
    }

    /// 空狀態：第一次是「第一顆響完…」＋回去開始一顆；剛清空是「全部清掉了…」＋去設定匯入。
    private var empty: some View {
        VStack(spacing: Tokens.Space.m) {
            Text(model.wiped ? Words.wipedLine : Words.rackEmpty)
                .font(Tokens.Fonts.title3)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
            CompactButton(
                label: model.wiped ? Words.wipedAction : Words.rackEmptyAction,
                primary: true
            ) {
                withAnimation { model.page = model.wiped ? .settings : .home }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.xl)
        .padding(.horizontal, Tokens.Space.section)
    }

    private var filled: some View {
        VStack(spacing: .zero) {
            Group {
                if mode == .calendar {
                    Segmented(options: views, value: view) { view = $0 }
                } else {
                    Segmented(options: ranges, value: range) { range = $0 }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Tokens.Space.m)
            periodNav
            ScrollView {
                Group {
                    if mode == .calendar {
                        calendar
                    } else {
                        StatsPanel(state: model.state, range: range, selected: selected)
                    }
                }
                .padding(.bottom, Tokens.Space.l)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// 這一段叫什麼：天＝11月17日 星期二；3 天＝起訖；週＝這週或某月某日那週；月＝2026年11月。
    private var periodTitle: String {
        switch period {
        case .month:
            return Words.monthTitle(selected)
        case .week:
            let weekStart = DayKeys.weekStart(selected)
            let isThisWeek = weekStart == DayKeys.weekStart(model.todayKey)
            return isThisWeek ? Words.thisWeek : Words.weekOf(weekStart)
        case .three:
            let days = RackCalendar.viewDays(.three, selected: selected)
            return Words.daysRange(days.first ?? selected, days.last ?? selected)
        case .day:
            return Words.dayTitle(selected)
        }
    }

    /// ‹ 這一段 ›。畫面上已經有今天就沒有 ›（不往還沒到的日子翻）。
    private var periodNav: some View {
        let today = model.todayKey
        let atToday = RackCalendar.reachesToday(period, selected: selected, todayKey: today)
        return HStack {
            TextButton(label: Words.prevPeriod, a11yLabel: Words.prevPeriodA11y) { shift(-1) }
            Text(periodTitle)
                .font(Tokens.Fonts.bodyStrong)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .frame(maxWidth: .infinity)
            TextButton(label: Words.nextPeriod, a11yLabel: Words.nextPeriodA11y) { shift(1) }
                .opacity(atToday ? 0 : 1)
                .disabled(atToday)
        }
        .padding(.top, Tokens.Space.s)
    }

    private func shift(_ step: Int) {
        picked = RackCalendar.shiftPeriod(period, selected: selected, step: step)
    }

    /// 天檢視點上面那排是換一天；其他檢視（含月）點某一天是切到那天的天檢視。
    private func pickDay(_ key: String) {
        picked = key
        view = .day
    }

    /// 行事曆那一半：月是格子，其他三種是時間軸。
    @ViewBuilder private var calendar: some View {
        let state = model.state
        if view == .month {
            MonthGrid(
                state: state,
                monthKey: selected,
                todayKey: model.todayKey,
                onPickDay: pickDay
            )
        } else {
            RackDayHeads(
                state: state,
                view: view,
                selected: selected,
                todayKey: model.todayKey,
                onPick: pickDay
            )
            if view == .day, let sum = Receipt.daySum(state.days[selected]) {
                // 天檢視右上那行小計：幾顆、幾分鐘。沒番茄就不寫
                Text(Words.daySumLine(sum.beans, sum.minutes))
                    .font(Tokens.Fonts.sub)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, Tokens.Space.s)
            }
            RackTimeline(
                state: state,
                keys: RackCalendar.viewDays(view, selected: selected),
                view: view,
                now: model.now,
                todayKey: model.todayKey
            ) { key in
                openDay = OpenDay(id: key)
            }
        }
    }
}

/// 時間軸上面那排日子。天檢視：這週七天，點了換到那一天。
/// 3 天、週檢視：一欄一個、對齊下面的欄（左邊空出時刻那欄的寬），今天有淡底，點了切到那天的天檢視。
struct RackDayHeads: View {
    var state: AppState
    var view: RackView
    var selected: String
    var todayKey: String
    var onPick: (String) -> Void

    var body: some View {
        let isSingle = view == .day
        let weekKeys = DayKeys.weekDays(DayKeys.weekStart(selected))
        let keys = isSingle ? weekKeys : RackCalendar.viewDays(view, selected: selected)
        HStack(spacing: .zero) {
            ForEach(keys, id: \.self) { key in
                cell(key, lit: isSingle ? key == selected : key == todayKey)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.leading, isSingle ? .zero : Tokens.Rack.timelineGutter)
        .padding(.top, Tokens.Space.s)
    }

    /// 一天的小方格：星期、日期、有紀錄的話下面一顆番茄紅的點。lit 的有產品色淡底。
    private func cell(_ key: String, lit: Bool) -> some View {
        let hasRecord = Receipt.hasRecord(state.days[key])
        let ink = lit ? Tokens.Colors.accentText : Tokens.Colors.textPrimary
        return Button {
            onPick(key)
        } label: {
            VStack(spacing: .zero) {
                Text(Words.weekdayShort[DayKeys.weekdayIndex(key)])
                    .font(Tokens.Fonts.caption)
                    .foregroundStyle(lit ? ink : Tokens.Colors.textSecondary)
                Text(String(Int(key.suffix(2)) ?? 0))
                    .font(Tokens.Fonts.bodyStrong)
                    .foregroundStyle(ink)
                Circle()
                    .fill(hasRecord ? Tokens.Tomato.pod : .clear)
                    .frame(width: Tokens.Shape.dayDot, height: Tokens.Shape.dayDot)
                    .padding(.top, Tokens.Space.xs)
            }
            .padding(.vertical, Tokens.Space.xs)
            .frame(minWidth: Tokens.Shape.weekDayWidth)
            .background(
                lit ? Tokens.Colors.soft : .clear,
                in: RoundedRectangle(cornerRadius: Tokens.Shape.radiusButton)
            )
        }
        .buttonStyle(FadeStyle())
        .accessibilityLabel(Words.dayA11y(key, hasRecord: hasRecord))
        .accessibilityAddTraits(lit ? .isSelected : [])
    }
}
