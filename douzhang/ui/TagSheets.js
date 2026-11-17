// 標籤的兩張半頁（2026-11-17 AG1，比較頁 5B）。「類型」與「在做哪件事・估幾顆」合成一個標籤：名稱、番茄色、預設長度。
// TagPickSheet：主畫面點最上面那顆膠囊開的，兩欄排開，點了就換；最後一格「＋ 新標籤」加一個並直接開它的編輯。
// TagEditSheet：改名、番茄色、滾輪選長度、刪除。設定頁也用同一張（原本寫在 screens/Settings.js，兩邊都要用才搬來這裡）。
// 只收選擇與字，狀態機在 core/settings.js。
import { useState } from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { pressFeedback } from '@domy/design';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { BigButton } from './BigButton';
import { TextButton } from './TextButton';
import { Sheet } from './Sheet';
import { Tomato } from './Tomato';

const LENGTHS = params.typeLengths.map((len) => ({ value: len, label: words.typeLen(len) }));

/** iOS 原生滾輪（滾動有系統的輕觸覺）。options：[{ value, label }]。 */
export function Wheel({ options, value, onChange }) {
  const T = useTokens();
  return (
    <Picker
      selectedValue={value}
      onValueChange={onChange}
      itemStyle={{ ...T.font.section, color: T.color.textPrimary }}
    >
      {options.map((o) => (
        <Picker.Item key={String(o.value)} label={o.label} value={o.value} />
      ))}
    </Picker>
  );
}

/** 五顆番茄並排選色，選中的那顆外面一圈茄紫（W1）。 */
function ColorPicker({ value, onChange }) {
  const T = useTokens();
  const size = T.shape.colorSwatch;
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: T.space.m }}>
      {params.tomatoColors.map((c) => {
        const on = c === value;
        return (
          <Pressable
            key={c}
            accessibilityRole="button"
            accessibilityLabel={words.tomatoColorName[c]}
            accessibilityState={{ selected: on }}
            onPress={() => onChange(c)}
            style={{
              width: T.shape.tapPrimary,
              height: T.shape.tapPrimary,
              alignItems: 'center',
              justifyContent: 'center',
              borderRadius: T.shape.radiusPill,
              borderWidth: T.shape.selectRing,
              borderColor: on ? T.color.accent : 'transparent', // token-ok: 沒選的不畫圈
              backgroundColor: on ? T.color.soft : 'transparent', // token-ok: 沒選的不畫底
            }}
          >
            <Tomato color={c} size={size} />
          </Pressable>
        );
      })}
    </View>
  );
}

/** 一個標籤的半頁：改名、番茄色、滾輪選長度、最下面刪除（只剩一個時沒有）。改了立刻存，「好」只是關。 */
export function TagEditSheet({
  type,
  canDelete,
  onClose,
  onRename,
  onSetLen,
  onSetColor,
  onRemove,
}) {
  const T = useTokens();
  if (!type) return null;
  return (
    <Sheet visible title={type.name} onClose={onClose}>
      <TextInput
        key={type.name} // 不受控：清空存成「未命名」時要重掛，框裡才會顯示新名字
        defaultValue={type.name}
        maxLength={params.typeNameMaxChars}
        onEndEditing={(e) => onRename(e.nativeEvent.text)}
        returnKeyType="done"
        accessibilityLabel={words.typeNameA11y}
        selectionColor={T.color.accent}
        style={{
          ...T.font.body,
          color: T.color.textPrimary,
          backgroundColor: T.color.card,
          borderWidth: T.shape.hairline,
          borderColor: T.color.fieldBorder,
          borderRadius: T.shape.radiusButton,
          paddingHorizontal: T.space.card,
          minHeight: T.shape.field,
        }}
      />
      <ColorPicker value={type.color} onChange={onSetColor} />
      <Wheel options={LENGTHS} value={type.len} onChange={onSetLen} />
      <BigButton label={words.ok} onPress={onClose} />
      {canDelete ? (
        <TextButton
          danger
          label={words.deleteThisType}
          onPress={() => {
            onClose();
            onRemove();
          }}
          style={{ alignSelf: 'center', marginTop: T.space.s }}
        />
      ) : null}
    </Sheet>
  );
}

