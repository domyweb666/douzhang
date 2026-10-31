// 畫面用的時鐘：每 params.tickMs 刷新一次「現在」。倒數都用 endAt − now 算，不另外存剩幾秒。
import { useEffect, useState } from 'react';
import { AppState } from 'react-native';
import { params } from '../design/params';

export function useNow() {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const handle = setInterval(() => setNow(Date.now()), params.tickMs);
    // iOS 背景會停掉計時器；回前景那一刻立刻重算，第一幀就是對的態（鎖屏放過到點回來不閃計時中）
    const sub = AppState.addEventListener('change', (next) => {
      if (next === 'active') setNow(Date.now());
    });
    return () => {
      clearInterval(handle);
      sub.remove();
    };
  }, []);
  return now;
}

/** 剩餘毫秒 → 「m:ss」，不足 0 顯示 0:00。 */
export function mmss(ms) {
  const totalSeconds = Math.max(0, Math.ceil(ms / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = String(totalSeconds % 60).padStart(2, '0');
  return `${minutes}:${seconds}`;
}

/** 時刻 → 「HH:MM」（收據用）。 */
export function hhmm(timestamp) {
  const d = new Date(timestamp);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
