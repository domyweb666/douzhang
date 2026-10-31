// 殼：開機讀檔、每一拍看時鐘、到點換畫面、每次改動就存。狀態機在 core/machine.js，畫面在 screens/。
import { useCallback, useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, SafeAreaView, Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { useTokens } from './design/Tokens';
import { words } from './design/words';
import { load, save } from './core/store';
import { PHASE, backFromRest, keep, phaseOf, settle, start } from './core/machine';
import { useNow } from './ui/useNow';
import { Home } from './screens/Home';
import { Bell } from './screens/Bell';

export default function App() {
  const T = useTokens();
  const now = useNow();
  const [state, setState] = useState(null); // null＝還在讀檔
  const [saveFailed, setSaveFailed] = useState(false);
  const [unreadable, setUnreadable] = useState(false); // 本機檔讀不懂：先不覆蓋（I1），清空要等 G4

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

  const commit = useCallback(
    (next) => {
      setState(next);
      if (unreadable) return; // 壞檔不蓋（I1）：畫面照常，只是不寫回去
      save(next).then((ok) => setSaveFailed(!ok)); // S6：寫失敗要被看到
    },
    [unreadable],
  );

  if (!state) {
    return <View style={{ flex: 1, backgroundColor: T.color.background }} />;
  }

  // 休息到點沒按也回待機：每一拍在 render 時把過期的休息收掉，下一次動作才存回去
  const live = settle(state, now);
  const phase = phaseOf(live, now);
  const onStart = (opts) => commit(start(live, Date.now(), opts));
  const onKeep = (text) => commit(keep(live, Date.now(), text));
  const onBackFromRest = () => commit(backFromRest(live));

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: T.color.background }}>
      <StatusBar style="auto" />
      <KeyboardAvoidingView
        style={{ flex: 1, paddingHorizontal: T.space.l, paddingBottom: T.space.m }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        {unreadable ? (
          <Text style={{ ...T.font.caption, color: T.color.danger, marginTop: T.space.s }}>
            {words.importUnreadable}
          </Text>
        ) : null}
        {saveFailed ? (
          <Text style={{ ...T.font.caption, color: T.color.danger, marginTop: T.space.s }}>
            {words.saveFailed}
          </Text>
        ) : null}
        {phase === PHASE.bell ? (
          <Bell onKeep={onKeep} />
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
