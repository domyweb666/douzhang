// 番茄帳 計時中擋住其他 app（AF1）：包原生模組 AppShield（modules/app-shield，螢幕使用時間 API）。
// 什麼時候該擋由純函式 shouldShield() 算，殼只負責在答案變了的時候叫 applyShield()。
// Expo Go、Android、測試裡沒有這個模組：shieldAvailable 是 false，其他函式什麼都不做。
// 擋不擋得成都不能卡住計時，所以原生呼叫失敗一律吞掉。
import { requireOptionalNativeModule } from 'expo';
import { PHASE, phaseOf } from './machine';
import { words } from '../design/words';

const native = requireOptionalNativeModule('AppShield');

export const shieldAvailable = !!native;

/** 現在該不該擋：開關開著、而且這顆還在跑。鈴響、休息、待機都不擋。 */
export function shouldShield(state, now) {
  return !!state.settings.shield && phaseOf(state, now) === PHASE.focus;
}

/** 蓋上或解開。沒授權、沒選 app 時系統自己不會擋。 */
export function applyShield(on) {
  if (!native) return;
  try {
    if (on) native.block();
    else native.unblock();
  } catch {
    // 擋不成照樣計時
  }
}

/** 要螢幕使用時間的授權。已經允許過不會再跳框；不允許、沒有模組都回 false。 */
export async function authorizeShield() {
  if (!native) return false;
  try {
    return await native.authorize();
  } catch {
    return false;
  }
}

// 選了幾項。設定頁每一拍都重畫，不每次都去問原生：開機問一次，選完、清空時更新
let picked = 0;
try {
  picked = native ? native.count() : 0;
} catch {
  picked = 0;
}

export const shieldCount = () => picked;

/** 開系統的選擇畫面，關掉後更新選了幾項。 */
export async function pickShieldApps() {
  if (!native) return;
  try {
    picked = await native.pick(words.cancel, words.shieldPickDone);
  } catch {
    // 選擇畫面開不起來：原本選的不動
  }
}

/** 清空所有資料時用：解開，選過的也忘掉（安全標準 P5）。 */
export function forgetShield() {
  if (!native) return;
  try {
    native.forget();
    picked = 0;
  } catch {
    // 忘不掉也不擋清空
  }
}
