// 計時中長大的番茄（AG2）測試：走了幾成、畫多大、什麼顏色。
import { blank } from '../core/store';
import { flow, keep, start } from '../core/machine';
import { growProgress, growScale, ripeColor } from '../core/grow';
import { params } from '../design/params';
import { CharacterColors } from '../design/Tokens';

const MIN = 60 * 1000;
const T0 = new Date(2026, 10, 17, 9, 0, 0).getTime();
const INK = CharacterColors.tomato;
const COLORS = { unripe: INK.unripe, ripe: INK.body.red };

describe('走了幾成', () => {
  test('剛開始是 0，一半是 0.5，到點是 1，過了也不超過 1', () => {
    const c = start(blank(), T0).current;
    expect(growProgress(c, T0)).toBe(0);
    expect(growProgress(c, T0 + 12.5 * MIN)).toBe(0.5);
    expect(growProgress(c, T0 + 25 * MIN)).toBe(1);
    expect(growProgress(c, T0 + 40 * MIN)).toBe(1);
  });

  test('再做一下的那段維持全熟，不倒回去變青', () => {
    const rang = T0 + 25 * MIN;
    const more = flow(start(blank(), T0), rang + MIN, 15).current;
    expect(growProgress(more, rang + 2 * MIN)).toBe(1);
  });

  test('沒在計時（待機、休息）是 0', () => {
    expect(growProgress(null, T0)).toBe(0);
    const rest = keep(start(blank(), T0), T0 + 25 * MIN, '').current;
    expect(growProgress(rest, T0 + 26 * MIN)).toBe(0);
  });
});

describe('大小與顏色', () => {
  test('一開始是全熟的 minScale 成，到點是全熟大小，一路只變大', () => {
    expect(growScale(0)).toBe(params.grow.minScale);
    expect(growScale(1)).toBe(1);
    expect(growScale(0.5)).toBeGreaterThan(growScale(0.25));
    expect(growScale(2)).toBe(1);
  });

  test('顏色：開始是青的，到點是標籤的番茄色，中間不經過黃（AH1）', () => {
    expect(ripeColor(0, COLORS)).toBe(INK.unripe.toLowerCase());
    expect(ripeColor(1, COLORS)).toBe(INK.body.red.toLowerCase());
    const purple = { unripe: INK.unripe, ripe: INK.body.purple };
    // 一半的時候是青與紫各一半，不是黃
    const [r, g, b] = [1, 3, 5].map((i) => parseInt(ripeColor(0.5, purple).slice(i, i + 2), 16));
    const mid = (k) =>
      Math.round(
        (parseInt(INK.unripe.slice(k, k + 2), 16) + parseInt(INK.body.purple.slice(k, k + 2), 16)) /
          2,
      );
    expect([r, g, b].map((v, i) => Math.abs(v - mid([1, 3, 5][i])) <= 1)).toEqual([
      true,
      true,
      true,
    ]);
  });

  test('中間的顏色都是合法的 #rrggbb', () => {
    for (let p = 0; p <= 1; p += 0.05) expect(ripeColor(p, COLORS)).toMatch(/^#[0-9a-f]{6}$/);
  });
});
