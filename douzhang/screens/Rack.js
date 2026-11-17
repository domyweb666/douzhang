// 番茄架（左右滑三頁的左邊那頁）。2026-11-02 U9：上面一排這週七天（‹ › 換週），下面選中那天的時間軸，
// 每顆番茄畫在開始的時刻、高度照長度、裡面寫鈴響時留的那句；作廢是虛線框。點一顆開那天的收據。
// 換週用 ‹ › 不用左右滑：這頁本身在左右滑的分頁裡，再滑一層會搶手勢。
// 沒番茄的日子不寫 0、沒有連續數字（S12、S15）。最下面一列：今天沒收工→收工；今天什麼都沒有→掛葉子（F1、F2）。
// 2026-11-14 照 Domy 重新設計：選中的那天用產品色淡底（同分頁列的選中）、空狀態用 DomyEmptyState、整頁停在分頁列上面。
import { useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { DomyButton, useTabBarClearance } from '@domy/design';
import { CharacterColors, useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { MS_PER_MINUTE } from '../design/params';
import {
  dayTimeline,
  daySum,
  hasRecord,
  rackWeeks,
  shiftWeek,
  weekDays,
  weekStart,
} from '../core/receipt';
import { TextButton } from '../ui/TextButton';
import { PageTitle } from '../ui/PageTitle';
import { typeOf } from '../core/machine';
import { Leaf } from '../ui/Pod';
import { Mascot } from '../ui/Mascot';
import { Tomato } from '../ui/Tomato';
import { DaySheet, WeekSheet } from '../ui/ReceiptSheets';

const MS_PER_HOUR = 60 * MS_PER_MINUTE;

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

/** 上面那排的一天：星期、日期、有紀錄的話下面一顆點（番茄紅；只有葉子就葉子綠）。 */
function DayKey({ dayKey, day, selected, onPress }) {
  const T = useTokens();
  const mode = T._dark ? 'dark' : 'light';
  const has = hasRecord(day);
  const leafOnly = has && day.leaf && !day.beans.length && !day.voids.length;
  const dot = leafOnly ? CharacterColors.leaf[mode] : CharacterColors.pod[mode];
  const fg = selected ? T.color.accentText : T.color.textPrimary;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={words.dayA11y(dayKey, has)}
      accessibilityState={{ selected }}
      onPress={onPress}
      style={{
        width: T.shape.weekDayWidth,
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
          backgroundColor: has ? dot : 'transparent', // token-ok: 沒紀錄的日子不畫點
        }}
      />
    </Pressable>
  );
}

/** ‹ 這週 › ＋七天。下一週只到這週為止。 */
function WeekStrip({ ws, thisWeek, selected, days, onSelect, onShift }) {
  const T = useTokens();
  return (
    <View style={{ marginTop: T.space.m }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <TextButton
          label={words.prevWeek}
          a11yLabel={words.prevWeekA11y}
          onPress={() => onShift(-1)}
        />
        <Text
          style={{ ...T.font.bodyStrong, color: T.color.textPrimary, flex: 1, textAlign: 'center' }}
        >
          {ws === thisWeek ? words.thisWeek : words.weekOf(ws)}
        </Text>
        {ws < thisWeek ? (
          <TextButton
            label={words.nextWeek}
            a11yLabel={words.nextWeekA11y}
            onPress={() => onShift(1)}
          />
        ) : (
          <View style={{ width: T.shape.tapMin }} />
        )}
      </View>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: T.space.s }}>
        {weekDays(ws).map((k) => (
          <DayKey
            key={k}
            dayKey={k}
            day={days[k]}
            selected={k === selected}
            onPress={() => onSelect(k)}
          />
        ))}
      </View>
    </View>
  );
}

/** 時間軸上的一顆番茄或一次作廢。 */
function Block({ item, top, height, type, onPress }) {
  const T = useTokens();
  const mode = T._dark ? 'dark' : 'light';
  const isVoid = item.kind === 'void';
  const sub = { ...T.font.caption, color: T.color.textSecondary };
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={{
        position: 'absolute',
        top,
        height,
        left: T.shape.timelineGutter,
        right: 0,
        overflow: 'hidden',
        borderRadius: T.shape.radiusButton,
        paddingHorizontal: T.space.s,
        paddingVertical: T.space.xs,
        backgroundColor: isVoid ? 'transparent' : CharacterColors.podSoft[mode], // token-ok: 作廢只畫框
        // iOS 的虛線框四邊要一樣寬，所以作廢不畫左邊那條粗邊
        borderWidth: isVoid ? T.shape.hairline : 0,
        borderStyle: isVoid ? 'dashed' : 'solid',
        borderColor: T.color.textSecondary,
        borderLeftWidth: isVoid ? T.shape.hairline : T.shape.timelineEdge,
        borderLeftColor: isVoid ? T.color.textSecondary : CharacterColors.pod[mode],
      }}
    >
      {isVoid ? (
        <Text numberOfLines={1} style={sub}>
          {words.voidLine(item)}
        </Text>
      ) : (
        <>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: T.space.xs }}>
            <Tomato color={type?.color} size={T.shape.blockIcon} />
            <Text style={{ ...T.font.caption, color: T.color.textPrimary }}>
              {words.blockTitle(type?.name || '', item.len, item.flow)}
            </Text>
          </View>
          <Text numberOfLines={2} style={{ ...T.font.sub, color: T.color.textPrimary }}>
            {item.clue || words.noNoteMark}
          </Text>
        </>
      )}
    </Pressable>
  );
}

