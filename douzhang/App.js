// 殼：開機讀檔、每一拍看時鐘、到點換畫面、每次改動就存、狀態變了就重排通知。狀態機在 core/machine.js，畫面在 screens/。
import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, AppState, KeyboardAvoidingView, Linking, Platform, Text, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import * as ScreenOrientation from 'expo-screen-orientation';
import { activateKeepAwakeAsync, deactivateKeepAwake } from 'expo-keep-awake';
import { Accelerometer } from 'expo-sensors';
import { DomyThemeProvider } from '@domy/design';
import { douzhangTheme } from './design/theme';
import { useTokens } from './design/Tokens';
import { words, tagLabel } from './design/words';
import { params } from './design/params';
import { POSE, startTracker, track } from './core/posture';
import { blank, dayKey, load, readRaw, save } from './core/store';
import {
  PHASE,
  backFromRest,
  flow,
  jot,
  keep,
  markDone,
  phaseOf,
  setDraft,
  settle,
  start,
  typeOf,
  voidBean,
} from './core/machine';
import { askPermissionOnce, notifStatus, planned, sync } from './core/notify';
import {
  autoBackup,
  exportBackup,
  lastAutoBackupAt,
  pickImport,
  removeAutoBackups,
} from './core/backup';
import { ambienceFor, applyAmbience } from './core/ambience';
import {
  applyShield,
  authorizeShield,
  forgetShield,
  pickShieldApps,
  shouldShield,
} from './core/shield';
import {
  addType,
  pickType,
  setAmbience,
  setAmbienceVolume,
  removeType,
  renameType,
  setRestLongEvery,
  setRestLongMinutes,
  setRestMode,
  setRestShort,
  setShield,
  setSound,
  setTilt,
  setTestMode,
  setTypeColor,
  setTypeLen,
} from './core/settings';
import { useNow } from './ui/useNow';
import { TextButton } from './ui/TextButton';
import { Home } from './screens/Home';
import { Bell } from './screens/Bell';
import { Focus } from './screens/Focus';
import { Settings } from './screens/Settings';
import { Rack } from './screens/Rack';
import { PageTabs, Pager } from './ui/Pager';
import { HomeIcon, RackIcon, SettingsIcon } from './ui/TabIcons';

function DangerLine({ children }) {
  const T = useTokens();
  return (
    <Text style={{ ...T.font.caption, color: T.color.danger, marginTop: T.space.s }}>
      {children}
    </Text>
  );
}

/** 通知被拒：一行狀態（不是錯誤）＋去系統設定的路。只在計時中顯示，不再跳任何框（安全 P2）。 */
function NotificationOffLine({ onOpen }) {
  const T = useTokens();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: T.space.s }}>
      <Text style={{ ...T.font.sub, color: T.color.textSecondary, flex: 1 }}>
        {words.notificationOffLine}
      </Text>
      <TextButton label={words.openNotifications} onPress={onOpen} />
    </View>
  );
}

/** 最上面那幾行狀態：本機檔讀不懂、存不進去、計時中通知沒開。都沒有就什麼都不佔。 */
function StatusLines({ unreadable, saveFailed, notifOff }) {
  const T = useTokens();
  return (
    <View style={{ paddingHorizontal: T.space.screen }}>
      {unreadable ? <DangerLine>{words.importUnreadable}</DangerLine> : null}
      {saveFailed ? <DangerLine>{words.saveFailed}</DangerLine> : null}
      {notifOff ? <NotificationOffLine onOpen={() => Linking.openSettings()} /> : null}
    </View>
  );
}

/** 鈴響頁連同它的邊距。onHome：收下或再做一下之後回主畫面（停在番茄架或設定時響了，不是回原來那頁）。 */
function BellPage({ state, now, actions, onHome }) {
  const T = useTokens();
  const insets = useSafeAreaInsets();
  const current = state.current;
  const then = (action) => (value) => {
    onHome();
    action(value);
  };
  return (
    <View
      style={{
        flex: 1,
        paddingHorizontal: T.space.screen,
        paddingBottom: insets.bottom + T.space.m,
      }}
    >
      <Bell
        state={state}
        current={current}
        now={now}
        draft={current.draft || ''}
        onDraft={actions.onDraft}
        onKeep={then(actions.onKeep)}
        onFlow={then(actions.onFlow)}
      />
    </View>
  );
}

