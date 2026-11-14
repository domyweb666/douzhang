// 設定（左右滑三頁的右邊那頁）。五區依序：任務類型、節奏、提醒、手感、備份（PRD S18）。
// 任務類型 C1；節奏、提醒、手感 G1；備份與清空 G2–G4。狀態機在 core/settings.js，改完立刻生效（下一拍就讀新設定）。
// U10（2026-11-02）：類型與收工時間改成「一列一個值 ›」，點了從底部開半頁用 iOS 滾輪選（原本一排排膠囊要找黑的那顆）。
// 2026-11-14 照 Domy Design System 重新設計：每區是一個 DomySection（標題＋白卡，列之間自動分隔線），
// 列用 DomySettingsRow（值＋箭頭、產品色膠囊、開關三種尾巴），說明字放在區塊的 footer。
import { useState } from 'react';
import { Image, Linking, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { DomySection, DomySettingsRow, useTabBarClearance } from '@domy/design';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { TextButton } from '../ui/TextButton';
import { PageTitle } from '../ui/PageTitle';
import { Segmented } from '../ui/Segmented';
import { Sheet } from '../ui/Sheet';
import { BigButton } from '../ui/BigButton';
import { hhmm } from '../ui/useNow';
import { TOMATO_ASPECT, tomatoOf } from '../ui/tomatoImages';
import { dayKey } from '../core/store';

const LENGTHS = params.typeLengths.map((len) => ({ value: len, label: words.typeLen(len) }));
const CLOSE_TIMES = params.closeTimes.map((t) => ({ value: t, label: t }));
const REST_MODES = [
  { value: 'auto', label: words.restModeAuto },
  { value: 'self', label: words.restModeSelf },
];

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
            <Image source={tomatoOf(c)} style={{ width: size, height: size * TOMATO_ASPECT }} />
          </Pressable>
        );
      })}
    </View>
  );
}

