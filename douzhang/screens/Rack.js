// 番茄架（左右滑三頁的左邊那頁）。2026-11-17 AG4＋AG5 改版：時間帳本。
// 標題右邊切「行事曆｜分析」。行事曆有天／3 天／週／月四種檢視（ui/Timeline.js、ui/MonthGrid.js），
// 分析有日／週／月（ui/Stats.js）。兩邊共用同一個選中的日子與同一列 ‹ 這一段 ›。
// 換一段用 ‹ › 不用左右滑：這頁本身在左右滑的分頁裡，再滑一層會搶手勢。
// 沒番茄的日子不寫 0、沒有連續數字（S12、S15）。收工、掛葉子、這週的收據都拿掉了（AG1、AG5）。
import { useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { DomyButton, useTabBarClearance } from '@domy/design';
import { CharacterColors, useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { daySum, hasRecord, rackWeeks, weekDays, weekStart } from '../core/receipt';
import { VIEW, reachesToday, shiftPeriod, viewDays } from '../core/calendar';
import { RANGE } from '../core/stats';
import { TextButton } from '../ui/TextButton';
import { PageTitle } from '../ui/PageTitle';
import { Segmented } from '../ui/Segmented';
import { Mascot } from '../ui/Mascot';
import { Timeline } from '../ui/Timeline';
import { MonthGrid } from '../ui/MonthGrid';
import { StatsView } from '../ui/Stats';
import { DaySheet } from '../ui/ReceiptSheets';

const MODE = { calendar: 'calendar', stats: 'stats' };
const MODES = [
  { value: MODE.calendar, label: words.rackModeCalendar },
  { value: MODE.stats, label: words.rackModeStats },
];
const VIEWS = [
  { value: VIEW.day, label: words.viewDay },
  { value: VIEW.three, label: words.viewThree },
  { value: VIEW.week, label: words.viewWeek },
  { value: VIEW.month, label: words.viewMonth },
];
const RANGES = [
  { value: RANGE.day, label: words.rangeDay },
  { value: RANGE.week, label: words.viewWeek },
  { value: RANGE.month, label: words.viewMonth },
];

/**
 * 空狀態：第一次是「第一顆響完…」＋回去開始一顆；剛清空是「全部清掉了…」＋去設定匯入（06 豆棚）。
 * Y1：上面站著番茄火柴人，滑到這頁時揮一次手（剛清空時只站著，不揮）。
 * 排版照 DomyEmptyState（它的圖示位是固定大小的圓，放不下一整個人，所以這裡自己排）。
 */
function Empty({ wiped, active, onBack, onSettings }) {
  const T = useTokens();
  return (
    <View
      style={{
        alignItems: 'center',
        gap: T.space.m,
        paddingVertical: T.space.xl,
        paddingHorizontal: T.space.section,
      }}
    >
      <Mascot action="wave" play={active && !wiped} height={T.shape.mascotHeight} />
      <Text style={{ ...T.font.title3, color: T.color.textPrimary, textAlign: 'center' }}>
        {wiped ? words.wipedLine : words.rackEmpty}
      </Text>
      <DomyButton
        size="compact"
        title={wiped ? words.wipedAction : words.rackEmptyAction}
        onPress={wiped ? onSettings : onBack}
        style={{ marginTop: T.space.xs }}
      />
    </View>
  );
}

/** 這一段叫什麼：天＝11月17日 星期二；3 天＝起訖；週＝這週或某月某日那週；月＝2026年11月。 */
function periodTitle(period, selected, todayKey) {
  if (period === VIEW.month) return words.monthTitle(selected);
  if (period === VIEW.week) {
    const ws = weekStart(selected);
    return ws === weekStart(todayKey) ? words.thisWeek : words.weekOf(ws);
  }
  if (period === VIEW.three) {
    const days = viewDays(VIEW.three, selected);
    return words.daysRange(days[0], days[2]);
  }
  return `${words.monthDay(selected)} ${words.weekday(selected)}`;
}

/** ‹ 這一段 ›。畫面上已經有今天就沒有 ›（不往還沒到的日子翻）。 */
function PeriodNav({ period, selected, todayKey, onShift }) {
  const T = useTokens();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: T.space.s }}>
      <TextButton
        label={words.prevWeek}
        a11yLabel={words.prevPeriodA11y}
        onPress={() => onShift(-1)}
      />
      <Text
        style={{ ...T.font.bodyStrong, color: T.color.textPrimary, flex: 1, textAlign: 'center' }}
      >
        {periodTitle(period, selected, todayKey)}
      </Text>
      {reachesToday(period, selected, todayKey) ? (
        <View style={{ width: T.shape.tapMin }} />
      ) : (
        <TextButton
          label={words.nextWeek}
          a11yLabel={words.nextPeriodA11y}
          onPress={() => onShift(1)}
        />
      )}
    </View>
  );
}

