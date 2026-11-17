// 番茄帳 計時中長大的番茄（2026-11-17 AG2，比較頁 1A「從青到紅」）：這顆長到幾成、畫多大、什麼顏色。
// 純函式，只看 current 與時鐘；顏色從畫面層傳進來（Tokens），這裡只做混色。
import { PHASE } from './machine';
import { params } from '../design/params';

const clamp01 = (x) => Math.min(1, Math.max(0, x));

/** 這顆走了幾成（0–1）。再做一下的那段番茄已經熟了，維持 1，不倒回去變青。 */
export function growProgress(current, now) {
  if (!current || current.phase !== PHASE.focus) return 0;
  if (current.flowed) return 1;
  const span = current.endAt - current.startedAt;
  return span > 0 ? clamp01((now - current.startedAt) / span) : 1;
}

/** 畫多大：全熟大小的幾成。 */
export const growScale = (progress) =>
  params.grow.minScale + (1 - params.grow.minScale) * clamp01(progress);

const channels = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
function mix(from, to, t) {
  const a = channels(from);
  const b = channels(to);
  return `#${a
    .map((v, i) =>
      Math.round(v + (b[i] - v) * t)
        .toString(16)
        .padStart(2, '0'),
    )
    .join('')}`;
}

/** 什麼顏色：青 → 黃（到 turnAt）→ 這個標籤的番茄色。三個顏色都是 #RRGGBB。 */
export function ripeColor(progress, { unripe, turning, ripe }) {
  const p = clamp01(progress);
  const turn = params.grow.turnAt;
  return p < turn ? mix(unripe, turning, p / turn) : mix(turning, ripe, (p - turn) / (1 - turn));
}