/** 一種類型的半頁：改名、番茄色、滾輪選長度、最下面刪除（只剩一種時沒有）。改了立刻存，「好」只是關。 */
function TypeEditSheet({ type, canDelete, onClose, onRename, onSetLen, onSetColor, onRemove }) {
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

/** 一種類型：前面一顆它的番茄色、名字，右邊長度＋箭頭（DomySettingsRow 的樣子，多一顆小番茄）。 */
function TypeRow({ type, onPress }) {
  const T = useTokens();
  const icon = T.shape.colorSwatch / 1.5;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${type.name}，${words.typeLen(type.len)}`}
      onPress={onPress}
      style={({ pressed }) => ({
        minHeight: T.shape.row,
        flexDirection: 'row',
        alignItems: 'center',
        gap: T.space.m,
        paddingVertical: T.space.s,
        marginHorizontal: -T.space.card,
        paddingHorizontal: T.space.card,
        backgroundColor: pressed ? T.color.fillButton : T.color.card,
      })}
    >
      <Image
        source={tomatoOf(type.color)}
        resizeMode="contain"
        style={{ width: icon, height: icon }}
      />
      <Text style={{ ...T.font.body, color: T.color.textPrimary, flex: 1 }}>{type.name}</Text>
      <Text style={{ ...T.font.body, color: T.color.textSecondary }}>
        {words.typeLen(type.len)}
      </Text>
      <Text style={{ ...T.font.body, color: T.color.textTertiary }}>{words.chevron}</Text>
    </Pressable>
  );
}

function TypesSection({ settings, actions }) {
  const T = useTokens();
  const [openId, setOpenId] = useState(null);
  const open = settings.types.find((t) => t.id === openId);
  return (
    <View>
      <DomySection title={words.taskType}>
        {settings.types.map((t) => (
          <TypeRow key={t.id} type={t} onPress={() => setOpenId(t.id)} />
        ))}
        <TextButton
          flush
          label={words.addType}
          onPress={actions.onAddType}
          style={{ minHeight: T.shape.row }}
        />
      </DomySection>
      <TypeEditSheet
        type={open}
        canDelete={settings.types.length > 1}
        onClose={() => setOpenId(null)}
        onRename={(name) => actions.onRenameType(openId, name)}
        onSetLen={(len) => actions.onSetTypeLen(openId, len)}
        onSetColor={(color) => actions.onSetTypeColor(openId, color)}
        onRemove={() => actions.onRemoveType(openId)}
      />
    </View>
  );
}

/** 休息怎麼算：列的名字在上、分段在下（DomySettingsRow 沒有放分段的尾巴，照它的高度與間距自己排）。 */
function RestModeRow({ value, onChange }) {
  const T = useTokens();
  return (
    <View style={{ paddingVertical: T.space.m, gap: T.space.s }}>
      <Text style={{ ...T.font.body, color: T.color.textPrimary }}>{words.restRow}</Text>
      <Segmented options={REST_MODES} value={value} onChange={onChange} />
    </View>
  );
}

function RhythmSection({ settings, actions }) {
  const [open, setOpen] = useState(false);
  return (
    <View>
      <DomySection title={words.rhythm} footer={words.closeTimeSub}>
        <RestModeRow value={settings.restMode} onChange={actions.onSetRestMode} />
        <DomySettingsRow
          label={words.closeTimeRow}
          picker={{ value: settings.closeTime, onPress: () => setOpen(true) }}
        />
      </DomySection>
      <Sheet visible={open} title={words.closeTimeRow} onClose={() => setOpen(false)}>
        <Wheel options={CLOSE_TIMES} value={settings.closeTime} onChange={actions.onSetCloseTime} />
        <BigButton label={words.ok} onPress={() => setOpen(false)} />
      </Sheet>
    </View>
  );
}

/**
 * 到點通知：允許「開著」；被拒「沒開」＋點了去系統設定（06 設定狀態表）；
 * 還沒問過什麼都不寫（第一次按開始才問，那時系統設定裡也還沒有這一列）。
 */
function notifRowProps(status) {
  if (status === 'undetermined') return {};
  if (status === 'denied') return { value: words.notifOff, onPress: () => Linking.openSettings() };
  return { value: words.notifOn };
}

function ReminderSection({ settings, actions, notif }) {
  return (
    <DomySection title={words.reminders}>
      <DomySettingsRow label={words.notifRow} {...notifRowProps(notif)} />
      <DomySettingsRow
        label={words.soundRow}
        toggle={{ value: !!settings.sound, onValueChange: actions.onSetSound }}
      />
    </DomySection>
  );
}

function FeelSection({ settings, actions }) {
  return (
    <DomySection title={words.feel}>
      <DomySettingsRow
        label={words.tiltRow}
        toggle={{ value: !!settings.tilt, onValueChange: actions.onSetTilt }}
      />
    </DomySection>
  );
}

/** 開發期才有的測試模式開關（正式 build 整區不畫）。 */
function DevSection({ settings, actions }) {
  if (!__DEV__) return null;
  return (
    <DomySection title={words.devSection} footer={words.testModeSub}>
      <DomySettingsRow
        label={words.testModeRow}
        toggle={{ value: !!settings.demo, onValueChange: actions.onSetTestMode }}
      />
    </DomySection>
  );
}

const PROBLEM_WORDS = {
  unreadable: words.importUnreadable,
  tooBig: words.importTooBig,
  backupFailed: words.autoBackupFailed,
  exportFailed: words.exportFailed,
  backupsLeft: words.backupsLeft,
};

/** 備份：匯出、匯入兩列；出錯原因（有才出）紅字在卡片下；說明與上次自動備份時間（S3）放 footer。 */
function BackupSection({ backup }) {
  const T = useTokens();
  const last = backup.lastBackup
    ? words.lastAutoBackup(
        `${words.monthDay(dayKey(backup.lastBackup))} ${hhmm(backup.lastBackup)}`,
      )
    : null;
  return (
    <View style={{ gap: T.space.s }}>
      <DomySection
        title={words.backup}
        footer={last ? `${words.backupNote}\n${last}` : words.backupNote}
      >
        <DomySettingsRow label={words.exportBackup} onPress={backup.onExport} />
        <DomySettingsRow label={words.importBackup} onPress={backup.onImport} />
      </DomySection>
      {backup.problem ? (
        <Text style={{ ...T.font.sub, color: T.color.danger, paddingHorizontal: T.space.card }}>
          {PROBLEM_WORDS[backup.problem]}
        </Text>
      ) : null}
    </View>
  );
}

export function Settings({ state, actions, notif, backup, onWipe }) {
  const T = useTokens();
  const clearance = useTabBarClearance();
  return (
    <View style={{ flex: 1 }}>
      <PageTitle>{words.settings}</PageTitle>
      <ScrollView
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{
          gap: T.space.section,
          paddingTop: T.space.l,
          paddingBottom: clearance,
        }}
      >
        <TypesSection settings={state.settings} actions={actions} />
        <RhythmSection settings={state.settings} actions={actions} />
        <ReminderSection settings={state.settings} actions={actions} notif={notif} />
        <FeelSection settings={state.settings} actions={actions} />
        <DevSection settings={state.settings} actions={actions} />
        <BackupSection backup={backup} />
        <DomySection>
          <DomySettingsRow destructive label={words.wipeAll} onPress={onWipe} />
        </DomySection>
      </ScrollView>
    </View>
  );
}
