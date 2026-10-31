// 鈴響・寫一句（方向 A：底部收下，貼鍵盤上緣）。
// A5：空白守門（「收下這顆」停用、多一顆「這顆不留話」）、右上「再做 15 分・30 分」一顆一次、念頭與有人找列在框下、很久才回來的副標。
import { useState } from 'react';
import { Text, TextInput, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params, MS_PER_MINUTE } from '../design/params';
import { restMinutes } from '../core/store';
import { BigButton } from '../ui/BigButton';
import { TextButton } from '../ui/TextButton';
import { Sheet } from '../ui/Sheet';

function Header({ current, now, onOpenFlow }) {
  const T = useTokens();
  const agoMs = now - current.endAt;
  const lateSub = agoMs >= restMinutes(current.len) * MS_PER_MINUTE;
  return (
    <View style={{ marginTop: T.space.l }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <Text style={{ ...T.font.title, color: T.color.textPrimary }}>{words.rang}</Text>
        {current.flowed ? null : <TextButton label={words.flowMenu} onPress={onOpenFlow} />}
      </View>
      <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.xs }}>
        {lateSub ? words.rangAgo(Math.floor(agoMs / MS_PER_MINUTE)) : words.bellSub}
      </Text>
    </View>
  );
}

/** 計時中記的念頭與有人找（B1 寫進來）。清單空就什麼都不畫，不寫「沒有紀錄」。 */
function Jotted({ current }) {
  const T = useTokens();
  const rows = [
    ...current.notes.map((v) => ({ k: words.noteThought, v })),
    ...current.pings.map((v) => ({ k: words.notePing, v })),
  ];
  if (!rows.length) return null;
  return (
    <View style={{ marginTop: T.space.m }}>
      {rows.map((r, i) => (
        <Text
          key={i}
          style={{ ...T.font.sub, color: T.color.textSecondary, marginTop: T.space.xs }}
        >
          {r.k}　{r.v}
        </Text>
      ))}
    </View>
  );
}

function FlowSheet({ visible, onClose, onFlow }) {
  const T = useTokens();
  return (
    <Sheet visible={visible} title={words.flowTitle} sub={words.flowSub} onClose={onClose}>
      <BigButton second label={words.flow15} onPress={() => onFlow(15)} />
      <BigButton
        second
        label={words.flow30}
        onPress={() => onFlow(30)}
        style={{ marginTop: T.space.m }}
      />
    </Sheet>
  );
}

export function Bell({ current, now, draft, onDraft, onKeep, onFlow }) {
  const T = useTokens();
  const [flowOpen, setFlowOpen] = useState(false);
  const empty = !draft.trim();
  return (
    <View style={{ flex: 1 }}>
      <Header current={current} now={now} onOpenFlow={() => setFlowOpen(true)} />
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
          marginTop: T.space.m,
          minHeight: T.shape.tapPrimary * 2,
        }}
      />
      <Jotted current={current} />
      <View style={{ flex: 1 }} />
      {empty ? (
        <TextButton
          secondary
          label={words.keepWithoutNote}
          onPress={() => onKeep('')}
          style={{ alignSelf: 'center', marginBottom: T.space.s }}
        />
      ) : null}
      <BigButton label={words.keepThis} disabled={empty} onPress={() => onKeep(draft)} />
      <FlowSheet
        visible={flowOpen}
        onClose={() => setFlowOpen(false)}
        onFlow={(minutes) => {
          setFlowOpen(false);
          onFlow(minutes);
        }}
      />
    </View>
  );
}
