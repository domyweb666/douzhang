// 豆罐物理測試：只驗「不穿牆、落地會回報、雙豆連著、點一下會動」，手感本身要真機（閘門 3）。
import { Token } from '../design/Tokens';
import { addBody, count, makeWorld, seed, step, tapAt } from '../core/jarPhysics';
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

test('參數全部來自 Tokens：重力、半徑、豆數上限與參數表同值', () => {
  const P = jarParams(Token);
  expect(P.gravity).toBe(1100);
  expect(P.radius).toBe(18);
  expect(P.maxBeans).toBe(40);
  expect(P.link).toBe(32);
});

test('從罐口掉一顆，兩秒後落在罐底，而且落地那一幀有回報（給啵與觸覺用）', () => {
  const W = world();
  addBody(W, false, 150, -36, 0, -160, true);
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

test('撒 40 顆預跑安置後，沒有一顆在牆外', () => {
  const W = world();
  seed(W, 40, (i) => i % 4 === 3);
  expect(count(W)).toBe(40);
  for (const b of W.bodies) {
    expect(b.x).toBeGreaterThanOrEqual(18 - 0.01);
    expect(b.x).toBeLessThanOrEqual(300 - 18 + 0.01);
    expect(b.y).toBeLessThanOrEqual(400 - 18 + 0.01);
  }
});

test('雙豆兩粒靜置後間距接近連桿長度', () => {
  const W = world();
  addBody(W, true, 150, 100);
  run(W, 3);
  const L = W.links[0];
  expect(Math.hypot(L.b.x - L.a.x, L.b.y - L.a.y)).toBeCloseTo(32, 0);
});

test('超過豆數上限不再撒', () => {
  const W = world();
  seed(W, 100, () => false);
  expect(count(W)).toBe(40);
});

test('點一下罐底附近，落定的豆會被彈起來（往上的速度）', () => {
  const W = world();
  addBody(W, false, 150, 400 - 18);
  run(W, 1);
  tapAt(W, 150, 400 - 18);
  expect(W.bodies[0].vy).toBeLessThan(0);
});

test('遠離手指的豆不受影響', () => {
  const W = world();
  addBody(W, false, 30, 400 - 18);
  run(W, 1);
  const before = W.bodies[0].vy;
  tapAt(W, 280, 50);
  expect(W.bodies[0].vy).toBe(before);
});
