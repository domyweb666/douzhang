// 計時中的三個半頁（06 狀態表）：記一筆（念頭／有人找共用）、結束這顆、作廢原因。
// 只收字與按鈕，不碰狀態：呼叫端給 onJot／onDoneEarly／onVoid，狀態機在 core/machine.js。
import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { MS_PER_MINUTE, params } from '../design/params';
import { BigButton } from './BigButton';
import { Sheet } from './Sheet';
import { Segmented } from './Segmented';
import { LineInput } from './LineInput';

/** kind：'notes'（冒出念頭）或 'pings'（有人找）。寫一行按記下（或鍵盤 return），倒數不停。 */
export function NoteSheet({ kind, onClose, onJot }) {
  const T = useTokens();
  const [text, setText] = useState('');
  const submit = () => {
    if (text.trim()) onJot(kind, text);
    onClose();
  };
  return (
    <Sheet
      visible={!!kind}
      title={kind === 'pings' ? words.noteTitlePing : words.noteTitleThought}
      sub={words.noteSub}
      onClose={onClose}
    >
      <LineInput
        value={text}
        onChange={setText}
        maxLength={params.noteMaxChars}
        onSubmit={submit}
      />
      <BigButton
        label={words.jotDown}
        disabled={!text.trim()}
        onPress={submit}
        style={{ marginTop: T.space.m }}
      />
    </Sheet>
  );
}

/** 半頁裡的一列選項：主字＋小副標。 */
function Row({ title, sub, onPress }) {
  const T = useTokens();
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => ({
        minHeight: T.shape.tapPrimary,
        justifyContent: 'center',
        paddingVertical: T.space.s,
        borderBottomWidth: 1, // token-ok: 分隔線 1pt 是系統慣例，不是設計數字
        borderBottomColor: T.color.separator,
        opacity: pressed ? T.opacity.pressed : 1,
      })}
    >
      <Text style={{ ...T.font.body, color: T.color.textPrimary }}>{title}</Text>
      {sub ? (
        <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.xs }}>
          {sub}
        </Text>
      ) : null}
    </Pressable>
  );
}

/** 結束這顆？三選一：提早做完（還沒標過才有）、作廢（不到五分鐘叫停下來）、繼續做。 */
export function EndSheet({ visible, current, now, onClose, onDoneEarly, onVoid }) {
  const T = useTokens();
  const early = (now - current.startedAt) / MS_PER_MINUTE < params.stopNoRecordMinutes;
  return (
    <Sheet
      visible={visible}
      title={words.endTitle}
      sub={early ? words.endSubEarly : words.endSub}
      onClose={onClose}
    >
      {current.done ? null : (
        <Row
          title={words.doneEarly}
          sub={words.doneEarlySub}
          onPress={() => {
            onClose();
            onDoneEarly();
          }}
        />
      )}
      <Row title={early ? words.stopNow : words.voidThis} onPress={() => onVoid(early)} />
      <BigButton
        second
        label={words.keepGoing}
        onPress={onClose}
        style={{ marginTop: T.space.l }}
      />
    </Sheet>
  );
}

/** 作廢原因：四個分段＋一行選填 → 記一筆。 */
export function VoidSheet({ visible, onClose, onVoid }) {
  const T = useTokens();
  const [reason, setReason] = useState('');
  const [text, setText] = useState('');
  return (
    <Sheet visible={visible} title={words.voidThis} sub={words.voidSub} onClose={onClose}>
      <Segmented
        options={words.voidReasons.map((r) => ({ value: r, label: r }))}
        value={reason}
        onChange={setReason}
      />
      <LineInput
        value={text}
        onChange={setText}
        placeholder={words.voidTextPlaceholder}
        maxLength={params.voidTextMaxChars}
        style={{ marginTop: T.space.m }}
      />
      <View style={{ flexDirection: 'row', gap: T.space.m, marginTop: T.space.m }}>
        <BigButton second label={words.keepGoing} onPress={onClose} style={{ flex: 1 }} />
        <BigButton
          label={words.quickNote}
          onPress={() => onVoid({ reason, text })}
          style={{ flex: 1 }}
        />
      </View>
    </Sheet>
  );
}
