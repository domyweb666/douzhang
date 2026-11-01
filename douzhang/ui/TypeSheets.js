// 待機的「這顆」半頁（2026-11-02 U5）：原本類型半頁＋估幾顆半頁兩張疊，併成一張兩段：上面切類型，下面選今天在做哪件事。
// 只收選擇與字，狀態機在 core/settings.js。
import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { BigButton } from './BigButton';
import { TextButton } from './TextButton';
import { Sheet } from './Sheet';
import { Segmented } from './Segmented';
import { LineInput } from './LineInput';
import { SheetRow } from './SheetRow';

function Cap({ children }) {
  const T = useTokens();
  return (
    <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.l }}>
      {children}
    </Text>
  );
}

/** −／＋ 調顆數，1 到 estimateMax（原本 1–7 七格分段，小手機太擠）。 */
function Stepper({ value, onChange }) {
  const T = useTokens();
  const step = (d) => onChange(Math.min(params.estimateMax, Math.max(1, value + d)));
  const key = (label, d, a11y) => (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={a11y}
      onPress={() => step(d)}
      style={{
        minWidth: T.shape.tapMin,
        minHeight: T.shape.tapMin,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Text style={{ ...T.font.button, color: T.color.textPrimary }}>{label}</Text>
    </Pressable>
  );
  return (
    <View
      accessibilityLabel={words.estValueA11y(value)}
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        backgroundColor: T.color.fillButton,
        borderRadius: T.shape.radiusButton,
      }}
    >
      {key(words.minus, -1, words.estLess)}
      <Text style={{ ...T.font.button, color: T.color.textPrimary }}>{value}</Text>
      {key(words.plus, 1, words.estMore)}
    </View>
  );
}

/** 新的一件事：先是一列「＋ 新的一件事」，點了才展開輸入框（不然一打開半頁鍵盤就蓋住類型）。 */
function NewTask({ onEstimate, onClose }) {
  const T = useTokens();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [est, setEst] = useState(1);
  if (!open) return <TextButton flush label={words.newTask} onPress={() => setOpen(true)} />;
  return (
    <View style={{ marginTop: T.space.s }}>
      <LineInput
        value={name}
        onChange={setName}
        placeholder={words.estNamePlaceholder}
        maxLength={params.taskNameMaxChars}
      />
      <View
        style={{ flexDirection: 'row', alignItems: 'center', gap: T.space.m, marginTop: T.space.m }}
      >
        <Stepper value={est} onChange={setEst} />
        <BigButton
          label={words.estSave}
          disabled={!name.trim()}
          onPress={() => {
            onEstimate({ name, est });
            onClose();
          }}
          style={{ flex: 1 }}
        />
      </View>
    </View>
  );
}

/** 「這顆」：類型分段（點了即換、半頁不關）＋今天估過的事（點了選中並關）＋新的一件事＋不掛任何事。 */
export function ThisSheet({ visible, state, onClose, onPickType, onEstimate, onPickTask }) {
  const tasks = state.days[state.todayKey]?.tasks || [];
  const types = state.settings.types.map((t) => ({
    value: t.id,
    label: words.typeOption(t.name, t.len),
  }));
  const pick = (id) => {
    onPickTask(id);
    onClose();
  };
  return (
    <Sheet visible={visible} title={words.thisBean} onClose={onClose}>
      <Segmented options={types} value={state.settings.typeId} onChange={onPickType} />
      <Cap>{words.taskCap}</Cap>
      {tasks.map((t) => (
        <SheetRow
          key={t.id}
          title={t.name}
          value={words.estShort(t.est)}
          selected={t.id === state.taskId}
          onPress={() => pick(t.id)}
        />
      ))}
      <NewTask onEstimate={onEstimate} onClose={onClose} />
      {tasks.length ? (
        <SheetRow title={words.noTask} selected={!state.taskId} onPress={() => pick(null)} />
      ) : null}
    </Sheet>
  );
}