/** 兩欄裡的一格：type 有給是一個標籤（小番茄、名字、長度），沒給是最後那格「＋ 新標籤」。 */
function TagCell({ type, selected, onPress }) {
  const T = useTokens();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={type ? `${type.name}，${words.typeLen(type.len)}` : undefined}
      accessibilityState={type ? { selected } : undefined}
      onPress={onPress}
      style={({ pressed }) => [
        {
          flex: 1,
          minHeight: T.shape.tapPrimary,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: type ? 'flex-start' : 'center',
          gap: T.space.s,
          paddingHorizontal: T.space.m,
          paddingVertical: T.space.s,
          borderRadius: T.shape.radiusButton,
          borderWidth: T.shape.selectRing,
          borderColor: selected ? T.color.accent : 'transparent', // token-ok: 沒選的不畫框
          backgroundColor: selected ? T.color.soft : T.color.fillButton,
        },
        pressFeedback(pressed, T.reduceMotion),
      ]}
    >
      {type ? (
        <>
          <Tomato color={type.color} size={T.shape.colorSwatch} />
          <View style={{ flex: 1 }}>
            <Text numberOfLines={1} style={{ ...T.font.bodyStrong, color: T.color.textPrimary }}>
              {type.name}
            </Text>
            <Text style={{ ...T.font.caption, color: T.color.textSecondary }}>
              {words.typeLen(type.len)}
            </Text>
          </View>
        </>
      ) : (
        <Text style={{ ...T.font.bodyStrong, color: T.color.accentText }}>{words.newTag}</Text>
      )}
    </Pressable>
  );
}

/** 把標籤兩個一排排好，最後補上「新標籤」那格；落單時右邊補一個空位，格子才不會撐滿整排。 */
function pairs(types) {
  const cells = [...types, null];
  const rows = [];
  for (let i = 0; i < cells.length; i += 2) rows.push(cells.slice(i, i + 2));
  return rows;
}

/**
 * 「這顆要做」：點一個標籤就換成它並關掉。點「＋ 新標籤」：加一個、換成它的編輯半頁，按好之後選中它。
 * 兩張半頁不疊著開（iOS 的 Modal 疊兩層會卡），所以編輯時這張先不畫。
 */
export function TagPickSheet({ visible, settings, actions, onClose }) {
  const T = useTokens();
  const [editingNew, setEditingNew] = useState(false);
  const types = settings.types;
  if (!visible) return null;
  if (editingNew) {
    const type = types[types.length - 1];
    return (
      <TagEditSheet
        type={type}
        canDelete={types.length > 1}
        onClose={() => {
          actions.onPickType(type.id);
          onClose();
        }}
        onRename={(name) => actions.onRenameType(type.id, name)}
        onSetLen={(len) => actions.onSetTypeLen(type.id, len)}
        onSetColor={(color) => actions.onSetTypeColor(type.id, color)}
        onRemove={() => actions.onRemoveType(type.id)}
      />
    );
  }
  const pick = (id) => {
    actions.onPickType(id);
    onClose();
  };
  const addNew = () => {
    actions.onAddType();
    setEditingNew(true);
  };
  return (
    <Sheet visible title={words.thisToDo} onClose={onClose}>
      <View style={{ gap: T.space.s }}>
        {pairs(types).map((row, i) => (
          <View key={i} style={{ flexDirection: 'row', gap: T.space.s }}>
            {row.map((type) => (
              <TagCell
                key={type ? type.id : 'new'}
                type={type}
                selected={!!type && type.id === settings.typeId}
                onPress={type ? () => pick(type.id) : addNew}
              />
            ))}
            {row.length === 1 ? <View style={{ flex: 1 }} /> : null}
          </View>
        ))}
      </View>
    </Sheet>
  );
}