/** 一天的小方格：星期、日期、有紀錄的話下面一顆番茄紅的點。selected 的有產品色淡底。 */
function DayKey({ dayKey, day, selected, wide, onPress }) {
  const T = useTokens();
  const has = hasRecord(day);
  const fg = selected ? T.color.accentText : T.color.textPrimary;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={words.dayA11y(dayKey, has)}
      accessibilityState={{ selected }}
      onPress={onPress}
      style={{
        flex: wide ? 1 : undefined,
        width: wide ? undefined : T.shape.weekDayWidth,
        paddingVertical: T.space.xs,
        alignItems: 'center',
        borderRadius: T.shape.radiusButton,
        backgroundColor: selected ? T.color.soft : 'transparent', // token-ok: 沒選的那天不畫底
      }}
    >
      <Text style={{ ...T.font.caption, color: selected ? fg : T.color.textSecondary }}>
        {words.weekday(dayKey).slice(-1)}
      </Text>
      <Text style={{ ...T.font.bodyStrong, color: fg }}>{dayKey.slice(-2).replace(/^0/, '')}</Text>
      <View
        style={{
          width: T.shape.dayDot,
          height: T.shape.dayDot,
          borderRadius: T.shape.radiusPill,
          marginTop: T.space.xs,
          backgroundColor: has ? CharacterColors.pod[T._dark ? 'dark' : 'light'] : 'transparent', // token-ok: 沒紀錄的日子不畫點
        }}
      />
    </Pressable>
  );
}

/**
 * 時間軸上面那排日子。天檢視：這週七天，點了換到那一天。
 * 3 天、週檢視：一欄一個、對齊下面的欄（左邊空出時刻那欄的寬），今天有淡底，點了切到那天的天檢視。
 */
function DayHeads({ state, view, selected, onPick }) {
  const T = useTokens();
  const single = view === VIEW.day;
  const keys = single ? weekDays(weekStart(selected)) : viewDays(view, selected);
  return (
    <View
      style={{
        flexDirection: 'row',
        justifyContent: 'space-between',
        marginTop: T.space.s,
        paddingLeft: single ? 0 : T.shape.timelineGutter,
      }}
    >
      {keys.map((k) => (
        <DayKey
          key={k}
          dayKey={k}
          day={state.days[k]}
          wide={!single}
          selected={single ? k === selected : k === state.todayKey}
          onPress={() => onPick(k)}
        />
      ))}
    </View>
  );
}

/** 天檢視右上那行小計：幾顆、幾分鐘。沒番茄就不寫。 */
function DaySum({ day }) {
  const T = useTokens();
  const sum = daySum(day);
  if (!sum) return null;
  return (
    <Text
      style={{
        ...T.font.sub,
        color: T.color.textSecondary,
        textAlign: 'right',
        marginTop: T.space.s,
      }}
    >
      {words.daySumLine(sum.beans, sum.minutes)}
    </Text>
  );
}

/** 行事曆那一半：月是格子，其他三種是時間軸。 */
function CalendarBody({ state, now, view, selected, onPickDay, onOpenDay }) {
  if (view === VIEW.month)
    return <MonthGrid state={state} monthKey={selected} onPickDay={onPickDay} />;
  return (
    <>
      <DayHeads state={state} view={view} selected={selected} onPick={onPickDay} />
      {view === VIEW.day ? <DaySum day={state.days[selected]} /> : null}
      <Timeline
        state={state}
        keys={viewDays(view, selected)}
        view={view}
        now={now}
        onOpen={onOpenDay}
      />
    </>
  );
}

export function Rack({ state, now, wiped, active, onSettings, onBack }) {
  const T = useTokens();
  const clearance = useTabBarClearance(); // 內容停在分頁列上面
  const [mode, setMode] = useState(MODE.calendar);
  const [view, setView] = useState(VIEW.day);
  const [range, setRange] = useState(RANGE.week);
  const [selected, setSelected] = useState(state.todayKey);
  const [dayOpen, setDayOpen] = useState(null);
  const calendar = mode === MODE.calendar;
  const period = calendar ? view : range; // 日／週／月跟天／週／月是同一組字，換一段的算法共用
  const empty = !rackWeeks(state).length;
  // 天檢視點上面那排是換一天；其他檢視（含月）點某一天是切到那天的天檢視
  const pickDay = (key) => {
    setSelected(key);
    setView(VIEW.day);
  };
  return (
    <View style={{ flex: 1, paddingBottom: clearance }}>
      <View style={{ flexDirection: 'row', alignItems: 'flex-end' }}>
        <View style={{ flex: 1 }}>
          <PageTitle>{words.rack}</PageTitle>
        </View>
        {empty ? null : <Segmented options={MODES} value={mode} onChange={setMode} />}
      </View>
      {empty ? (
        <Empty wiped={wiped} active={active} onBack={onBack} onSettings={onSettings} />
      ) : (
        <>
          <Segmented
            options={calendar ? VIEWS : RANGES}
            value={period}
            onChange={calendar ? setView : setRange}
            style={{ marginTop: T.space.m }}
          />
          <PeriodNav
            period={period}
            selected={selected}
            todayKey={state.todayKey}
            onShift={(step) => setSelected(shiftPeriod(period, selected, step))}
          />
          <ScrollView
            style={{ flex: 1 }}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={{ paddingBottom: T.space.l }}
          >
            {calendar ? (
              <CalendarBody
                state={state}
                now={now}
                view={view}
                selected={selected}
                onPickDay={pickDay}
                onOpenDay={setDayOpen}
              />
            ) : (
              <StatsView state={state} range={range} selected={selected} />
            )}
          </ScrollView>
        </>
      )}
      <DaySheet
        dayKey={dayOpen}
        day={dayOpen ? state.days[dayOpen] : null}
        onClose={() => setDayOpen(null)}
      />
    </View>
  );
}