/** 選中那天：葉子日畫葉子；有番茄或作廢畫時間軸；什麼都沒有就空白（不寫 0）。 */
function DayView({ state, dayKey, onOpen }) {
  const T = useTokens();
  const day = state.days[dayKey];
  const { items, from, to } = dayTimeline(day);
  if (!items.length) {
    if (!day?.leaf) return null;
    return (
      <View style={{ alignItems: 'center', marginTop: T.space.xl, gap: T.space.m }}>
        <Leaf />
        <Text style={{ ...T.font.sub, color: T.color.textSecondary }}>{words.leafDay}</Text>
      </View>
    );
  }
  const perMs = T.shape.timelineHour / MS_PER_HOUR;
  const hours = [];
  for (let t = from; t <= to; t += MS_PER_HOUR) hours.push(t);
  return (
    <View style={{ height: (to - from) * perMs, marginTop: T.space.m }}>
      {hours.map((t) => (
        <View
          key={t}
          style={{
            position: 'absolute',
            top: (t - from) * perMs,
            left: 0,
            right: 0,
            flexDirection: 'row',
            alignItems: 'center',
          }}
        >
          <Text
            style={{
              ...T.font.caption,
              color: T.color.textSecondary,
              width: T.shape.timelineGutter,
            }}
          >
            {words.hourLabel(new Date(t).getHours())}
          </Text>
          <View style={{ flex: 1, height: T.shape.hairline, backgroundColor: T.color.separator }} />
        </View>
      ))}
      {items.map((it) => (
        <Block
          key={`${it.kind}-${it.start}`}
          item={it}
          top={(it.start - from) * perMs}
          height={Math.max(T.shape.timelineBlockMin, (it.end - it.start) * perMs)}
          type={it.typeId ? typeOf(state, it.typeId) : null}
          onPress={onOpen}
        />
      ))}
    </View>
  );
}

/** 換到某一週時選哪天：有今天選今天，不然選那週最後一天有紀錄的，都沒有就週一。 */
function dayToShow(state, ws) {
  const keys = weekDays(ws);
  if (keys.includes(state.todayKey)) return state.todayKey;
  return [...keys].reverse().find((k) => hasRecord(state.days[k])) || keys[0];
}

export function Rack({ state, wiped, active, onSettings, onBack }) {
  const T = useTokens();
  const clearance = useTabBarClearance(); // 收工那列與時間軸底部都停在分頁列上面
  const [selected, setSelected] = useState(state.todayKey);
  const [dayOpen, setDayOpen] = useState(null);
  const [weekOpen, setWeekOpen] = useState(null);
  const thisWeek = weekStart(state.todayKey);
  const ws = weekStart(selected);
  const sum = daySum(state.days[selected]);
  const empty = !rackWeeks(state).length;
  return (
    <View style={{ flex: 1, paddingBottom: clearance }}>
      <View style={{ flexDirection: 'row', alignItems: 'flex-end' }}>
        <View style={{ flex: 1 }}>
          <PageTitle>{words.rack}</PageTitle>
        </View>
        {empty ? null : (
          <TextButton label={words.weekReceiptLink} onPress={() => setWeekOpen(ws)} />
        )}
      </View>
      {empty ? (
        <Empty wiped={wiped} active={active} onBack={onBack} onSettings={onSettings} />
      ) : (
        <>
          <WeekStrip
            ws={ws}
            thisWeek={thisWeek}
            selected={selected}
            days={state.days}
            onSelect={setSelected}
            onShift={(n) => setSelected(dayToShow(state, shiftWeek(ws, n)))}
          />
          <View
            style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: T.space.m }}
          >
            <Text style={{ ...T.font.sub, color: T.color.textSecondary }}>
              {`${words.monthDay(selected)} ${words.weekday(selected)}`}
            </Text>
            {sum ? (
              <Text style={{ ...T.font.sub, color: T.color.textSecondary }}>
                {words.daySumLine(sum.beans, sum.minutes)}
              </Text>
            ) : null}
          </View>
          <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: T.space.l }}>
            <DayView state={state} dayKey={selected} onOpen={() => setDayOpen(selected)} />
          </ScrollView>
        </>
      )}
      <DaySheet
        dayKey={dayOpen}
        day={dayOpen ? state.days[dayOpen] : null}
        onClose={() => setDayOpen(null)}
      />
      <WeekSheet weekStart={weekOpen} state={state} onClose={() => setWeekOpen(null)} />
    </View>
  );
}
