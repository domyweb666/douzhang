// 殼：開機讀檔、每一拍看時鐘、到點換畫面、每次改動就存、狀態變了就重排通知。狀態機在 core/machine.js，畫面在 screens/。
import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, AppState, KeyboardAvoidingView, Linking, Platform, Text, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { DomyThemeProvider } from '@domy/design';
import { douzhangTheme } from './design/theme';
import { useTokens } from './design/Tokens';
import { words } from './design/words';
import { blank, dayKey, load, readRaw, save } from './core/store';
import {
  PHASE,
  backFromRest,
  closeDay,
  flow,
  hangLeaf,
  jot,
  keep,
  markDone,
  phaseOf,
  seePlanted,
  setDraft,
  settle,
  start,
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
import {
  addType,
  estimate,
  pickTask,
  pickType,
  removeType,
  renameType,
  setCloseTime,
  setRestMode,
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
 * 昨天收工種下的那句：今天第一次看到時小標打招呼一次（F1）。開機那一次由讀檔處理；
 * iOS 的「明天打開」多半是從背景叫回來、不是重開，所以回前景也看一次。
 */
function useGreeting(stateRef, commit) {
  const [greet, setGreet] = useState(false);
  useEffect(() => {
    const sub = AppState.addEventListener('change', (next) => {
      const s = stateRef.current;
      if (next !== 'active' || !s) return;
      const t = Date.now();
      const seen = seePlanted(settle(s, t), t); // 過期的休息先收掉，才算回到待機
      setGreet(seen.greet); // 每次叫回來重新判斷：打過招呼後再打開一次就回到「下一步」
      if (seen.state.planted !== s.planted) commit(seen.state);
    });
    return () => sub.remove();
  }, [stateRef, commit]);
  return [greet, setGreet];
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

/** 狀態與動作全在這裡：殼只負責排版。每個動作先算新狀態（純函式），再 commit（存檔＋對齊通知）。 */
function useDouzhang() {
  const now = useNow();
  const [state, setState] = useState(null); // null＝還在讀檔
  const [saveFailed, setSaveFailed] = useState(false);
  const [unreadable, setUnreadable] = useState(false); // 本機檔讀不懂：先不覆蓋（I1），只有匯入或清空能換掉
  const [moment, setMoment] = useState(null); // 'cheer'｜'bow'｜null：剛收下一顆、剛收工或掛葉子，火柴人還沒演過（Y1；不存檔，重開就沒有）
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
  const [greet, setGreet] = useGreeting(stateRef, commit);
  // 匯入、清空：整份換掉。這是唯一准蓋掉「讀不懂的本機檔」的路（I1），所以不經 commit 的 unreadable 檢查
  const replaceAll = useCallback(
    (next) => {
      setUnreadable(false);
      setGreet(false);
      setState(next);
      save(next).then((ok) => setSaveFailed(!ok));
      arm(next, true);
    },
    [arm, setGreet],
  );
  const backup = useBackup(stateRef, unreadable, replaceAll);

  useEffect(() => {
    let alive = true;
    load().then(({ state: loaded, unreadable: broken }) => {
      if (!alive) return;
      setUnreadable(broken);
      const settled = settle(loaded, Date.now());
      const seen = seePlanted(settled, Date.now());
      setState(seen.state);
      setGreet(seen.greet);
      // 標成看過要存下來，不然每次開都打招呼；壞檔不蓋（I1，跟 commit 同一條規則）
      if (seen.state !== settled && !broken) save(seen.state).then((ok) => setSaveFailed(!ok));
      arm(seen.state, true); // 開機對齊：系統裡排的要跟現在的狀態一致
    });
    return () => {
      alive = false;
    };
  }, [arm, setGreet]);

  if (!state) return null;
  // 休息到點沒按也回待機：每一拍在 render 時把過期的休息收掉，下一次動作才存回去
  const live = settle(state, now);
  const actions = makeActions(live, act, commit, { setNotif, setGreet, setMoment });
  const view = { ...live, todayKey: dayKey(now) }; // 畫面要知道「今天」是哪一天（估過的事只看今天）
  return {
    live: view,
    now,
    phase: phaseOf(live, now),
    greet,
    moment,
    saveFailed,
    unreadable,
    notif,
    actions,
    backup,
  };
}

/** 畫面拿到的動作：純函式算新狀態，act 會先看按下那一刻的時鐘，commit 不需要時鐘。 */
function makeActions(live, act, commit, { setNotif, setGreet, setMoment }) {
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
      setGreet(false); // 招呼只到開始第一顆為止
      setMoment(null); // 沒演到的慶祝或鞠躬不留到下一顆
      act((t) => start(live, t, opts));
    },
    onKeep: (text) => {
      setGreet(false); // 收下了新的一句，卡片上已經不是昨天那句
      setMoment('cheer');
      act((t) => keep(live, t, text));
    },
    onBackFromRest: () => commit(backFromRest(live)),
    onFlow: (minutes) => act((t) => flow(live, t, minutes)),
    onDraft: (text) => commit(setDraft(live, text)), // 每個字都存：殺掉再開草稿才在
    onJot: (kind, text) => commit(jot(live, kind, text)),
    onDoneEarly: () => commit(markDone(live)),
    onVoid: (v) => act((t) => voidBean(live, t, v)),
    // 類型與估幾顆（C）
    onPickType: (id) => commit(pickType(live, id)),
    onAddType: () => act((t) => addType(live, t)),
    onRenameType: (id, name) => commit(renameType(live, id, name)),
    onSetTypeLen: (id, len) => commit(setTypeLen(live, id, len)),
    onRemoveType: (id) => commit(removeType(live, id)),
    onEstimate: (v) => act((t) => estimate(live, t, v)),
    onPickTask: (id) => act((t) => pickTask(live, t, id)),
    // 節奏、提醒、手感（G1）
    onSetRestMode: (mode) => commit(setRestMode(live, mode)),
    onSetCloseTime: (time) => commit(setCloseTime(live, time)),
    onSetSound: (on) => commit(setSound(live, on)),
    onSetTilt: (on) => commit(setTilt(live, on)),
    onSetTestMode: (on) => commit(setTestMode(live, on)),
    onSetTypeColor: (id, color) => commit(setTypeColor(live, id, color)),
    // 收工與葉子（F）
    onCloseDay: (text) => {
      setMoment('bow');
      act((t) => closeDay(live, t, text));
    },
    onHangLeaf: () => {
      setMoment('bow');
      act((t) => hangLeaf(live, t));
    },
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
  const insets = useSafeAreaInsets();
  const dz = useDouzhang();
  const [page, setPage] = useState(PAGE.home); // 左右滑三頁：番茄架｜主畫面｜設定
  const jarSeen = useRef(null); // 豆罐上次看到幾顆：鈴響時豆罐卸載，收下後重掛要知道哪顆是新的
  if (!dz) return <View style={{ flex: 1, backgroundColor: T.color.background }} />;
  const { live, now, phase, greet, moment, saveFailed, unreadable, notif, actions, backup } = dz;
  return (
    <SafeAreaView edges={TOP_EDGES} style={{ flex: 1, backgroundColor: T.color.background }}>
      <StatusBar style="auto" />
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <View style={{ paddingHorizontal: T.space.screen }}>
          {unreadable ? <DangerLine>{words.importUnreadable}</DangerLine> : null}
          {saveFailed ? <DangerLine>{words.saveFailed}</DangerLine> : null}
          {notif === 'denied' && phase === PHASE.focus ? (
            <NotificationOffLine onOpen={() => Linking.openSettings()} />
          ) : null}
        </View>
        {phase === PHASE.bell ? (
          <View
            style={{
              flex: 1,
              paddingHorizontal: T.space.screen,
              paddingBottom: insets.bottom + T.space.m,
            }}
          >
            <Bell
              current={live.current}
              now={now}
              draft={live.current.draft || ''}
              onDraft={actions.onDraft}
              onKeep={(text) => {
                setPage(PAGE.home); // 停在番茄架或設定時響了：收下後回主畫面的休息，不是回原來那頁
                actions.onKeep(text);
              }}
              onFlow={(minutes) => {
                setPage(PAGE.home);
                actions.onFlow(minutes);
              }}
            />
          </View>
        ) : (
          <Pager page={page} onPage={setPage} labels={PAGE_LABELS}>
            <Rack
              state={live}
              now={now}
              actions={actions}
              wiped={backup.wiped}
              active={page === PAGE.rack}
              onSettings={() => setPage(PAGE.settings)}
              onBack={() => setPage(PAGE.home)}
            />
            <Home
              state={live}
              phase={phase}
              now={now}
              greet={greet}
              moment={page === PAGE.home ? moment : null} // 火柴人只在主畫面是眼前那頁時演（Y1）
              wiped={backup.wiped}
              jarSeen={jarSeen}
              actions={actions}
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
