// 番茄架的分析（2026-11-17 AG5，比較頁 4A）：這一段專注多久、收了幾顆、每天一根依標籤分色的長條、各標籤占多少。
// 只陳述，不跟上一段比：沒有「比上週少幾 %」的箭頭，也沒有紅字（產品定稿：不製造罪惡感）。
// 數字都是 core/stats.js 算的，這裡只畫。日＝那天的番茄排一排；週＝七根；月＝一天一根細的。
import { Text, View } from 'react-native';
import { CharacterColors, useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { RANGE, rangeDays, stats } from '../core/stats';
import { Tomato } from './Tomato';

const INK = CharacterColors.tomato;
const bodyOf = (type) => INK.body[type.color] || INK.body.red;

function Card({ children }) {
  const T = useTokens();
  return (
    <View
      style={{
        backgroundColor: T.color.card,
        borderRadius: T.shape.radiusCard,
        padding: T.space.card,
      }}
    >
      {children}
    </View>
  );
}

/** 上面那張：左邊專注多久，右邊收了幾顆。 */
function Numbers({ minutes, beans }) {
  const T = useTokens();
  const cell = (label, value) => (
    <View style={{ flex: 1 }}>
      <Text style={{ ...T.font.caption, color: T.color.textSecondary }}>{label}</Text>
      <Text style={{ ...T.font.title3, color: T.color.textPrimary }}>{value}</Text>
    </View>
  );
  return (
    <View style={{ flexDirection: 'row' }}>
      {cell(words.statsFocus, words.duration(minutes))}
      {cell(words.statsKept, words.beansCount(beans))}
    </View>
  );
}

/** 一天一根：由下往上疊各標籤的分鐘數，最高那天頂到 statsBars。沒番茄的日子那一格空著。 */
function Bars({ days, thin }) {
  const T = useTokens();
  const max = Math.max(...days.map((d) => d.minutes));
  return (
    <View
      accessible={false}
      style={{
        flexDirection: 'row',
        alignItems: 'flex-end',
        height: T.shape.statsBars,
        gap: thin ? T.shape.timelineLaneGap : T.space.s,
      }}
    >
      {days.map((d) => (
        <View
          key={d.key}
          style={{
            flex: 1,
            flexDirection: 'column-reverse',
            overflow: 'hidden',
            borderRadius: thin ? T.shape.timelineLaneGap : T.space.xs,
          }}
        >
          {d.parts.map((p) => (
            <View
              key={p.type.id}
              style={{
                height: (p.minutes / max) * T.shape.statsBars,
                backgroundColor: bodyOf(p.type),
              }}
            />
          ))}
        </View>
      ))}
    </View>
  );
}

/** 長條圖下面那排字：週是一二三四五六日；月只寫頭、中、尾三個日期。 */
function BarLabels({ days, thin }) {
  const T = useTokens();
  const style = { ...T.font.tab, color: T.color.textSecondary };
  const date = (key) => Number(key.slice(-2));
  if (thin)
    return (
      <View
        style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: T.space.xs }}
      >
        <Text style={style}>{date(days[0].key)}</Text>
        <Text style={style}>{date(days[Math.floor(days.length / 2)].key)}</Text>
        <Text style={style}>{date(days[days.length - 1].key)}</Text>
      </View>
    );
  return (
    <View style={{ flexDirection: 'row', gap: T.space.s, marginTop: T.space.xs }}>
      {words.weekdayShort.map((name) => (
        <Text key={name} style={{ ...style, flex: 1, textAlign: 'center' }}>
          {name}
        </Text>
      ))}
    </View>
  );
}

/** 日：那天收下的番茄依時間排一排，顏色跟標籤。 */
function TomatoRow({ list }) {
  const T = useTokens();
  return (
    <View
      accessible={false}
      style={{ flexDirection: 'row', flexWrap: 'wrap', alignItems: 'flex-end', gap: T.space.xs }}
    >
      {list.map((b) => (
        <Tomato key={b.t} color={b.type.color} size={T.shape.celebrateDot} />
      ))}
    </View>
  );
}

/** 一個標籤一列：小番茄、名字、占比的橫槓、多久。 */
function TagRow({ tag }) {
  const T = useTokens();
  return (
    <View
      accessible
      accessibilityLabel={`${tag.type.name}，${words.duration(tag.minutes)}，${words.beansCount(tag.beans)}`}
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: T.space.s,
        minHeight: T.shape.buttonCompact,
      }}
    >
      <Tomato color={tag.type.color} size={T.shape.blockIcon * 1.5} />
      <Text
        numberOfLines={1}
        style={{ ...T.font.sub, color: T.color.textPrimary, width: T.shape.statsName }}
      >
        {tag.type.name}
      </Text>
      <View
        style={{
          flex: 1,
          height: T.shape.statsShare,
          borderRadius: T.shape.radiusPill,
          overflow: 'hidden',
          backgroundColor: T.color.fillButton,
        }}
      >
        <View
          style={{
            width: `${tag.share * 100}%`,
            height: T.shape.statsShare,
            borderRadius: T.shape.radiusPill,
            backgroundColor: bodyOf(tag.type),
          }}
        />
      </View>
      <Text style={{ ...T.font.caption, color: T.color.textSecondary }}>
        {words.duration(tag.minutes)}
      </Text>
    </View>
  );
}

/** range：RANGE.day｜week｜month；selected：這一段裡的任一天。這一段沒有番茄就只寫一句。 */
export function StatsView({ state, range, selected }) {
  const T = useTokens();
  const s = stats(state, rangeDays(range, selected));
  if (!s.beans)
    return (
      <Text
        style={{
          ...T.font.sub,
          color: T.color.textSecondary,
          textAlign: 'center',
          marginTop: T.space.xl,
        }}
      >
        {words.statsEmpty}
      </Text>
    );
  const thin = range === RANGE.month;
  return (
    <View style={{ gap: T.space.m, marginTop: T.space.m }}>
      <Card>
        <Numbers minutes={s.minutes} beans={s.beans} />
      </Card>
      <Card>
        {range === RANGE.day ? (
          <TomatoRow list={s.list} />
        ) : (
          <>
            <Bars days={s.days} thin={thin} />
            <BarLabels days={s.days} thin={thin} />
          </>
        )}
      </Card>
      <Card>
        {s.tags.map((tag) => (
          <TagRow key={tag.type.id} tag={tag} />
        ))}
      </Card>
    </View>
  );
}
