// 火柴人姿勢測試：只驗「播完一定站好、該舉手時手有舉、該離地時有離地」，好不好看要在手機上看。
import { CHEER_JUMP_SECONDS, REST, RIG, blend, oneShot, skeleton } from '../core/poses';
import { Token } from '../design/Tokens';
import { MS_PER_SECOND } from '../design/params';

const M = Token.motion.mascot;
const sec = (ms) => ms / MS_PER_SECOND;
const BLEND = sec(M.blendMs);
const feetY = (pose) => skeleton(pose).legs.map((leg) => leg[2][1]);
const handsY = (pose) => skeleton(pose).arms.map((arm) => arm[2][1]);

test('還沒開始與播完之後都是站姿（畫面停下來時一定站好）', () => {
  for (const [name, ms] of [
    ['cheer', M.cheerMs],
    ['bow', M.bowMs],
    ['wave', M.waveMs],
  ]) {
    expect(oneShot(name, 0, sec(ms), BLEND)).toBe(REST);
    expect(oneShot(name, sec(ms) + BLEND, sec(ms), BLEND)).toBe(REST);
    expect(oneShot(name, 99, sec(ms), BLEND)).toBe(REST);
  }
});

test('站姿：兩腳踩在地上、頭在脖子上不歪', () => {
  const s = skeleton(REST);
  feetY(REST).forEach((y) => expect(y).toBeCloseTo(RIG.ground, 0));
  expect(s.lift).toBe(0);
  expect(s.head).toEqual({ x: RIG.hipX, y: RIG.hipY - RIG.torso, rotate: 0, scaleY: 1 });
});

test('慶祝：總長是一跳的整數倍；跳到一半時兩手高過頭、兩腳離地、嘴張開', () => {
  const total = sec(M.cheerMs);
  expect((total / CHEER_JUMP_SECONDS) % 1).toBeCloseTo(0);
  const mid = oneShot('cheer', CHEER_JUMP_SECONDS * 1.4, total, BLEND); // 第二跳的最高點附近
  const s = skeleton(mid);
  handsY(mid).forEach((y) => expect(y).toBeLessThan(s.head.y));
  feetY(mid).forEach((y) => expect(y).toBeLessThan(RIG.ground - 10));
  expect(s.lift).toBeGreaterThan(0.5);
  expect(mid.mouth).toBe('open');
  expect(mid.happy).toBe(1);
});

test('慶祝：動作跑完那一刻腳已經回到地上，之後只剩手放下來', () => {
  const total = sec(M.cheerMs);
  const end = oneShot('cheer', total + BLEND / 2, total, BLEND);
  expect(end.ry).toBeCloseTo(0);
  expect(skeleton(end).lift).toBeCloseTo(0);
});

test('鞠躬：彎到底時身體變短、頭往下、眼睛閉起來；腳不離地', () => {
  const total = sec(M.bowMs);
  const low = oneShot('bow', 1, total, BLEND);
  expect(low.tl).toBeCloseTo(0.7);
  expect(low.eyeH).toBeLessThan(2);
  expect(skeleton(low).head.y).toBeGreaterThan(skeleton(REST).head.y);
  feetY(low).forEach((y) => expect(y).toBeCloseTo(RIG.ground, 0));
});

test('揮手：右手舉過肩膀，左手放著', () => {
  const total = sec(M.waveMs);
  const mid = oneShot('wave', total / 2, total, BLEND);
  const [left, right] = skeleton(mid).arms;
  expect(right[2][1]).toBeLessThan(right[0][1]); // 右手比右肩高
  expect(left[2][1]).toBeGreaterThan(left[0][1]); // 左手在左肩下面
});

test('blend：數字照比例，嘴型過半才換', () => {
  const open = { ...REST, ry: -40, mouth: 'open' };
  expect(blend(REST, open, 0.25).ry).toBeCloseTo(-10);
  expect(blend(REST, open, 0.25).mouth).toBe('smile');
  expect(blend(REST, open, 0.75).mouth).toBe('open');
});
