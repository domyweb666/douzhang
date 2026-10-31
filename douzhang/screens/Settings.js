// 設定（全頁模態）。五區依序：任務類型、節奏、提醒、手感、備份（PRD S18）。
// 任務類型 C1；節奏、提醒、手感 G1；備份與清空 G2–G4。狀態機在 core/settings.js，改完立刻生效（下一拍就讀新設定）。
import { Linking, ScrollView, Switch, Text, TextInput, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { TextButton } from '../ui/TextButton';
import { Segmented } from '../ui/Segmented';
import { hhmm } from '../ui/useNow';
import { dayKey } from '../core/store';

const LENGTHS = params.typeLengths.map((len) => ({ value: len, label: words.typeLen(len) }));
const REST_MODES = [
  { value: 'auto', label: words.restModeAuto },
  { value: 'self', label: words.restModeSelf },
];
const CLOSE_TIMES = params.closeTimes.map((t) => ({ value: t, label: t }));

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
        borderBottomWidth: T.shape.hairline,
        borderBottomColor: T.color.separator,
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <TextInput
          key={type.name} // 不受控：清空存成「未命名」時要重掛，框裡才會顯示新名字
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

/** 設定裡的一列：左邊主字（可帶副標），右邊放開關或狀態；下面可以再放一排分段。 */
function SettingRow({ title, sub, right, children, last }) {
  const T = useTokens();
  return (
    <View
      style={{
        paddingVertical: T.space.m,
        borderBottomWidth: last ? 0 : T.shape.hairline,
        borderBottomColor: T.color.separator,
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', minHeight: T.shape.tapMin }}>
        <View style={{ flex: 1 }}>
          <Text style={{ ...T.font.body, color: T.color.textPrimary }}>{title}</Text>
          {sub ? (
            <Text
              style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.xs }}
            >
              {sub}
            </Text>
          ) : null}
        </View>
        {right}
      </View>
      {children}
    </View>
  );
}

function Toggle({ value, onChange, label }) {
  const T = useTokens();
  return (
    <Switch
      accessibilityLabel={label}
      value={!!value}
      onValueChange={onChange}
      trackColor={{ false: T.color.fillButton, true: T.color.accent }}
      ios_backgroundColor={T.color.fillButton}
    />
  );
}

function RhythmSection({ settings, actions }) {
  const T = useTokens();
  return (
    <View>
      <Cap>{words.rhythm}</Cap>
      <Group>
        <SettingRow title={words.restRow}>
          <Segmented
            options={REST_MODES}
            value={settings.restMode}
            onChange={actions.onSetRestMode}
            style={{ marginTop: T.space.s }}
          />
        </SettingRow>
        <SettingRow last title={words.closeTimeRow} sub={words.closeTimeSub}>
          <Segmented
            options={CLOSE_TIMES}
            value={settings.closeTime}
            onChange={actions.onSetCloseTime}
            style={{ marginTop: T.space.s }}
          />
        </SettingRow>
      </Group>
    </View>
  );
}

/** 到點通知：允許就「開著」；沒開就「沒開」＋「打開」去系統設定（06 設定狀態表）。 */
function NotifStatus({ denied }) {
  const T = useTokens();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
      <Text style={{ ...T.font.sub, color: T.color.textSecondary }}>
        {denied ? words.notifOff : words.notifOn}
      </Text>
      {denied ? (
        <TextButton label={words.notifOpen} onPress={() => Linking.openSettings()} />
      ) : null}
    </View>
  );
}

function ReminderSection({ settings, actions, notifDenied }) {
  return (
    <View>
      <Cap>{words.reminders}</Cap>
      <Group>
        <SettingRow title={words.notifRow} right={<NotifStatus denied={notifDenied} />} />
        <SettingRow
          last
          title={words.soundRow}
          right={
            <Toggle value={settings.sound} onChange={actions.onSetSound} label={words.soundRow} />
          }
        />
      </Group>
    </View>
  );
}

function FeelSection({ settings, actions }) {
  return (
    <View>
      <Cap>{words.feel}</Cap>
      <Group>
        <SettingRow
          last
          title={words.tiltRow}
          right={
            <Toggle value={settings.tilt} onChange={actions.onSetTilt} label={words.tiltRow} />
          }
        />
      </Group>
    </View>
  );
}

const PROBLEM_WORDS = {
  unreadable: words.importUnreadable,
  tooBig: words.importTooBig,
  backupFailed: words.autoBackupFailed,
  exportFailed: words.exportFailed,
};

/** 備份：匯出、匯入兩列，下面一行出錯原因（有才出）、一句說明、上次自動備份時間（S3）。 */
function BackupSection({ backup }) {
  const T = useTokens();
  const note = { ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.s };
  return (
    <View>
      <Cap>{words.backup}</Cap>
      <Group>
        <TextButton
          flush
          label={words.exportBackup}
          onPress={backup.onExport}
          style={{
            minHeight: T.shape.tapPrimary,
            borderBottomWidth: T.shape.hairline,
            borderBottomColor: T.color.separator,
          }}
        />
        <TextButton
          flush
          label={words.importBackup}
          onPress={backup.onImport}
          style={{ minHeight: T.shape.tapPrimary }}
        />
      </Group>
      {backup.problem ? (
        <Text style={{ ...T.font.sub, color: T.color.danger, marginTop: T.space.s }}>
          {PROBLEM_WORDS[backup.problem]}
        </Text>
      ) : null}
      <Text style={note}>{words.backupNote}</Text>
      {backup.lastBackup ? (
        <Text style={note}>
          {words.lastAutoBackup(
            `${words.monthDay(dayKey(backup.lastBackup))} ${hhmm(backup.lastBackup)}`,
          )}
        </Text>
      ) : null}
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

export function Settings({ state, actions, notifDenied, backup, onWipe, onBack }) {
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
        <RhythmSection settings={state.settings} actions={actions} />
        <ReminderSection settings={state.settings} actions={actions} notifDenied={notifDenied} />
        <FeelSection settings={state.settings} actions={actions} />
        <BackupSection backup={backup} />
        <Group>
          <TextButton danger flush label={words.wipeAll} onPress={onWipe} />
        </Group>
      </ScrollView>
    </View>
  );
}
