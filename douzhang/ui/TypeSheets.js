// 待機的類型半頁（選類型＋「這件事估幾顆」入口）與估幾顆半頁（06 狀態表「類型與估算」）。
// 只收選擇與字，狀態機在 core/settings.js。
import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { BigButton } from './BigButton';
import { Sheet } from './Sheet';
import { Segmented } from './Segmented';
import { LineInput } from './LineInput';

/** 半頁裡的一列：左邊主字（可帶小副標）、右邊值、選中打勾。 */
export function SheetRow({ title, sub, value, selected, onPress, tint }) {
  const T = useTokens();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected: !!selected }}
      onPress={onPress}
      style={({ pressed }) => ({
        minHeight: T.shape.tapPrimary,
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: T.space.s,
        borderBottomWidth: 1, // token-ok: 分隔線 1pt 是系統慣例（lessons 已記）
        borderBottomColor: T.color.separator,
        opacity: pressed ? T.opacity.pressed : 1,
      })}
    >
      <View style={{ flex: 1 }}>
        <Text style={{ ...T.font.body, color: tint ? T.color.accentText : T.color.textPrimary }}>
          {title}
        </Text>
        {sub ? (
          <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.xs }}>
            {sub}
          </Text>
        ) : null}
      </View>
      {value ? <Text style={{ ...T.font.sub, color: T.color.textSecondary }}>{value}</Text> : null}
      {selected ? (
        <Text style={{ ...T.font.body, color: T.color.accentText, marginLeft: T.space.s }}>✓</Text>
      ) : null}
    </Pressable>
  );
}

/** 點列即選；最下面一列是估幾顆的入口。 */
export function TypeSheet({ visible, state, onClose, onPickType, onOpenEstimate }) {
  const task = (state.days[state.todayKey]?.tasks || []).find((t) => t.id === state.taskId);
  return (
    <Sheet visible={visible} title={words.typeTitle} sub={words.typeSub} onClose={onClose}>
      {state.settings.types.map((t) => (
        <SheetRow
          key={t.id}
          title={t.name}
          value={words.typeLen(t.len)}
          selected={t.id === state.settings.typeId}
          onPress={() => {
            onPickType(t.id);
            onClose();
          }}
        />
      ))}
      <SheetRow
        title={words.estimate}
        sub={words.estRowSub}
        value={task ? words.estValue(task.name, task.est) : words.estOptional}
        onPress={onOpenEstimate}
      />
    </Sheet>
  );
}

const COUNTS = Array.from({ length: params.estimateMax }, (_, i) => ({
  value: i + 1,
  label: String(i + 1),
}));

/** 名字＋顆數 → 記下來；下面列今天估過的可以換，或不掛任務。 */
export function EstimateSheet({ visible, state, onClose, onEstimate, onPickTask }) {
  const T = useTokens();
  const [name, setName] = useState('');
  const [est, setEst] = useState(0);
  const tasks = state.days[state.todayKey]?.tasks || [];
  const save = () => {
    onEstimate({ name, est });
    onClose();
  };
  return (
    <Sheet visible={visible} title={words.estTitle} sub={words.estSub} onClose={onClose}>
      <LineInput
        value={name}
        onChange={setName}
        placeholder={words.estNamePlaceholder}
        maxLength={params.taskNameMaxChars}
      />
      <Segmented options={COUNTS} value={est} onChange={setEst} style={{ marginTop: T.space.m }} />
      <BigButton
        label={words.estSave}
        disabled={!name.trim() || !est}
        onPress={save}
        style={{ marginTop: T.space.m }}
      />
      {tasks.length ? (
        <View style={{ marginTop: T.space.l }}>
          <Text style={{ ...T.font.caption, color: T.color.textSecondary }}>
            {words.estListCap}
          </Text>
          {tasks.map((t) => (
            <SheetRow
              key={t.id}
              title={t.name}
              value={words.estShort(t.est)}
              selected={t.id === state.taskId}
              onPress={() => {
                onPickTask(t.id);
                onClose();
              }}
            />
          ))}
          <SheetRow
            title={words.noTask}
            selected={!state.taskId}
            onPress={() => {
              onPickTask(null);
              onClose();
            }}
          />
        </View>
      ) : null}
    </Sheet>
  );
}
