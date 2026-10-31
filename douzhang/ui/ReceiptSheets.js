// 一天的收據、一週的收據（06 狀態表）。數字由 core/receipt.js 算，這裡只排版、只用 words。
import { ScrollView, Text, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { VERDICT, dayReceipt, podItems, taskRows, weekReceipt } from '../core/receipt';
import { BigButton } from './BigButton';
import { Sheet } from './Sheet';
import { Pod } from './Pod';
import { hhmm } from './useNow';

function Line({ left, right, muted }) {
  const T = useTokens();
  return (
    <View style={{ flexDirection: 'row', paddingVertical: T.space.s }}>
      {left ? (
        <Text style={{ ...T.font.sub, color: T.color.textSecondary, marginRight: T.space.m }}>
          {left}
        </Text>
      ) : null}
      <Text
        style={{
          ...T.font.body,
          color: muted ? T.color.textSecondary : T.color.textPrimary,
          flex: 1,
        }}
      >
        {right}
      </Text>
    </View>
  );
}

function KV({ k, v }) {
  const T = useTokens();
  return (
    <View
      style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: T.space.s }}
    >
      <Text style={{ ...T.font.body, color: T.color.textPrimary, flex: 1 }}>{k}</Text>
      <Text style={{ ...T.font.sub, color: T.color.textSecondary }}>{v}</Text>
    </View>
  );
}

function Cap({ children }) {
  const T = useTokens();
  return (
    <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.l }}>
      {children}
    </Text>
  );
}

function Foot({ children }) {
  const T = useTokens();
  return (
    <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.m }}>
      {children}
    </Text>
  );
}

function beanLine(row) {
  const marks = [];
  if (row.double) marks.push(words.doublePea);
  if (row.flow) marks.push(words.flowMark(row.flow));
  if (row.notes || row.pings) marks.push(words.jotMark(row.notes, row.pings));
  const text = row.clue || words.noNoteMark;
  return marks.length ? `${text}　${marks.join('　')}` : text;
}

/** 一天的收據：時間、那句、作廢行、沒留話標記，由早到晚；有估才有估算對帳。 */
export function DaySheet({ dayKey, day, onClose }) {
  const T = useTokens();
  const rows = day ? dayReceipt(day) : [];
  const tasks = day ? taskRows(day) : [];
  return (
    <Sheet visible={!!dayKey} title={dayKey ? words.dayReceiptTitle(dayKey) : ''} onClose={onClose}>
      <ScrollView style={{ maxHeight: T.shape.tapPrimary * 7 }}>
        {day ? <Pod items={podItems(day)} /> : null}
        <View style={{ marginTop: T.space.m }}>
          {rows.length ? (
            rows.map((r, i) =>
              r.kind === 'bean' ? (
                <Line key={i} left={hhmm(r.start)} right={beanLine(r)} muted={!r.clue} />
              ) : (
                <Line key={i} left={hhmm(r.t)} right={words.voidLine(r)} muted />
              ),
            )
          ) : (
            <Line right={words.leafDay} muted />
          )}
        </View>
        {tasks.length ? (
          <View>
            <Cap>{words.estimateVsActual}</Cap>
            {tasks.map(({ task, actual }) => (
              <KV
                key={task.id}
                k={task.novel ? `${task.name}　${words.novelMark}` : task.name}
                v={words.estActual(task.est, actual)}
              />
            ))}
          </View>
        ) : null}
        {day?.restOver ? <Foot>{words.restOverLine(day.restOver)}</Foot> : null}
      </ScrollView>
      <BigButton second label={words.ok} onPress={onClose} style={{ marginTop: T.space.l }} />
    </Sheet>
  );
}

const VERDICT_WORDS = {
  [VERDICT.fewData]: words.verdictFewData,
  [VERDICT.under]: words.verdictUnder,
  [VERDICT.over]: words.verdictOver,
  [VERDICT.even]: words.verdictEven,
};

/** 一週的收據：各類型幾格、估少估多剛好、作廢分佈（達 3 次那一行）、延長提示。 */
export function WeekSheet({ weekStart, state, onClose }) {
  const T = useTokens();
  const w = weekStart ? weekReceipt(state, weekStart) : null;
  return (
    <Sheet
      visible={!!weekStart}
      title={words.weekReceipt}
      sub={weekStart ? words.weekSub(weekStart) : ''}
      onClose={onClose}
    >
      {w ? (
        <ScrollView style={{ maxHeight: T.shape.tapPrimary * 7 }}>
          {w.byType.length ? (
            w.byType.map((t) => <KV key={t.name} k={t.name} v={words.unitsLabel(t.units)} />)
          ) : (
            <Line right={words.weekEmpty} muted />
          )}
          <Cap>{words.estimateVsActual}</Cap>
          <KV k={words.underLabel} v={words.timesLabel(w.under)} />
          <KV k={words.overLabel} v={words.timesLabel(w.over)} />
          <KV k={words.evenLabel} v={words.timesLabel(w.even)} />
          <Foot>{VERDICT_WORDS[w.verdict]}</Foot>
          {w.totalVoids ? (
            <View>
              <Cap>{words.voidDist}</Cap>
              {w.voids.map((v) => (
                <KV key={v.label} k={v.label} v={String(v.count)} />
              ))}
              {w.voidHint ? <Foot>{words.voidHint}</Foot> : null}
            </View>
          ) : null}
          {w.flowHint ? <Foot>{words.flowHint}</Foot> : null}
        </ScrollView>
      ) : null}
      <BigButton second label={words.ok} onPress={onClose} style={{ marginTop: T.space.l }} />
    </Sheet>
  );
}