/**
 * 權限狀態（notifStatus 三態）：開機與回前景各看一次（使用者可能剛從系統設定改回來）。
 * 從沒允許翻成允許時要重排一次通知，所以回報 onGranted。
 */
function useNotificationStatus(onGranted) {
  const [status, setStatus] = useState('undetermined');
  const wasOff = useRef(false);
  useEffect(() => {
    const refresh = () =>
      notifStatus()
        .then((next) => {
          setStatus(next);
          const ok = next === 'granted';
          if (ok && wasOff.current) onGranted();
          wasOff.current = !ok;
        })
        .catch(() => {});
    refresh();
    const sub = AppState.addEventListener('change', (next) => {
      if (next === 'active') refresh();
    });
    return () => sub.remove();
  }, [onGranted]);
  return [status, setStatus];
}

/** 狀態與通知對齊：內容沒變就不重排（存草稿每個字都 commit，不該每個字都取消再排）。 */
function useArm() {
  const lastPlan = useRef('');
  return useCallback((next, force) => {
    const plan = JSON.stringify(planned(next, Date.now()));
    if (!force && plan === lastPlan.current) return;
    lastPlan.current = plan;
    sync(next);
  }, []);
}

/**
 * 備份三件事（G2–G4）。確認框用系統 Alert（S4、S5），不自己畫。
 * 自動備份存的是「現在存著的原文」：本機檔讀不懂時，備份的是那份讀不懂的字，不是空白（S3）。
 * problem：設定頁備份區下面那一行（'unreadable'｜'tooBig'｜'backupFailed'｜'exportFailed'）。
 */
function useBackup(stateRef, unreadable, replaceAll) {
  const [lastBackup, setLastBackup] = useState(() => lastAutoBackupAt());
  const [problem, setProblem] = useState(null);
  const [wiped, setWiped] = useState(false);
  const savedText = async () => {
    try {
      return unreadable ? await readRaw() : JSON.stringify(stateRef.current);
    } catch {
      return null;
    }
  };

  const onExport = async () => {
    setProblem(null);
    const text = await savedText();
    if (!text || !(await exportBackup(text, Date.now()))) setProblem('exportFailed');
  };
  const onImport = async () => {
    setProblem(null);
    const picked = await pickImport();
    if (picked.canceled) return;
    if (picked.error) return setProblem(picked.error);
    let raw;
    try {
      raw = await readRaw(); // null＝什麼都還沒存過（剛裝好），沒有東西要備份
    } catch {
      return setProblem('backupFailed'); // 讀不到現在的資料就不知道要備份什麼：不匯（S3）
    }
    const t = Date.now();
    if (raw && !(await autoBackup(raw, t))) return setProblem('backupFailed');
    if (raw) setLastBackup(t);
    Alert.alert(words.importConfirm, undefined, [
      { text: words.cancel, style: 'cancel' },
      {
        text: words.importConfirmOk,
        onPress: () => {
          setWiped(false);
          replaceAll(settle(picked.state, Date.now()));
        },
      },
    ]);
  };
  const onWipe = (done) =>
    Alert.alert(words.wipeTitle, words.wipeBody, [
      { text: words.cancel, style: 'cancel' },
      {
        text: words.wipeAll,
        style: 'destructive',
        onPress: () => {
          const removed = removeAutoBackups(); // P5：清乾淨，含自動備份
          forgetShield(); // P5：擋板解開，選過要擋的 app 也忘掉
          setLastBackup(lastAutoBackupAt());
          setProblem(removed ? null : 'backupsLeft');
          setWiped(true);
          replaceAll(blank());
          done();
        },
      },
    ]);
  return { lastBackup, problem, wiped, onExport, onImport, onWipe };
}

const ZEN_AWAKE = 'zen';
/** 鎖方向。鎖不了（裝置不支援、Expo Go 不給）就照原方向畫，不擋計時。 */
const lockTo = (lock) => ScreenOrientation.lockAsync(lock).catch(() => {});

/**
 * 聚焦模式（2026-11-17）：計時中把手機橫放，或按「聚焦模式」，整頁換成橫向翻牌時鐘；直拿回來、按回主畫面或鈴響就回直向。
 * key：計時中那顆的記號（開始與結束時刻），沒在計時是 null。聚焦只跟著那一顆：響了、結束、再做一下都從直向重新開始。
 * 橫放靠加速度計看重力落在哪一軸（開著直向鎖定也有效）；沒有加速度計（模擬器）就只剩按鈕。
 * 聚焦模式開著時螢幕不自己熄。
 */
