// 設定（全頁模態）。五區依序：任務類型、節奏、提醒、手感、備份（PRD S18）。
// C1 先有「任務類型」；節奏、提醒、手感是 G1，備份與清空是 G2–G4。狀態機在 core/settings.js。
import { ScrollView, Text, TextInput, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { TextButton } from '../ui/TextButton';
import { Segmented } from '../ui/Segmented';

const LENGTHS = params.typeLengths.map((len) => ({ value: len, label: words.typeLen(len) }));

function Cap({ children }) {
  const T = useTokens();
  return (
    <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.xl }}>
      {children}
    </Text>
  );
}

function Group({ children }) {
  const T = useTokens();
  return (
    <View
      style={{
        backgroundColor: T.color.card,
        borderRadius: T.shape.radiusCard,
        paddingHorizontal: T.space.l,
        marginTop: T.space.s,
      }}
    >
      {children}
    </View>
  );
}

/** 一種類型：名字（可改）、長度刻度、刪除（只剩一種時沒有）。 */
function TypeRow({ type, canDelete, onRename, onSetLen, onRemove }) {
  const T = useTokens();
  return (
    <View
      style={{
        paddingVertical: T.space.m,
        borderBottomWidth: 1, // token-ok: 分隔線 1pt 是系統慣例（lessons 已記）
        borderBottomColor: T.color.separator,
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <TextInput
          defaultValue={type.name}
          maxLength={params.typeNameMaxChars}
          onEndEditing={(e) => onRename(e.nativeEvent.text)}
          returnKeyType="done"
          style={{ ...T.font.body, color: T.color.textPrimary, flex: 1, minHeight: T.shape.tapMin }}
        />
        {canDelete ? (
          <TextButton label={words.deleteType} onPress={onRemove} style={{ alignSelf: 'center' }} />
        ) : null}
      </View>
      <Segmented
        options={LENGTHS}
        value={type.len}
        onChange={onSetLen}
        style={{ marginTop: T.space.s }}
      />
    </View>
  );
}

function TypesSection({ settings, actions }) {
  const T = useTokens();
  return (
    <View>
      <Cap>{words.taskType}</Cap>
      <Group>
        {settings.types.map((t) => (
          <TypeRow
            key={t.id}
            type={t}
            canDelete={settings.types.length > 1}
            onRename={(name) => actions.onRenameType(t.id, name)}
            onSetLen={(len) => actions.onSetTypeLen(t.id, len)}
            onRemove={() => actions.onRemoveType(t.id)}
          />
        ))}
        <TextButton
          flush
          label={words.addType}
          onPress={actions.onAddType}
          style={{ minHeight: T.shape.tapPrimary }}
        />
      </Group>
    </View>
  );
}

export function Settings({ state, actions, onBack }) {
  const T = useTokens();
  return (
    <View style={{ flex: 1 }}>
      <View
        style={{
          height: T.shape.tapMin,
          marginTop: T.space.s,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <TextButton flush label={words.back} onPress={onBack} />
        <Text style={{ ...T.font.body, color: T.color.textPrimary }}>{words.settings}</Text>
        <View style={{ minWidth: T.shape.tapPrimary }} />
      </View>
      <ScrollView
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ paddingBottom: T.space.xl }}
      >
        <TypesSection settings={state.settings} actions={actions} />
      </ScrollView>
    </View>
  );
}
