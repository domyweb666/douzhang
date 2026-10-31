// 待機的類型半頁（選類型＋「這件事估幾顆」入口）與估幾顆半頁（06 狀態表「類型與估算」）。
// 只收選擇與字，狀態機在 core/settings.js。
import { useState } from 'react';
import { Text, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { BigButton } from './BigButton';
import { Sheet } from './Sheet';
import { Segmented } from './Segmented';
import { LineInput } from './LineInput';
import { SheetRow } from './SheetRow';

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