function useZen(key) {
  const [zenFor, setZenFor] = useState(null);
  const on = key != null && zenFor === key;
  const enter = useCallback(() => setZenFor(key), [key]);
  // 先轉回直向再換畫面：主畫面的番茄堆第一次排版就要是直的寬高
  const leave = useCallback(() => {
    lockTo(ScreenOrientation.OrientationLock.PORTRAIT_UP).then(() => setZenFor(null));
  }, []);

  useEffect(() => {
    const { LANDSCAPE, PORTRAIT_UP } = ScreenOrientation.OrientationLock;
    lockTo(on ? LANDSCAPE : PORTRAIT_UP);
    if (!on) return undefined;
    activateKeepAwakeAsync(ZEN_AWAKE).catch(() => {});
    return () => {
      deactivateKeepAwake(ZEN_AWAKE).catch(() => {});
    };
  }, [on]);

  useEffect(() => {
    if (key == null) return undefined;
    let sub = null;
    let gone = false;
    let tracker = startTracker();
    Accelerometer.isAvailableAsync()
      .then((ok) => {
        if (!ok || gone) return;
        Accelerometer.setUpdateInterval(params.zen.sampleMs);
        sub = Accelerometer.addListener((sample) => {
          const next = track(tracker, sample, Date.now(), params.zen);
          tracker = next.tracker;
          if (next.changed === POSE.landscape) enter();
          if (next.changed === POSE.portrait) leave();
        });
      })
      .catch(() => {});
    return () => {
      gone = true;
      sub?.remove();
    };
  }, [key, enter, leave]);

  return { on, enter, leave };
}

/**
 * 聚焦模式跟主畫面之間傳的東西。leaveTo(sheet)：離開聚焦回主畫面，sheet 是回去要直接開的半頁
 * （'note' 記一筆｜'end' 結束這顆｜null 不開）。forHome：主畫面要的三樣（見 Home 的 zen）。
 */
function useZenHandoff(zen, goHome) {
  const [sheet, setSheet] = useState(null);
  const clear = useCallback(() => setSheet(null), []);
  const leaveTo = (next) => {
    setSheet(next);
    goHome();
    zen.leave();
  };
  return {
    leaveTo,
    forHome: { onEnter: zen.enter, initialSheet: sheet, onInitialSheetOpened: clear },
  };
}

/** 計時中那顆的記號：再做一下會換結束時刻，所以延長後是新的記號。 */
const zenKeyOf = (dz) =>
  dz && dz.phase === PHASE.focus ? `${dz.live.current.startedAt}-${dz.live.current.endAt}` : null;

