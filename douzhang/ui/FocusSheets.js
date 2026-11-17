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

const NOTE_KINDS = [
  { value: 'notes', label: words.noteThought },
  { value: 'pings', label: words.notePing },
];

/** 記一筆（U6 合成一顆）：上面分段選念頭或有人找（預設念頭），寫一行按記下（或鍵盤 return），倒數不停。 */
export function NoteSheet({ visible, onClose, onJot }) {
  const T = useTokens();
  const [kind, setKind] = useState('notes');
  const [text, setText] = useState('');
  const submit = () => {
    if (text.trim()) onJot(kind, text);
    onClose();
  };
  return (
    <Sheet visible={visible} title={words.quickNote} sub={words.noteSub} onClose={onClose}>
      <Segmented options={NOTE_KINDS} value={kind} onChange={setKind} />
      <LineInput
        value={text}
        onChange={setText}
        placeholder={kind === 'pings' ? words.noteTitlePing : words.noteTitleThought}
        maxLength={params.noteMaxChars}
        onSubmit={submit}
        style={{ marginTop: T.space.m }}
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

/**
 * 計時中右上「⋯」開的半頁（2026-11-18 AH2，比較頁 C）：原本畫面上那排鈕與底部「結束這顆」都收進這裡。
 * 點一列就關掉自己，交給呼叫端開下一張（onPick：'note'｜'sound'｜'zen'｜'end'）。
 * noteCount：這顆記過幾筆；soundValue：現在選的背景音（關、雨、柴火）。
 */
export function MoreSheet({ visible, noteCount, soundValue, onClose, onPick }) {
  return (
    <Sheet visible={visible} title={words.moreTitle} onClose={onClose}>
      <SheetRow
        title={words.quickNote}
        value={noteCount ? String(noteCount) : undefined}
        onPress={() => onPick('note')}
      />
      <SheetRow title={words.ambienceTitle} value={soundValue} onPress={() => onPick('sound')} />
      <SheetRow title={words.zenEnter} onPress={() => onPick('zen')} />
      <SheetRow title={words.endThis} onPress={() => onPick('end')} />
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
