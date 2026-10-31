// 豆帳 通知：只有「到點」一種（這顆到點、休息到點），文案固定、不含那句（安全 P3）。
// 每次轉態「全部取消再排」，不做差量（藍圖危險方塊「通知排程」）。
// 該排什麼由純函式 planned() 算，殼只負責在狀態改變後叫 sync()。核心迴圈不靠通知：前景時 app 自己切鈴響頁。
import * as Notifications from 'expo-notifications';
import { PHASE } from './machine';
import { words } from '../design/words';

// 前景收到通知：不跳橫幅、不進清單，只出聲（畫面那一刻已經是鈴響頁）
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: false,
    shouldShowList: false,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

/** 現在這個狀態該排哪些通知。已經過了的時刻不排（鈴響頁等人回來時沒有通知可排）。 */
export function planned(state, now) {
  const c = state.current;
  if (!c || c.endAt <= now) return [];
  if (c.phase === PHASE.focus) return [{ title: words.rang, body: words.bellSub, at: c.endAt }];
  if (c.phase === PHASE.rest && state.settings.restMode === 'auto')
    return [{ title: words.restDone, body: words.backFromRest, at: c.endAt }];
  return [];
}

/** 只問一次：已允許回 true；被拒且不能再問回 false、不跳框（P2）；只有還沒問過才跳系統框。 */
export async function askPermissionOnce() {
  const before = await Notifications.getPermissionsAsync();
  if (before.granted) return true;
  if (!before.canAskAgain) return false;
  // 只要橫幅與聲音，不要徽章（安全 P1 的精神：只申請用得到的）
  const after = await Notifications.requestPermissionsAsync({
    ios: { allowAlert: true, allowSound: true, allowBadge: false },
  });
  return after.granted;
}

export async function isGranted() {
  const p = await Notifications.getPermissionsAsync();
  return p.granted;
}

let queue = Promise.resolve(); // 連續兩次轉態時，後一次要等前一次「取消＋排」做完，不然會排出兩則

/** 全部取消再照 planned() 重排。排不進去（沒權限）不丟例外：那一行提示由殼顯示。 */
export function sync(state, now = Date.now()) {
  queue = queue.then(() => arm(state, now));
  return queue;
}

async function arm(state, now) {
  try {
    await Notifications.cancelAllScheduledNotificationsAsync();
    for (const n of planned(state, now)) {
      await Notifications.scheduleNotificationAsync({
        content: { title: n.title, body: n.body, sound: state.settings.sound ? 'default' : false },
        trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: new Date(n.at) },
      });
    }
  } catch {
    // 沒權限或平台不支援：核心不靠通知，靜默
  }
}
