// 畫面用的時鐘：每 params.tickMs 刷新一次「現在」。倒數都用 endAt − now 算，不另外存剩幾秒。
import { useEffect, useState } from 'react';
import { params } from '../design/params';

export function useNow() {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const handle = setInterval(() => setNow(Date.now()), params.tickMs);
    return () => clearInterval(handle);
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
