// 番茄架的時間軸（2026-11-17 AG4，比較頁 3A「實心色塊」）：天、3 天、週共用這一個，差別只在一次排幾欄。
// 左邊時刻，右邊一天一欄；每顆番茄是它標籤顏色的實心方塊，畫在開始的時刻、高度照長度，作廢是虛線框。
// 規則沿用蒜日子：時間重疊的並排、同一群平分欄寬（排法在 core/calendar.js 的 dayBlocks）；
// 太短的畫到最小高度；今天那欄有一條標出現在時間的線。
// 字的多寡跟著欄寬：天＝標籤、長度、那句；3 天＝標籤；週太窄，不寫字。
import { Pressable, Text, View } from 'react-native';
import { CharacterColors, useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { VIEW, axisHours, dayBlocks, hourOfDay } from '../core/calendar';
import { typeOf } from '../core/machine';

const INK = CharacterColors.tomato;

/** 一條整點的線與左邊的時刻。 */
function HourLine({ hour, top }) {
  const T = useTokens();
  return (
    <View
      style={{
        position: 'absolute',
        top,
        left: 0,
        right: 0,
        flexDirection: 'row',
        alignItems: 'center',
      }}
    >
      <Text
        style={{ ...T.font.caption, color: T.color.textSecondary, width: T.shape.timelineGutter }}
      >
        {words.hourLabel(hour % 24)}
      </Text>
      <View style={{ flex: 1, height: T.shape.hairline, backgroundColor: T.color.separator }} />
    </View>
  );
}

/** 方塊裡寫什麼：天檢視且沒有並排才寫完整的（標籤・長度，夠高再加那句），其他只寫標籤名；作廢只在天檢視寫。 */
function BlockText({ item, type, full, tall, color }) {
  const T = useTokens();
  const line = { ...T.font.caption, color };
  if (item.kind === 'void')
    return full ? (
      <Text numberOfLines={1} style={{ ...line, color: T.color.textSecondary }}>
        {words.voidLine(item)}
      </Text>
    ) : null;
  if (!full)
    return (
      <Text numberOfLines={1} style={line}>
        {type.name}
      </Text>
    );
  return (
    <>
      <Text numberOfLines={1} style={{ ...line, fontWeight: T.font.chip.fontWeight }}>
        {words.blockTitle(type.name, item.len, item.flow)}
      </Text>
      {tall && item.clue ? (
        <Text numberOfLines={2} style={line}>
          {item.clue}
        </Text>
      ) : null}
    </>
  );
}

/** 讀屏念的那一句：番茄是「專注・25 分，那句」，作廢是「作廢，第幾分鐘…」。 */
const blockLabel = (item, type) =>
  item.kind === 'void'
    ? words.voidLine(item)
    : `${words.blockTitle(type.name, item.len, item.flow)}${item.clue ? `，${item.clue}` : ''}`;

/** 方塊的樣子。週檢視欄太窄：圓角小、沒有內距。夠高（tall）字靠上，不夠高字置中。作廢只畫虛線框。 */
function boxStyle(T, { week, tall, fill }) {
  return {
    flex: 1,
    overflow: 'hidden',
    borderRadius: week ? T.shape.timelineLaneGap * 2 : T.shape.radiusButton,
    paddingHorizontal: week ? 0 : T.space.s,
    justifyContent: tall ? 'flex-start' : 'center',
    paddingTop: tall ? T.space.xs : 0,
    backgroundColor: fill || 'transparent', // token-ok: 作廢只畫框
    borderWidth: fill ? 0 : T.shape.hairline,
    borderStyle: fill ? 'solid' : 'dashed',
    borderColor: T.color.textSecondary,
  };
}

/** 時間軸上的一顆番茄或一次作廢。left、width 用百分比：並排時平分那一欄。 */
function Block({ block, from, view, type, onPress }) {
  const T = useTokens();
  const { item, top, height, lane, lanes } = block;
  const week = view === VIEW.week;
  const px = height * T.shape.timelineHour - T.shape.timelineLaneGap;
  const tall = px >= T.shape.timelineNoteMin;
  const color = type ? type.color : 'red';
  const fill = item.kind === 'void' ? null : INK.body[color] || INK.body.red;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={blockLabel(item, type)}
      onPress={onPress}
      style={{
        position: 'absolute',
        top: (top - from) * T.shape.timelineHour,
        height: px,
        left: `${(lane / lanes) * 100}%`,
        width: `${100 / lanes}%`,
        paddingRight: T.shape.timelineLaneGap,
      }}
    >
      <View style={boxStyle(T, { week, tall, fill })}>
        {!week && px >= T.shape.timelineTextMin ? (
          <BlockText
            item={item}
            type={type}
            full={view === VIEW.day && lanes === 1}
            tall={tall}
            color={INK.onBody[color] || INK.onBody.red}
          />
        ) : null}
      </View>
    </Pressable>
  );
}

/** 今天那一欄標出現在時間的橫線。 */
function NowLine({ top }) {
  const T = useTokens();
  return (
    <View
      pointerEvents="none"
      style={{
        position: 'absolute',
        top,
        left: 0,
        right: 0,
        height: T.shape.nowLine,
        backgroundColor: T.color.accent,
      }}
    />
  );
}

/**
 * keys：要畫的那幾天（1、3 或 7 個日期鍵）；onOpen(key)：點了某一天的方塊。
 * 這幾天都沒有番茄也沒有作廢就什麼都不畫（不寫 0、不畫空的時間軸）。
 */
export function Timeline({ state, keys, view, now, onOpen }) {
  const T = useTokens();
  const hourH = T.shape.timelineHour;
  const minPx = view === VIEW.week ? T.shape.timelineBlockMinWeek : T.shape.timelineBlockMin;
  const columns = keys.map((k) => dayBlocks(state.days[k], k, minPx / hourH));
  const axis = axisHours(columns);
  if (!axis) return null;
  const hours = [];
  for (let h = axis.from; h <= axis.to; h++) hours.push(h);
  const nowHour = hourOfDay(now);
  const showNow = nowHour >= axis.from && nowHour <= axis.to;
  return (
    <View style={{ height: (axis.to - axis.from) * hourH, marginTop: T.space.m }}>
      {hours.map((h) => (
        <HourLine key={h} hour={h} top={(h - axis.from) * hourH} />
      ))}
      <View
        style={{
          position: 'absolute',
          top: 0,
          bottom: 0,
          left: T.shape.timelineGutter,
          right: 0,
          flexDirection: 'row',
        }}
      >
        {keys.map((k, i) => (
          <View key={k} style={{ flex: 1 }}>
            {columns[i].map((b) => (
              <Block
                key={`${b.item.kind}-${b.item.start}`}
                block={b}
                from={axis.from}
                view={view}
                type={b.item.typeId ? typeOf(state, b.item.typeId) : null}
                onPress={() => onOpen(k)}
              />
            ))}
            {showNow && k === state.todayKey ? (
              <NowLine top={(nowHour - axis.from) * hourH} />
            ) : null}
          </View>
        ))}
      </View>
    </View>
  );
}
