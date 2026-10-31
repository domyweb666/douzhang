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
import { load, save } from './core/store';
import { PHASE, backFromRest, flow, keep, phaseOf, setDraft, settle, start } from './core/machine';
import { askPermissionOnce, isGranted, planned, sync } from './core/notify';
import { useNow } from './ui/useNow';
import { TextButton } from './ui/TextButton';
import { Home } from './screens/Home';
import { Bell } from './screens/Bell';

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

export default function App() {
  const T = useTokens();
  const now = useNow();
  const [state, setState] = useState(null); // null＝還在讀檔
  const [saveFailed, setSaveFailed] = useState(false);
  const [unreadable, setUnreadable] = useState(false); // 本機檔讀不懂：先不覆蓋（I1），清空要等 G4
  const [notifDenied, setNotifDenied] = useState(false);
  const lastPlan = useRef(''); // 上次排給系統的內容；沒變就不重排（存草稿每個字都 commit，不該每個字都取消再排）

  useEffect(() => {
    let alive = true;
    load().then(({ state: loaded, unreadable: broken }) => {
      if (!alive) return;
      setUnreadable(broken);
      setState(settle(loaded, Date.now()));
    });
    return () => {
      alive = false;
    };
  }, []);

  // 權限狀態：開機與回前景各看一次（使用者可能剛從系統設定改回來）
  useEffect(() => {
    const refresh = () => isGranted().then((ok) => setNotifDenied(!ok));
    refresh();
    const sub = AppState.addEventListener('change', (next) => {
      if (next === 'active') refresh();
    });
    return () => sub.remove();
  }, []);

  const commit = useCallback(
    (next) => {
      setState(next);
      if (!unreadable) save(next).then((ok) => setSaveFailed(!ok)); // 壞檔不蓋（I1）；S6：寫失敗要被看到
      const plan = JSON.stringify(planned(next, Date.now()));
      if (plan !== lastPlan.current) {
        lastPlan.current = plan;
        sync(next);
      }
    },
    [unreadable],
  );

  if (!state) {
    return <View style={{ flex: 1, backgroundColor: T.color.background }} />;
  }

  // 休息到點沒按也回待機：每一拍在 render 時把過期的休息收掉，下一次動作才存回去
  const live = settle(state, now);
  const phase = phaseOf(live, now);
  const onStart = async (opts) => {
    // 只有第一次（還沒問過）才會真的跳框；之後這一行只是讀狀態
    const ok = await askPermissionOnce();
    setNotifDenied(!ok);
    commit(start(live, Date.now(), opts));
  };
  const onKeep = (text) => commit(keep(live, Date.now(), text));
  const onBackFromRest = () => commit(backFromRest(live));
  const onFlow = (minutes) => commit(flow(live, Date.now(), minutes));
  const onDraft = (text) => commit(setDraft(live, text)); // 每個字都存：殺掉再開草稿才在

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
            onDraft={onDraft}
            onKeep={onKeep}
            onFlow={onFlow}
          />
        ) : (
          <Home
            state={live}
            phase={phase}
            now={now}
            onStart={onStart}
            onBackFromRest={onBackFromRest}
          />
        )}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}
