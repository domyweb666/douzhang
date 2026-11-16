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

// 2026-11-16 番茄換成會滾的那顆：角度只給畫用，這裡驗「滾多遠轉多少、躺好不會自己轉、不影響位置」。
test('罐底往右滾的那顆順時針轉，轉過的弧長跟滾過的距離差不多', () => {
  const W = world();
  W.w = 2000;
  addBody(W, 28, 100, 400 - 28, 300, 0);
  run(W, 5);
  const b = W.bodies[0];
  const travelled = b.x - 100;
  expect(travelled).toBeGreaterThan(30);
  expect(b.angle * 28).toBeGreaterThan(travelled * 0.8);
  expect(b.angle * 28).toBeLessThan(travelled * 1.2);
  expect(b.spin).toBe(0); // 停下來之後轉速歸零，不會留一點點慢慢轉
});

test('排滿的一排上面再躺一顆，放著不管：每顆的角度都不再變', () => {
  const W = world();
  for (let i = 0; i < 5; i++) addBody(W, 28, 30 + i * 60, 400 - 28, 0, 0, false, i / 10);
  addBody(W, 28, 150, 400 - 28 - 50, 0, 0, false, 0.4);
  run(W, 4); // 上面那顆先滾進兩顆中間，等它停
  const before = W.bodies.map((b) => b.angle);
  run(W, 5);
  W.bodies.forEach((b, i) => {
    expect(b.spin).toBe(0);
    expect(b.angle).toBe(before[i]);
  });
});

test('開機安置的每一顆只歪一點（不超過 lean），不帶轉速', () => {
  const W = world();
  seed(W, Array(20).fill(28));
  for (const b of W.bodies) {
    expect(Math.abs(b.angle)).toBeLessThanOrEqual(W.P.spin.lean);
    expect(b.spin).toBe(0);
  }
});

test('轉動只算角度：同樣的開局，轉速亂給一通，位置與速度一步都不差', () => {
  const start = (W) => {
    for (let i = 0; i < 5; i++) addBody(W, 28, 30 + i * 60, 400 - 28);
    addBody(W, 28, 140, -56, 20, -160, true);
  };
  const A = world();
  const B = world();
  start(A);
  start(B);
  B.bodies.forEach((b, i) => {
    b.spin = (i + 1) * 3;
    b.angle = i;
  });
  run(A, 4);
  run(B, 4);
  A.bodies.forEach((a, i) => {
    const b = B.bodies[i];
    expect([b.x, b.y, b.vx, b.vy]).toEqual([a.x, a.y, a.vx, a.vy]);
  });
});

test('掉在排滿的第一排上面：滾進兩顆中間的那顆有轉到，最後停住', () => {
  const W = world();
  for (let i = 0; i < 5; i++) addBody(W, 28, 30 + i * 60, 400 - 28);
  run(W, 1);
  addBody(W, 28, 140, -56, 20, -160, true);
  run(W, 6);
  const fresh = W.bodies[5];
  expect(Math.abs(fresh.angle)).toBeGreaterThan(0.2);
  expect(fresh.spin).toBe(0);
});

test('貼著牆往下掉的那顆不會被牆搓著轉；整排一起落地也幾乎不轉', () => {
  const W = world();
  for (let i = 0; i < 5; i++) addBody(W, 30, 30 + i * 60, 100); // 寬 300 剛好排滿，左右兩顆貼牆
  run(W, 4);
  for (const b of W.bodies) {
    expect(b.y).toBeGreaterThan(400 - 30 - 1);
    expect(Math.abs(b.angle)).toBeLessThan(0.1);
  }
});
