// 手機現在是直拿還是橫放（聚焦模式用，2026-11-17）。純函式，不碰感測器、不碰畫面。
// 只看重力落在哪一軸：不管哪一邊朝下，也不管單位（三軸先正規化），所以開著直向鎖定也判斷得出來。
// 平放在桌上（重力在 z 軸）兩個都不算，維持上一個姿勢。

export const POSE = { portrait: 'portrait', landscape: 'landscape' };

/** 一筆加速度 → 'portrait'｜'landscape'｜null（看不出來）。ratio：那一軸要佔重力的幾成才算。 */
export function poseOf({ x, y, z }, ratio) {
  const g = Math.sqrt(x * x + y * y + z * z);
  if (!(g > 0)) return null;
  if (Math.abs(x) / g >= ratio) return POSE.landscape;
  if (Math.abs(y) / g >= ratio) return POSE.portrait;
  return null;
}

/** 從直拿起算：按開始那一刻畫面是直的。之後第一次橫放就算「換了」。 */
export const startTracker = () => ({ pose: POSE.portrait, candidate: null, since: 0 });

/**
 * 吃一筆加速度，回 { tracker, changed }。changed 是這一筆剛確定換成的新姿勢，沒換是 null。
 * 新姿勢要連續維持 dwellMs 才算數：拿起手機晃一下、轉個角度看一眼都不算。
 */
export function track(tracker, sample, now, { ratio, dwellMs }) {
  const seen = poseOf(sample, ratio);
  if (!seen || seen === tracker.pose) {
    return {
      tracker: tracker.candidate ? { ...tracker, candidate: null } : tracker,
      changed: null,
    };
  }
  if (seen !== tracker.candidate) {
    return { tracker: { ...tracker, candidate: seen, since: now }, changed: null };
  }
  if (now - tracker.since < dwellMs) return { tracker, changed: null };
  return { tracker: { pose: seen, candidate: null, since: now }, changed: seen };
}
