// 豆棚（推進頁）：這週每天一列，右邊一串豆莢；點一天看收據；「翻到背面」看這週的收據。
// 沒豆子的日子不出現、不出現 0、沒有連續數字（S12、S15）。收工入口 F1 接。
import { useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { podItems, rackWeeks } from '../core/receipt';
import { TextButton } from '../ui/TextButton';
import { Leaf, Pod } from '../ui/Pod';
import { DaySheet, WeekSheet } from '../ui/ReceiptSheets';

function NavBar({ onBack }) {
  const T = useTokens();
  return (
    <View
      style={{
        height: T.shape.tapMin,
        marginTop: T.space.s,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
      }}
    >
      <TextButton flush label={words.back} onPress={onBack} />
      <Text style={{ ...T.font.body, color: T.color.textPrimary }}>{words.rack}</Text>
      <View style={{ minWidth: T.shape.tapPrimary }} />
    </View>
  );
}

function Group({ children }) {
  const T = useTokens();
  return (
    <View
      style={{
        backgroundColor: T.color.card,
        borderRadius: T.shape.radiusCard,
        paddingHorizontal: T.space.l,
        marginTop: T.space.s,
      }}
    >
      {children}
    </View>
  );
}

function Row({ children, onPress, last }) {
  const T = useTokens();
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => ({
        minHeight: T.shape.tapPrimary,
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: T.space.s,
        borderBottomWidth: last ? 0 : T.shape.hairline,
        borderBottomColor: T.color.separator,
        opacity: pressed ? T.opacity.pressed : 1,
      })}
    >
      {children}
    </Pressable>
  );
}

function DayRow({ dayKey, day, onPress }) {
  const T = useTokens();
  const leafOnly = day.leaf && !day.beans.length;
  return (
    <Row onPress={onPress}>
      <View style={{ width: T.shape.tapPrimary * 1.5 }}>
        <Text style={{ ...T.font.body, color: T.color.textPrimary }}>{words.monthDay(dayKey)}</Text>
        <Text style={{ ...T.font.caption, color: T.color.textSecondary }}>
          {words.weekday(dayKey)}
        </Text>
      </View>
      <View style={{ flex: 1 }}>{leafOnly ? <Leaf /> : <Pod items={podItems(day)} />}</View>
      <Text style={{ ...T.font.body, color: T.color.textSecondary }}>›</Text>
    </Row>
  );
}

function Empty({ onBack }) {
  const T = useTokens();
  return (
    <Group>
      <Text
        style={{
          ...T.font.sub,
          color: T.color.textSecondary,
          textAlign: 'center',
          marginTop: T.space.l,
        }}
      >
        {words.rackEmpty}
      </Text>
      <TextButton
        label={words.rackEmptyAction}
        onPress={onBack}
        style={{ alignSelf: 'center', marginVertical: T.space.m }}
      />
    </Group>
  );
}

export function Rack({ state, onBack }) {
  const T = useTokens();
  const [dayOpen, setDayOpen] = useState(null);
  const [weekOpen, setWeekOpen] = useState(null);
  const weeks = rackWeeks(state);
  const thisWeek = weeks.find((w) => w.days.includes(state.todayKey))?.weekStart;
  return (
    <View style={{ flex: 1 }}>
      <NavBar onBack={onBack} />
      <ScrollView contentContainerStyle={{ paddingBottom: T.space.xl }}>
        {weeks.length ? null : <Empty onBack={onBack} />}
        {weeks.map((w) => (
          <View key={w.weekStart}>
            <Text style={{ ...T.font.section, color: T.color.textPrimary, marginTop: T.space.xl }}>
              {w.weekStart === thisWeek ? words.thisWeek : words.weekOf(w.weekStart)}
            </Text>
            <Group>
              {w.days.map((k) => (
                <DayRow key={k} dayKey={k} day={state.days[k]} onPress={() => setDayOpen(k)} />
              ))}
              <Row last onPress={() => setWeekOpen(w.weekStart)}>
                <Text style={{ ...T.font.body, color: T.color.accentText, flex: 1 }}>
                  {words.flipToBackRow}
                </Text>
                <Text style={{ ...T.font.body, color: T.color.textSecondary }}>›</Text>
              </Row>
            </Group>
          </View>
        ))}
      </ScrollView>
      <DaySheet
        dayKey={dayOpen}
        day={dayOpen ? state.days[dayOpen] : null}
        onClose={() => setDayOpen(null)}
      />
      <WeekSheet weekStart={weekOpen} state={state} onClose={() => setWeekOpen(null)} />
    </View>
  );
}
