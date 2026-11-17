// 豆帳 通知：只有「到點」一種（這顆到點、休息到點），文案固定、不含那句（安全 P3）。
// 每次轉態「全部取消再排」，不做差量（藍圖危險方塊「通知排程」）。
// 該排什麼由純函式 planned() 算，殼只負責在狀態改變後叫 sync()。核心迴圈不靠通知：前景時 app 自己切鈴響頁。
import * as Notifications from 'expo-notifications';
import { PHASE, typeOf } from './machine';
import { words } from '../design/words';
import { MS_PER_MINUTE, params } from '../design/params';

// 前景收到通知：不跳橫幅、不進清單，只出聲（畫面那一刻已經是鈴響頁）
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: false,
    shouldShowList: false,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

/**
 * 現在這個狀態該排哪些通知。已經過了的時刻不排（鈴響頁等人回來時沒有通知可排）。
 * 開了「休息完自動開始」（AH8）：休息時連下一顆的到點一起排，下一顆在背景自己開始時才有人叫；
 * 休息完那則的內文改成下一顆自己開始了。
 */
export function planned(state, now) {
  const c = state.current;
  if (!c) return [];
  const list = [];
  if (c.phase === PHASE.focus) list.push({ title: words.rang, body: words.bellSub, at: c.endAt });
  if (c.phase === PHASE.rest && state.settings.restMode === 'auto' && c.endAt != null) {
    const auto = state.settings.autoNext;
    list.push({
      title: words.restDone,
      body: auto ? words.autoNextStarted : words.backFromRest,
      at: c.endAt,
    });
    if (auto) {
      const nextStart = c.endAt + params.autoNextDelayMs;
      const nextEnd = nextStart + typeOf(state, c.typeId).len * MS_PER_MINUTE;
      list.push({ title: words.rang, body: words.bellSub, at: nextEnd });
    }
  }
  return list.filter((n) => n.at > now);
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

/**
 * 通知權限三態：'granted' 允許、'denied' 被拒且系統不讓再問、'undetermined' 還沒問過。
 * 只有 denied 才顯示「沒開・打開」：還沒問過時，iOS 系統設定裡根本還沒有豆帳的通知那一列（G 審查員）。
 */
export async function notifStatus() {
  const p = await Notifications.getPermissionsAsync();
  if (p.granted) return 'granted';
  return p.canAskAgain ? 'undetermined' : 'denied';
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
