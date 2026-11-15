// 罐子物理測試：只驗「不穿牆、落地會回報、大小跟分鐘走、點一下會動」，手感本身要真機（閘門 3）。
import { Token } from '../design/Tokens';
import { addBody, count, makeWorld, radiusFor, seed, step, tapAt } from '../core/jarPhysics';
import { jarParams } from '../design/params';

const world = () => {
  const W = makeWorld(jarParams(Token));
  W.w = 300;
  W.h = 400;
  return W;
};
const run = (W, seconds) => {
  for (let i = 0; i < seconds * 60; i++) {
    W.impact = 0;
    W.landed = [];
    step(W, 1 / 60);
  }
};

test('參數從 Tokens 與 params 合成：重力、基準半徑、顆數上限與參數表同值', () => {
  const P = jarParams(Token);
  expect(P.gravity).toBe(1100);
  expect(P.radius).toBe(28); // 直徑 56（W2）
  expect(P.maxBeans).toBe(40);
});

test('番茄大小：25 分是基準，面積跟分鐘成正比（100 分會是兩倍寬），太小太大夾住', () => {
  const P = jarParams(Token);
  const R = P.radius;
  expect(radiusFor(P, 25)).toBeCloseTo(R);
  expect(radiusFor(P, 60)).toBeCloseTo(R * Math.sqrt(60 / 25));
  expect(radiusFor(P, 60)).toBeGreaterThan(radiusFor(P, 15));
  expect(radiusFor(P, 5)).toBeCloseTo(R * 0.7); // 5 分與測試顆都不會小到看不見
  expect(radiusFor(P, 90)).toBeCloseTo(R * 1.75); // 90 分不會撐爆罐子
});

test('從罐口掉一顆，兩秒後落在罐底，而且落地那一幀有回報（給啵與觸覺用）', () => {
  const W = world();
  addBody(W, 18, 150, -36, 0, -160, true);
  let landedAt = -1;
  for (let i = 0; i < 120; i++) {
    W.impact = 0;
    W.landed = [];
    step(W, 1 / 60);
    if (W.landed.length && landedAt < 0) landedAt = i;
  }
  const b = W.bodies[0];
  expect(landedAt).toBeGreaterThan(0);
  expect(b.y).toBeLessThanOrEqual(400 - 18 + 0.01);
  expect(b.fresh).toBe(false);
});

test('大小不一的 40 顆預跑安置後，沒有一顆在牆外（各用自己的半徑算）', () => {
  const W = world();
  seed(
    W,
    Array.from({ length: 40 }, (_, i) => (i % 3 === 0 ? 31 : 13)),
  );
  expect(count(W)).toBe(40);
  for (const b of W.bodies) {
    expect(b.x).toBeGreaterThanOrEqual(b.r - 0.01);
    expect(b.x).toBeLessThanOrEqual(300 - b.r + 0.01);
    expect(b.y).toBeLessThanOrEqual(400 - b.r + 0.01);
    expect(b.y).toBeGreaterThanOrEqual(b.r - 0.01);
  }
});

test('一大一小靜置後不會疊在一起：中心距離至少兩個半徑相加', () => {
  const W = world();
  addBody(W, 30, 150, 300);
  addBody(W, 12, 152, 200);
  run(W, 3);
  const [a, b] = W.bodies;
  expect(Math.hypot(b.x - a.x, b.y - a.y)).toBeGreaterThanOrEqual(30 + 12 - 1);
});

test('超過顆數上限不再撒', () => {
  const W = world();
  seed(W, Array(100).fill(18));
  expect(count(W)).toBe(40);
});

test('點一下罐底附近，落定的豆會被彈起來（往上的速度）', () => {
  const W = world();
  addBody(W, 18, 150, 400 - 18);
  run(W, 1);
  tapAt(W, 150, 400 - 18);
  expect(W.bodies[0].vy).toBeLessThan(0);
});

test('遠離手指的豆不受影響', () => {
  const W = world();
  addBody(W, 18, 30, 400 - 18);
  run(W, 1);
  const before = W.bodies[0].vy;
  tapAt(W, 280, 50);
  expect(W.bodies[0].vy).toBe(before);
});

/** 每幀照畫面那樣清空再走一步，回傳每次回報落地的 { 第幾幀, 那顆 }。 */
const landings = (W, frames) => {
  const seen = [];
  for (let i = 0; i < frames; i++) {
    W.impact = 0;
    W.landed = [];
    step(W, 1 / 60);
    for (const b of W.landed) seen.push({ frame: i, body: b, y: b.y });
  }
  return seen;
};

test('罐底第一排滿了，新的一顆落在別顆上面：撞到那一幀就回報落地，而且只回報一次', () => {
  const W = world();
  for (let i = 0; i < 5; i++) addBody(W, 28, 30 + i * 60, 400 - 28); // 寬 300 的罐底排滿五顆
  run(W, 1);
  addBody(W, 28, 150, -56, 0, -160, true);
  const seen = landings(W, 240);
  expect(seen).toHaveLength(1);
  expect(seen[0].body).toBe(W.bodies[5]);
  expect(seen[0].y).toBeLessThan(400 - 28 - 28); // 回報時還在第一排上面，不是等它碰到罐底
  expect(W.bodies[5].fresh).toBe(false);
});

test('兩顆都還在掉、半空中互撞不算落地：要等其中一顆碰到罐底', () => {
  const W = world();
  addBody(W, 18, 150, 100, 0, 0, true);
  addBody(W, 18, 150, 40, 0, 600, true); // 上面那顆比較快，半空中追撞下面那顆
  const seen = landings(W, 240);
  expect(seen.length).toBeGreaterThan(0);
  expect(seen[0].y).toBeGreaterThan(400 - 18 - 1); // 第一次回報就是碰到罐底那顆
});
