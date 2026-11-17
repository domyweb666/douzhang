// 設定（左右滑三頁的右邊那頁）。依序：標籤、節奏、提醒、專注、手感、備份（PRD S18；2026-11-17 AG1 類型改叫標籤、拿掉收工時間）。
// 任務類型 C1；節奏、提醒、手感 G1；備份與清空 G2–G4。狀態機在 core/settings.js，改完立刻生效（下一拍就讀新設定）。
// U10（2026-11-02）：類型與收工時間改成「一列一個值 ›」，點了從底部開半頁用 iOS 滾輪選（原本一排排膠囊要找黑的那顆）。
// 2026-11-14 照 Domy Design System 重新設計：每區是一個 DomySection（標題＋白卡，列之間自動分隔線），
// 列用 DomySettingsRow（值＋箭頭、產品色膠囊、開關三種尾巴），說明字放在區塊的 footer。
import { useState } from 'react';
import { Linking, Pressable, ScrollView, Text, View } from 'react-native';
import { DomySection, DomySettingsRow, useTabBarClearance } from '@domy/design';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { TextButton } from '../ui/TextButton';
import { PageTitle } from '../ui/PageTitle';
import { Segmented } from '../ui/Segmented';
import { Sheet } from '../ui/Sheet';
import { TagEditSheet, Wheel } from '../ui/TagSheets';
import { BigButton } from '../ui/BigButton';
import { hhmm } from '../ui/useNow';
import { Tomato } from '../ui/Tomato';
import { dayKey } from '../core/store';
import { shieldAvailable, shieldCount } from '../core/shield';

const REST_SHORTS = params.restShortOptions.map((v) => ({
  value: v,
  label: v === 'auto' ? words.restShortAuto : words.minutes(v),
}));
const REST_LONG_EVERY = params.restLongEveryOptions.map((n) => ({
  value: n,
  label: n ? words.restLongEvery(n) : words.restLongOff,
}));
const REST_LONG_MINUTES = params.restLongMinuteOptions.map((m) => ({
  value: m,
  label: words.minutes(m),
}));
const REST_MODES = [
  { value: 'auto', label: words.restModeAuto },
  { value: 'self', label: words.restModeSelf },
];

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
      <Tomato color={type.color} size={icon} />
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
      <DomySection title={words.taskType} footer={words.typeSub}>
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
      <TagEditSheet
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

/** 節奏那區卡片下的說明：休息怎麼算（看得到那兩列時才講）。 */
function rhythmFooter(settings) {
  const lines = [];
  if (settings.restMode === 'self') lines.push(words.restSelfSub);
  else {
    if (settings.restShort === 'auto') lines.push(words.restShortAutoSub);
    if (settings.restLongEvery)
      lines.push(words.restLongSub(settings.restLongEvery, settings.restLongMinutes));
  }
  return lines.join('\n');
}

/** 長休息半頁：左邊每幾顆（含「關」）、右邊幾分，兩個滾輪並排。 */
function LongRestWheels({ settings, actions }) {
  return (
    <View style={{ flexDirection: 'row' }}>
      <View style={{ flex: 1 }}>
        <Wheel
          options={REST_LONG_EVERY}
          value={settings.restLongEvery}
          onChange={actions.onSetRestLongEvery}
        />
      </View>
      <View style={{ flex: 1 }}>
        <Wheel
          options={REST_LONG_MINUTES}
          value={settings.restLongMinutes}
          onChange={actions.onSetRestLongMinutes}
        />
      </View>
    </View>
  );
}

/** 「我自己決定」的休息沒有長度，短休息、長休息兩列收起來（2026-11-17 設定 A）。 */
function RhythmSection({ settings, actions }) {
  const [open, setOpen] = useState(null); // 'short'｜'long'｜null
  const close = () => setOpen(null);
  const timed = settings.restMode !== 'self';
  const longValue = settings.restLongEvery
    ? words.restLongValue(settings.restLongEvery, settings.restLongMinutes)
    : words.restLongOff;
  return (
    <View>
      <DomySection title={words.rhythm} footer={rhythmFooter(settings)}>
        <RestModeRow value={settings.restMode} onChange={actions.onSetRestMode} />
        {timed ? (
          <DomySettingsRow
            label={words.restShortRow}
            value={REST_SHORTS.find((o) => o.value === settings.restShort).label}
            onPress={() => setOpen('short')}
          />
        ) : null}
        {timed ? (
          <DomySettingsRow
            label={words.restLongRow}
            value={longValue}
            onPress={() => setOpen('long')}
          />
        ) : null}
      </DomySection>
      <Sheet visible={open === 'short'} title={words.restShortRow} onClose={close}>
        <Wheel options={REST_SHORTS} value={settings.restShort} onChange={actions.onSetRestShort} />
        <BigButton label={words.ok} onPress={close} />
      </Sheet>
      <Sheet visible={open === 'long'} title={words.restLongRow} onClose={close}>
        <LongRestWheels settings={settings} actions={actions} />
        <BigButton label={words.ok} onPress={close} />
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

/**
 * 計時中擋住其他 app（AF1）。沒有原生模組（Expo Go、Android）整區不畫。
 * 兩列都要先有螢幕使用時間的授權：不允許就不開、不開選擇畫面，卡片下換成那一行說明。
 */
function ShieldSection({ settings, actions }) {
  const [denied, setDenied] = useState(false);
  if (!shieldAvailable) return null;
  const count = shieldCount();
  const onToggle = async (on) => setDenied(!(await actions.onSetShield(on)));
  const onPick = async () => setDenied(!(await actions.onPickShieldApps()));
  return (
    <DomySection title={words.shieldSection} footer={denied ? words.shieldDenied : words.shieldSub}>
      <DomySettingsRow
        label={words.shieldRow}
        toggle={{ value: !!settings.shield, onValueChange: onToggle }}
      />
      <DomySettingsRow
        label={words.shieldAppsRow}
        value={count ? words.shieldAppsCount(count) : words.shieldAppsNone}
        onPress={onPick}
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
        <ShieldSection settings={state.settings} actions={actions} />
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
