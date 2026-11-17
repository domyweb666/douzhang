// 番茄架的月檢視（2026-11-17 AG4）：一格一天，裡面是那天收下的番茄（一顆一個標籤色的小圓點）。
// 沿用蒜日子的「彈性週」：沒番茄的週壓扁成一行，只剩日期。這樣整個月不會出現一排排空格子
// （產品定稿：不製造罪惡感，沒番茄的日子不寫 0）。點一天就切到那天的天檢視。
import { Pressable, Text, View } from 'react-native';
import { CharacterColors, useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { monthWeeks } from '../core/calendar';
import { typeOf } from '../core/machine';

const INK = CharacterColors.tomato;

/** 那天的番茄：依時間排，最多畫 monthDotsMax 顆，再多寫「+N」。 */
function Dots({ state, beans }) {
  const T = useTokens();
  const sorted = beans.slice().sort((a, b) => a.t - b.t);
  const shown = sorted.slice(0, params.monthDotsMax);
  const more = sorted.length - shown.length;
  return (
    <View
      style={{
        flexDirection: 'row',
        flexWrap: 'wrap',
        justifyContent: 'center',
        gap: T.shape.timelineLaneGap,
      }}
    >
      {shown.map((b) => (
        <View
          key={b.t}
          style={{
            width: T.shape.monthDot,
            height: T.shape.monthDot,
            borderRadius: T.shape.radiusPill,
            borderWidth: T.shape.hairline,
            borderColor: INK.ink,
            backgroundColor: INK.body[typeOf(state, b.typeId).color] || INK.body.red,
          }}
        />
      ))}
      {more > 0 ? (
        <Text style={{ ...T.font.tab, color: T.color.textSecondary }}>{words.moreBeans(more)}</Text>
      ) : null}
    </View>
  );
}

/** 一格：日期（今天有產品色淡底）＋那天的番茄。別的月份的日子只寫淡淡的日期；還沒到的日子不能點。 */
function DayCell({ state, day, busy, onPress }) {
  const T = useTokens();
  const today = day.key === state.todayKey;
  const future = day.key > state.todayKey;
  const dim = !day.inMonth || future;
  return (
    <Pressable
      disabled={dim}
      accessibilityRole="button"
      accessibilityLabel={words.monthDayA11y(day.key, day.beans.length)}
      onPress={onPress}
      style={{ flex: 1, alignItems: 'center', gap: T.space.xs, paddingVertical: T.space.xs }}
    >
      <View
        style={{
          paddingHorizontal: T.space.s,
          borderRadius: T.shape.radiusPill,
          backgroundColor: today ? T.color.soft : 'transparent', // token-ok: 不是今天不畫底
        }}
      >
        <Text
          style={{
            ...T.font.caption,
            color: today ? T.color.accentText : dim ? T.color.textTertiary : T.color.textPrimary,
          }}
        >
          {Number(day.key.slice(-2))}
        </Text>
      </View>
      {busy && day.beans.length ? <Dots state={state} beans={day.beans} /> : null}
    </Pressable>
  );
}

/** monthKey：這個月裡任一天的日期鍵。onPickDay(key)：點了某一天。 */
export function MonthGrid({ state, monthKey, onPickDay }) {
  const T = useTokens();
  return (
    <View style={{ marginTop: T.space.m }}>
      <View style={{ flexDirection: 'row' }}>
        {words.weekdayShort.map((name) => (
          <Text
            key={name}
            style={{
              ...T.font.caption,
              color: T.color.textSecondary,
              flex: 1,
              textAlign: 'center',
            }}
          >
            {name}
          </Text>
        ))}
      </View>
      {monthWeeks(state, monthKey).map((week) => (
        <View
          key={week.weekStart}
          style={{
            flexDirection: 'row',
            minHeight: week.busy ? T.shape.monthWeek : T.shape.monthWeekFlat,
            borderTopWidth: T.shape.hairline,
            borderTopColor: T.color.separator,
          }}
        >
          {week.days.map((day) => (
            <DayCell
              key={day.key}
              state={state}
              day={day}
              busy={week.busy}
              onPress={() => onPickDay(day.key)}
            />
          ))}
        </View>
      ))}
    </View>
  );
}
