// 殼：開機讀檔、每一拍看時鐘、到點換畫面、每次改動就存、狀態變了就重排通知。狀態機在 core/machine.js，畫面在 screens/。
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AppState,
  KeyboardAvoidingView,
  Linking,
  Platform,
  SafeAreaView,
  Text,
  View,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { useTokens } from './design/Tokens';
import { words } from './design/words';
import { dayKey, load, save } from './core/store';
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
import { askPermissionOnce, isGranted, planned, sync } from './core/notify';
import {
  addType,
  estimate,
  pickTask,
  pickType,
  removeType,
  renameType,
  setTypeLen,
} from './core/settings';
import { useNow } from './ui/useNow';
import { TextButton } from './ui/TextButton';
import { Home } from './screens/Home';
import { Bell } from './screens/Bell';
import { Settings } from './screens/Settings';
import { Rack } from './screens/Rack';

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

/** 權限狀態：開機與回前景各看一次（使用者可能剛從系統設定改回來）。剛打開時要重排一次通知，所以回報「翻成允許」。 */
function useNotificationDenied(onGranted) {
  const [denied, setDenied] = useState(false);
  const wasDenied = useRef(false);
  useEffect(() => {
    const refresh = () =>
      isGranted()
        .then((ok) => {
          setDenied(!ok);
          if (ok && wasDenied.current) onGranted();
          wasDenied.current = !ok;
        })
        .catch(() => {});
    refresh();
    const sub = AppState.addEventListener('change', (next) => {
      if (next === 'active') refresh();
    });
    return () => sub.remove();
  }, [onGranted]);
  return [denied, setDenied];
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
      const seen = seePlanted(s, Date.now());
      if (seen === s) return;
      setGreet(true);
      commit(seen);
    });
    return () => sub.remove();
  }, [stateRef, commit]);
  return [greet, setGreet];
}

/** 狀態與動作全在這裡：殼只負責排版。每個動作先算新狀態（純函式），再 commit（存檔＋對齊通知）。 */
function useDouzhang() {
  const now = useNow();
  const [state, setState] = useState(null); // null＝還在讀檔
  const [saveFailed, setSaveFailed] = useState(false);
  const [unreadable, setUnreadable] = useState(false); // 本機檔讀不懂：先不覆蓋（I1），清空要等 G4
  const arm = useArm();
  const stateRef = useRef(null);
  useEffect(() => {
    stateRef.current = state;
  }, [state]);
  const rearm = useCallback(() => {
    if (stateRef.current) arm(stateRef.current, true);
  }, [arm]);
  const [notifDenied, setNotifDenied] = useNotificationDenied(rearm);

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

  useEffect(() => {
    let alive = true;
    load().then(({ state: loaded, unreadable: broken }) => {
      if (!alive) return;
      setUnreadable(broken);
      const settled = settle(loaded, Date.now());
      const seen = seePlanted(settled, Date.now());
      setState(seen);
      if (seen !== settled) {
        setGreet(true);
        save(seen).then((ok) => setSaveFailed(!ok)); // 標成看過要存下來，不然每次開都打招呼
      }
      arm(seen, true); // 開機對齊：系統裡排的要跟現在的狀態一致
    });
    return () => {
      alive = false;
    };
  }, [arm, setGreet]);

  if (!state) return null;
  // 休息到點沒按也回待機：每一拍在 render 時把過期的休息收掉，下一次動作才存回去
  const live = settle(state, now);
  const actions = {
    onStart: async (opts) => {
      // 只有第一次（還沒問過）才會真的跳框；問不到也照樣開始（核心不靠通知）
      let ok = false;
      try {
        ok = await askPermissionOnce();
      } catch {
        ok = false;
      }
      setNotifDenied(!ok);
      setGreet(false); // 招呼只到開始第一顆為止
      act((t) => start(live, t, opts));
    },
    ...makeActions(live, act, commit),
  };
  const view = { ...live, todayKey: dayKey(now) }; // 畫面要知道「今天」是哪一天（估過的事只看今天）
  return {
    live: view,
    now,
    phase: phaseOf(live, now),
    greet,
    saveFailed,
    unreadable,
    notifDenied,
    actions,
  };
}

/** 開始以外的動作：純函式算新狀態，act 會先看按下那一刻的時鐘，commit 不需要時鐘。 */
function makeActions(live, act, commit) {
  return {
    onKeep: (text) => act((t) => keep(live, t, text)),
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
    // 收工與葉子（F）
    onCloseDay: (text) => act((t) => closeDay(live, t, text)),
    onHangLeaf: () => act((t) => hangLeaf(live, t)),
  };
}

export default function App() {
  const T = useTokens();
  const dz = useDouzhang();
  const [screen, setScreen] = useState('home'); // 'home'｜'settings'｜'rack'
  const jarSeen = useRef(null); // 豆罐上次看到幾顆：鈴響時豆罐卸載，收下後重掛要知道哪顆是新的
  if (!dz) return <View style={{ flex: 1, backgroundColor: T.color.background }} />;
  const { live, now, phase, greet, saveFailed, unreadable, notifDenied, actions } = dz;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: T.color.background }}>
      <StatusBar style="auto" />
      <KeyboardAvoidingView
        style={{ flex: 1, paddingHorizontal: T.space.l, paddingBottom: T.space.m }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        {unreadable ? <DangerLine>{words.importUnreadable}</DangerLine> : null}
        {saveFailed ? <DangerLine>{words.saveFailed}</DangerLine> : null}
        {notifDenied && phase === PHASE.focus ? (
          <NotificationOffLine onOpen={() => Linking.openSettings()} />
        ) : null}
        {phase === PHASE.bell ? (
          <Bell
            current={live.current}
            now={now}
            draft={live.current.draft || ''}
            onDraft={actions.onDraft}
            onKeep={(text) => {
              setScreen('home'); // 停在設定或豆棚時響了：收下後回主畫面的休息，不是回原來那頁
              actions.onKeep(text);
            }}
            onFlow={(minutes) => {
              setScreen('home');
              actions.onFlow(minutes);
            }}
          />
        ) : screen === 'settings' ? (
          <Settings state={live} actions={actions} onBack={() => setScreen('home')} />
        ) : screen === 'rack' ? (
          <Rack state={live} now={now} actions={actions} onBack={() => setScreen('home')} />
        ) : (
          <Home
            state={live}
            phase={phase}
            now={now}
            greet={greet}
            jarSeen={jarSeen}
            actions={actions}
            onRack={() => setScreen('rack')}
            onSettings={() => setScreen('settings')}
          />
        )}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}
