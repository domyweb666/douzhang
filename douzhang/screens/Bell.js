// 鈴響・寫一句（方向 A：底部收下，貼鍵盤上緣）。
// A5：空白守門（「收下這顆」停用、多一顆「這顆不留話」）、右上「再做 15 分・30 分」一顆一次、念頭與有人找列在框下、很久才回來的副標。
// R1（2026-11-01 重新設計）：框上放「這顆在做」那句，接的兩半同框。
// U7（2026-11-02）：「再做 N 分」從右上角搬到收下鈕正上方，兩顆直接按，不再開半頁。
import { Text, TextInput, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params, MS_PER_MINUTE } from '../design/params';
import { restMinutes } from '../core/store';
import { BigButton } from '../ui/BigButton';
import { TextButton } from '../ui/TextButton';

function Header({ current, now }) {
  const T = useTokens();
  const agoMs = now - current.endAt;
  const lateSub = agoMs >= restMinutes(current.len) * MS_PER_MINUTE;
  return (
    <View style={{ marginTop: T.space.l }}>
      <Text style={{ ...T.font.title, color: T.color.textPrimary }}>{words.rang}</Text>
      {lateSub ? (
        <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.xs }}>
          {words.rangAgo(Math.floor(agoMs / MS_PER_MINUTE))}
        </Text>
      ) : null}
    </View>
  );
}

/** 這顆開始時那句。用框線不用底色，不跟下面的輸入框搶；上一顆不留話就不畫。 */
function PrevLine({ text }) {
  const T = useTokens();
  if (!text) return null;
  return (
    <View
      style={{
        borderWidth: T.shape.hairline,
        borderColor: T.color.separator,
        borderRadius: T.shape.radiusButton,
        padding: T.space.m,
        marginTop: T.space.m,
      }}
    >
      <Text style={{ ...T.font.caption, color: T.color.textSecondary }}>{words.bellPrevCap}</Text>
      <Text style={{ ...T.font.callout, color: T.color.textPrimary, marginTop: T.space.xs }}>
        {text}
      </Text>
    </View>
  );
}

/** 計時中記的念頭與有人找（B1 寫進來）。清單空就什麼都不畫，不寫「沒有紀錄」。 */
function Jotted({ current }) {
  const T = useTokens();
  const rows = [
    ...(current.notes || []).map((v) => ({ k: words.noteThought, v })),
    ...(current.pings || []).map((v) => ({ k: words.notePing, v })),
  ];
  if (!rows.length) return null;
  const sub = { ...T.font.sub, color: T.color.textSecondary };
  return (
    <View style={{ marginTop: T.space.m }}>
      {rows.map((r, i) => (
        <View key={i} style={{ flexDirection: 'row', marginTop: T.space.xs }}>
          <Text style={{ ...sub, marginRight: T.space.m }}>{r.k}</Text>
          <Text style={{ ...sub, flex: 1 }}>{r.v}</Text>
        </View>
      ))}
    </View>
  );
}

/** 「再做 15 分」「再做 30 分」並排；一顆只准延一次，延過就不畫（A5）。 */
function FlowRow({ current, onFlow }) {
  const T = useTokens();
  if (current.flowed) return null;
  return (
    <View style={{ flexDirection: 'row', gap: T.space.m, marginBottom: T.space.m }}>
      {params.flowMinutes.map((minutes) => (
        <BigButton
          key={minutes}
          second
          label={words.flowMore(minutes)}
          onPress={() => onFlow(minutes)}
          style={{ flex: 1 }}
        />
      ))}
    </View>
  );
}

export function Bell({ current, now, draft, onDraft, onKeep, onFlow }) {
  const T = useTokens();
  const empty = !draft.trim();
  return (
    <View style={{ flex: 1 }}>
      <Header current={current} now={now} />
      <PrevLine text={current.clue} />
      <Text style={{ ...T.font.bodyStrong, color: T.color.textPrimary, marginTop: T.space.l }}>
        {words.bellAsk}
      </Text>
      <TextInput
        autoFocus
        multiline
        maxLength={params.firstLineMaxChars}
        value={draft}
        onChangeText={onDraft}
        placeholder={words.bellPlaceholder}
        placeholderTextColor={T.color.textSecondary}
        style={{
          ...T.font.sentence,
          color: T.color.textPrimary,
          backgroundColor: T.color.card,
          borderRadius: T.shape.radiusButton,
          padding: T.space.m,
          marginTop: T.space.s,
          minHeight: T.shape.tapPrimary * 2,
        }}
      />
      <Jotted current={current} />
      <View style={{ flex: 1 }} />
      <FlowRow current={current} onFlow={onFlow} />
      <BigButton label={words.keepThis} disabled={empty} onPress={() => onKeep(draft)} />
      {empty ? (
        <TextButton
          secondary
          label={words.keepWithoutNote}
          onPress={() => onKeep('')}
          style={{ alignSelf: 'center', marginTop: T.space.xs }}
        />
      ) : null}
    </View>
  );
}
