// 設定（左右滑三頁的右邊那頁）。五區依序：任務類型、節奏、提醒、手感、備份（PRD S18）。
// 任務類型 C1；節奏、提醒、手感 G1；備份與清空 G2–G4。狀態機在 core/settings.js，改完立刻生效（下一拍就讀新設定）。
// U10（2026-11-02）：類型與收工時間改成「一列一個值 ›」，點了從底部開半頁用 iOS 滾輪選（原本一排排膠囊要找黑的那顆）。
import { useState } from 'react';
import { Linking, Pressable, ScrollView, Switch, Text, TextInput, View } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { TextButton } from '../ui/TextButton';
import { PageTitle } from '../ui/PageTitle';
import { Segmented } from '../ui/Segmented';
import { Sheet } from '../ui/Sheet';
import { BigButton } from '../ui/BigButton';
import { hhmm } from '../ui/useNow';
import { dayKey } from '../core/store';

const LENGTHS = params.typeLengths.map((len) => ({ value: len, label: words.typeLen(len) }));
const CLOSE_TIMES = params.closeTimes.map((t) => ({ value: t, label: t }));
const REST_MODES = [
  { value: 'auto', label: words.restModeAuto },
  { value: 'self', label: words.restModeSelf },
];

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

/** 一列一個值：左邊名字、右邊現在的值＋›，點了開半頁。 */
function ValueRow({ title, value, onPress, last }) {
  const T = useTokens();
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => ({
        minHeight: T.shape.tapPrimary,
        flexDirection: 'row',
        alignItems: 'center',
        borderBottomWidth: last ? 0 : T.shape.hairline,
        borderBottomColor: T.color.separator,
        opacity: pressed ? T.opacity.pressed : 1,
      })}
    >
      <Text style={{ ...T.font.body, color: T.color.textPrimary, flex: 1 }}>{title}</Text>
      <Text style={{ ...T.font.body, color: T.color.textSecondary }}>
        {value} {words.chevron}
      </Text>
    </Pressable>
  );
}

/** iOS 原生滾輪（滾動有系統的輕觸覺）。options：[{ value, label }]。 */
function Wheel({ options, value, onChange }) {
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

/** 一種類型的半頁：改名、滾輪選長度、最下面刪除（只剩一種時沒有）。改了立刻存，「好」只是關。 */
function TypeEditSheet({ type, canDelete, onClose, onRename, onSetLen, onRemove }) {
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
        style={{
          ...T.font.body,
          color: T.color.textPrimary,
          backgroundColor: T.color.fillButton,
          borderRadius: T.shape.radiusButton,
          paddingHorizontal: T.space.m,
          minHeight: T.shape.tapMin,
        }}
      />
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
  const [open, setOpen] = useState(false);
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
        <ValueRow
          last
          title={words.closeTimeRow}
          value={settings.closeTime}
          onPress={() => setOpen(true)}
        />
      </Group>
      <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.s }}>
        {words.closeTimeSub}
      </Text>
      <Sheet visible={open} title={words.closeTimeRow} onClose={() => setOpen(false)}>
        <Wheel options={CLOSE_TIMES} value={settings.closeTime} onChange={actions.onSetCloseTime} />
        <BigButton label={words.ok} onPress={() => setOpen(false)} />
      </Sheet>
    </View>
  );
}

/**
 * 到點通知：允許「開著」；被拒「沒開」＋「打開」去系統設定（06 設定狀態表）；
 * 還沒問過什麼都不寫（第一次按開始才問，那時系統設定裡也還沒有這一列）。
 */
function NotifStatus({ status }) {
  const T = useTokens();
  if (status === 'undetermined') return null;
  const denied = status === 'denied';
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

function ReminderSection({ settings, actions, notif }) {
  return (
    <View>
      <Cap>{words.reminders}</Cap>
      <Group>
        <SettingRow title={words.notifRow} right={<NotifStatus status={notif} />} />
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

/** 開發期才有的測試模式開關（正式 build 整區不畫）。 */
function DevSection({ settings, actions }) {
  if (!__DEV__) return null;
  return (
    <View>
      <Cap>{words.devSection}</Cap>
      <Group>
        <SettingRow
          last
          title={words.testModeRow}
          sub={words.testModeSub}
          right={
            <Toggle
              value={settings.demo}
              onChange={actions.onSetTestMode}
              label={words.testModeRow}
            />
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
  backupsLeft: words.backupsLeft,
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
  const [openId, setOpenId] = useState(null);
  const open = settings.types.find((t) => t.id === openId);
  return (
    <View>
      <Cap>{words.taskType}</Cap>
      <Group>
        {settings.types.map((t) => (
          <ValueRow
            key={t.id}
            title={t.name}
            value={words.typeLen(t.len)}
            onPress={() => setOpenId(t.id)}
          />
        ))}
        <TextButton
          flush
          label={words.addType}
          onPress={actions.onAddType}
          style={{ minHeight: T.shape.tapPrimary }}
        />
      </Group>
      <TypeEditSheet
        type={open}
        canDelete={settings.types.length > 1}
        onClose={() => setOpenId(null)}
        onRename={(name) => actions.onRenameType(openId, name)}
        onSetLen={(len) => actions.onSetTypeLen(openId, len)}
        onRemove={() => actions.onRemoveType(openId)}
      />
    </View>
  );
}

export function Settings({ state, actions, notif, backup, onWipe }) {
  const T = useTokens();
  return (
    <View style={{ flex: 1 }}>
      <PageTitle>{words.settings}</PageTitle>
      <ScrollView
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ paddingBottom: T.space.xl }}
      >
        <TypesSection settings={state.settings} actions={actions} />
        <RhythmSection settings={state.settings} actions={actions} />
        <ReminderSection settings={state.settings} actions={actions} notif={notif} />
        <FeelSection settings={state.settings} actions={actions} />
        <DevSection settings={state.settings} actions={actions} />
        <BackupSection backup={backup} />
        <Group>
          <TextButton danger flush label={words.wipeAll} onPress={onWipe} />
        </Group>
      </ScrollView>
    </View>
  );
}