/** 狀態與動作全在這裡：殼只負責排版。每個動作先算新狀態（純函式），再 commit（存檔＋對齊通知）。 */
function useDouzhang() {
  const now = useNow();
  const [state, setState] = useState(null); // null＝還在讀檔
  const [saveFailed, setSaveFailed] = useState(false);
  const [unreadable, setUnreadable] = useState(false); // 本機檔讀不懂：先不覆蓋（I1），只有匯入或清空能換掉
  const [moment, setMoment] = useState(null); // 'cheer'｜null：剛收下一顆，火柴人還沒演過（Y1；不存檔，重開就沒有）
  const arm = useArm();
  const stateRef = useRef(null);
  useEffect(() => {
    stateRef.current = state;
  }, [state]);
  const rearm = useCallback(() => {
    if (stateRef.current) arm(stateRef.current, true);
  }, [arm]);
  const [notif, setNotif] = useNotificationStatus(rearm);

  const commit = useCallback(
    (next) => {
      setState(next);
      if (!unreadable) save(next).then((ok) => setSaveFailed(!ok)); // 壞檔不蓋（I1）；S6：寫失敗要被看到
      arm(next);
    },
    [unreadable, arm],
  );
  // 動作都在「按下那一刻」看時鐘：recipe 拿到現在的毫秒，回新狀態
  const act = useCallback((recipe) => commit(recipe(Date.now())), [commit]);
  // 匯入、清空：整份換掉。這是唯一准蓋掉「讀不懂的本機檔」的路（I1），所以不經 commit 的 unreadable 檢查
  const replaceAll = useCallback(
    (next) => {
      setUnreadable(false);
      setState(next);
      save(next).then((ok) => setSaveFailed(!ok));
      arm(next, true);
    },
    [arm],
  );
  const backup = useBackup(stateRef, unreadable, replaceAll);

  useEffect(() => {
    let alive = true;
    load().then(({ state: loaded, unreadable: broken }) => {
      if (!alive) return;
      setUnreadable(broken);
      const settled = settle(loaded, Date.now());
      setState(settled);
      arm(settled, true); // 開機對齊：系統裡排的要跟現在的狀態一致
    });
    return () => {
      alive = false;
    };
  }, [arm]);

  // 擋 app 跟著狀態走（AF1）：開關開著且這顆還在跑才蓋，其他時候解開。答案變了才叫原生；
  // 讀完檔第一次有答案時也叫一次（開機對齊）。null＝還在讀檔，先不動。
  // 響的那一刻 app 在背景的話時鐘不走，要等回到番茄帳才會解開（第一版的取捨）。
  const shielded = state ? shouldShield(state, now) : null;
  useEffect(() => {
    if (shielded !== null) applyShield(shielded);
  }, [shielded]);

  // 白噪音也跟著狀態走（AG6）：這顆還在跑才播設定選的那種，響了、收下、作廢就停；計時中換種類或音量當下生效。
  // 在背景播的時候 app 還醒著、時鐘照走，所以到點那一刻聲音會自己停，上面的擋板也會跟著解開。
  const ambience = state ? ambienceFor(state, now) : null;
  const ambienceLevel = state ? state.settings.ambienceVolume : null;
  useEffect(() => {
    if (ambience !== null) applyAmbience(ambience, ambienceLevel);
  }, [ambience, ambienceLevel]);

  if (!state) return null;
  // 休息到點沒按也回待機：每一拍在 render 時把過期的休息收掉，下一次動作才存回去
  const live = settle(state, now);
  const actions = makeActions(live, act, commit, { setNotif, setMoment });
  const view = { ...live, todayKey: dayKey(now) }; // 畫面要知道「今天」是哪一天（估過的事只看今天）
  return {
    live: view,
    now,
    phase: phaseOf(live, now),
    moment,
    saveFailed,
    unreadable,
    notif,
    actions,
    backup,
  };
}

/** 畫面拿到的動作：純函式算新狀態，act 會先看按下那一刻的時鐘，commit 不需要時鐘。 */
function makeActions(live, act, commit, { setNotif, setMoment }) {
  return {
    onStart: async (opts) => {
      // 只有第一次（還沒問過）才會真的跳框；問不到也照樣開始（核心不靠通知）
      let ok = false;
      try {
        ok = await askPermissionOnce();
      } catch {
        ok = false;
      }
      setNotif(ok ? 'granted' : 'denied');
      setMoment(null); // 沒演到的慶祝不留到下一顆
      act((t) => start(live, t, opts));
    },
    onKeep: (text) => {
      setMoment('cheer');
      act((t) => keep(live, t, text));
    },
    onBackFromRest: () => commit(backFromRest(live)),
    onFlow: (minutes) => act((t) => flow(live, t, minutes)),
    onDraft: (text) => commit(setDraft(live, text)), // 每個字都存：殺掉再開草稿才在
    onJot: (kind, text) => commit(jot(live, kind, text)),
    onDoneEarly: () => commit(markDone(live)),
    onVoid: (v) => act((t) => voidBean(live, t, v)),
    // 標籤（C1；2026-11-17 AG1 起介面上叫標籤，估幾顆拿掉）
    onPickType: (id) => commit(pickType(live, id)),
    onAddType: () => act((t) => addType(live, t)),
    onRenameType: (id, name) => commit(renameType(live, id, name)),
    onSetTypeLen: (id, len) => commit(setTypeLen(live, id, len)),
    onRemoveType: (id) => commit(removeType(live, id)),
    // 節奏、提醒、手感（G1）
    onSetRestMode: (mode) => commit(setRestMode(live, mode)),
    onSetRestShort: (v) => commit(setRestShort(live, v)),
    onSetRestLongEvery: (v) => commit(setRestLongEvery(live, v)),
    onSetRestLongMinutes: (v) => commit(setRestLongMinutes(live, v)),
    onSetSound: (on) => commit(setSound(live, on)),
    onSetTilt: (on) => commit(setTilt(live, on)),
    onSetTestMode: (on) => commit(setTestMode(live, on)),
    // 白噪音（AG6）
    onSetAmbience: (kind) => commit(setAmbience(live, kind)),
    onSetAmbienceVolume: (level) => commit(setAmbienceVolume(live, level)),
    // 擋 app（AF1）：兩個都回「有沒有授權」，設定頁靠它決定要不要寫那一行
    onSetShield: async (on) => {
      if (on && !(await authorizeShield())) return false; // 要打開才問；不允許就不開
      commit(setShield(live, on));
      return true;
    },
    onPickShieldApps: async () => {
      if (!(await authorizeShield())) return false; // 沒授權時系統的選擇畫面是空的
      await pickShieldApps();
      applyShield(shouldShield(live, Date.now())); // 計時中改了要擋的：照新選的重蓋一次
      return true;
    },
    onSetTypeColor: (id, color) => commit(setTypeColor(live, id, color)),
    onMascotDone: () => setMoment(null), // 火柴人演完了（Y1）
  };
}

