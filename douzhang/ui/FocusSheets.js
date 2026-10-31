// 計時中的三個半頁（06 狀態表）：記一筆（念頭／有人找共用）、結束這顆、作廢原因。
// 只收字與按鈕，不碰狀態：呼叫端給 onJot／onDoneEarly／onVoid，狀態機在 core/machine.js。
import { useState } from 'react';
import { View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { BigButton } from './BigButton';
import { Sheet } from './Sheet';
import { Segmented } from './Segmented';
import { LineInput } from './LineInput';
import { SheetRow } from './SheetRow';

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

/**
 * 結束這顆？三選一：提早做完（還沒標過才有）、作廢（不到五分鐘叫停下來）、繼續做。
 * early 由打開半頁那一刻決定（呼叫端固定住）：4:59 看到「停下來」，按下去就照停下來辦，不會變成記一筆作廢。
 */
export function EndSheet({ visible, current, early, onClose, onDoneEarly, onVoid }) {
  const T = useTokens();
  return (
    <Sheet
      visible={visible}
      title={words.endTitle}
      sub={early ? words.endSubEarly : words.endSub}
      onClose={onClose}
    >
      {current.done ? null : (
        <SheetRow
          title={words.doneEarly}
          sub={words.doneEarlySub}
          onPress={() => {
            onClose();
            onDoneEarly();
          }}
        />
      )}
      <SheetRow title={early ? words.stopNow : words.voidThis} onPress={() => onVoid(early)} />
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