const PAGE = { rack: 0, home: 1, settings: 2 };
const PAGE_LABELS = [words.rack, words.home, words.settings];
const TOP_EDGES = ['top', 'left', 'right'];
const PAGE_TABS = [
  { label: words.rack, Icon: RackIcon },
  { label: words.home, Icon: HomeIcon },
  { label: words.settings, Icon: SettingsIcon },
];

/** 2026-11-14 照 Domy Design System 重新設計：最外層包安全區與茄紫 Theme，useTokens() 才拿得到顏色。 */
export default function App() {
  return (
    <SafeAreaProvider>
      <DomyThemeProvider theme={douzhangTheme}>
        <Main />
      </DomyThemeProvider>
    </SafeAreaProvider>
  );
}

/** 下緣不留安全區：分頁列自己避開 Home 指示條，番茄堆停在分頁列上面（各頁用 useTabBarClearance）。 */
function Main() {
  const T = useTokens();
  const dz = useDouzhang();
  const [page, setPage] = useState(PAGE.home); // 左右滑三頁：番茄架｜主畫面｜設定
  const jarSeen = useRef(null); // 豆罐上次看到幾顆：鈴響時豆罐卸載，收下後重掛要知道哪顆是新的
  const zen = useZen(zenKeyOf(dz));
  const handoff = useZenHandoff(zen, () => setPage(PAGE.home));
  if (!dz) return <View style={{ flex: 1, backgroundColor: T.color.background }} />;
  const { live, now, phase, moment, saveFailed, unreadable, notif, actions, backup } = dz;
  const zenType = zen.on ? typeOf(live, live.current.typeId) : null;
  if (zen.on)
    return (
      <Focus
        current={live.current}
        now={now}
        color={zenType.color}
        label={tagLabel(zenType)}
        onLeave={handoff.leaveTo}
      />
    );
  return (
    <SafeAreaView edges={TOP_EDGES} style={{ flex: 1, backgroundColor: T.color.background }}>
      <StatusBar style="auto" />
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <StatusLines
          unreadable={unreadable}
          saveFailed={saveFailed}
          notifOff={notif === 'denied' && phase === PHASE.focus}
        />
        {phase === PHASE.bell ? (
          <BellPage state={live} now={now} actions={actions} onHome={() => setPage(PAGE.home)} />
        ) : (
          <Pager page={page} onPage={setPage} labels={PAGE_LABELS}>
            <Rack
              state={live}
              now={now}
              wiped={backup.wiped}
              active={page === PAGE.rack}
              onSettings={() => setPage(PAGE.settings)}
              onBack={() => setPage(PAGE.home)}
            />
            <Home
              state={live}
              phase={phase}
              now={now}
              moment={page === PAGE.home ? moment : null} // 火柴人只在主畫面是眼前那頁時演（Y1）
              jarSeen={jarSeen}
              actions={actions}
              zen={handoff.forHome}
            />
            <Settings
              state={live}
              actions={actions}
              notif={notif}
              backup={backup}
              onWipe={() => backup.onWipe(() => setPage(PAGE.home))}
            />
          </Pager>
        )}
      </KeyboardAvoidingView>
      {phase === PHASE.bell ? null : <PageTabs page={page} onPage={setPage} tabs={PAGE_TABS} />}
    </SafeAreaView>
  );
}
