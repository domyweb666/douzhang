// 豆罐物理：只算，不畫、不碰資料。從灰盒子 app/Jar.js（候選 1：JS 迴圈）搬來的 makeWorld／addBody／step。
// 所有數字由呼叫端從 design/Tokens.js 的 motion.jarPhysics、motion.beanDrop、shape.beanRadius 餵進來（P），這裡不寫死。
// 輸入只有三種：加一顆（單或雙）、重力向量（傾斜）、點一下；輸出是每顆的位置與「這一幀落地了哪幾顆、最大撞擊速度」。

export function makeWorld(P) {
  return {
    P,
    bodies: [],
    links: [],
    w: 0,
    h: 0,
    gx: 0,
    gy: P.gravity,
    tgx: 0,
    tgy: P.gravity,
    impact: 0,
    landed: [],
  };
}

let nextId = 0;
const newId = () => ++nextId;

/** 加一顆。two＝雙豆（50 分那顆，兩粒連桿）。fresh＝從罐口掉進來的，落地那一幀要回報（啵＋觸覺）。 */
export function addBody(W, two, x, y, vx = 0, vy = 0, fresh = false) {
  const L = W.P.link;
  if (!two) {
    W.bodies.push({ x, y, vx, vy, single: true, fresh, id: newId() });
    return;
  }
  const a = { x: x - L / 2, y, vx, vy, fresh, id: newId() };
  const b = { x: x + L / 2, y, vx, vy, id: newId() };
  a.mate = b;
  b.mate = a;
  W.bodies.push(a, b);
  W.links.push({ a, b, id: newId() });
}

/** 顆數：單豆＋雙豆各算一顆。 */
export const count = (W) => W.bodies.filter((b) => b.single).length + W.links.length;

function integrate(W, dt) {
  const { P, gx, gy } = W;
  for (const b of W.bodies) {
    b.vx += gx * dt;
    b.vy += gy * dt;
    b.vx *= P.airDamp;
    b.vy *= P.airDamp;
    b.x += b.vx * dt;
    b.y += b.vy * dt;
  }
}

/** 雙豆連桿：拉回固定間距，速度混合讓兩粒一起動。 */
function solveLinks(W) {
  const { link } = W.P;
  for (const L of W.links) {
    const dx = L.b.x - L.a.x;
    const dy = L.b.y - L.a.y;
    const d = Math.hypot(dx, dy) || 1;
    const k = (d - link) / d / 2;
    L.a.x += dx * k;
    L.a.y += dy * k;
    L.b.x -= dx * k;
    L.b.y -= dy * k;
    const mvx = (L.a.vx + L.b.vx) / 2;
    const mvy = (L.a.vy + L.b.vy) / 2;
    L.a.vx += (mvx - L.a.vx) * W.P.linkMix;
    L.b.vx += (mvx - L.b.vx) * W.P.linkMix;
    L.a.vy += (mvy - L.a.vy) * W.P.linkMix;
    L.b.vy += (mvy - L.b.vy) * W.P.linkMix;
  }
}

function solveBeanPairs(W) {
  const { radius, beanRest } = W.P;
  const B = W.bodies;
  const m = 2 * radius;
  for (let i = 0; i < B.length; i++)
    for (let j = i + 1; j < B.length; j++) {
      const a = B[i];
      const b = B[j];
      if (a.mate === b) continue;
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const d2 = dx * dx + dy * dy;
      if (d2 >= m * m || d2 <= 1e-4) continue;
      const d = Math.sqrt(d2);
      const nx = dx / d;
      const ny = dy / d;
      const o = (m - d) / 2;
      a.x -= nx * o;
      a.y -= ny * o;
      b.x += nx * o;
      b.y += ny * o;
      const rv = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
      if (rv >= 0) continue;
      const jj = (-beanRest * rv) / 2;
      a.vx -= jj * nx;
      a.vy -= jj * ny;
      b.vx += jj * nx;
      b.vy += jj * ny;
      if (-rv > W.impact) W.impact = -rv;
    }
}

/** 撞牆：壓回牆內、反彈保留 wallRest、沿牆滑時切向乘 wallFric；回報最大撞擊速度。 */
function bounce(W, b, axis, limit, sign) {
  const v = b[axis === 'x' ? 'vx' : 'vy'] * sign;
  b[axis] = limit;
  if (v > 0) {
    if (v > W.impact) W.impact = v;
    b[axis === 'x' ? 'vx' : 'vy'] = -v * sign * W.P.wallRest;
    return true;
  }
  return false;
}

function solveWalls(W) {
  const { radius: R, wallFric } = W.P;
  const { w, h } = W;
  for (const b of W.bodies) {
    if (b.x < R) {
      bounce(W, b, 'x', R, -1);
      b.vy *= wallFric;
    }
    if (b.x > w - R) {
      bounce(W, b, 'x', w - R, 1);
      b.vy *= wallFric;
    }
    if (b.y > h - R) {
      // 落地那一幀：從罐口掉進來的要回報（啵＋觸覺在這一幀，不是按鈕那一幀）
      if (bounce(W, b, 'y', h - R, 1) && b.fresh) {
        b.fresh = false;
        W.landed.push(b);
      }
      b.vx *= wallFric;
    }
    // 罐口：還在掉進來的（fresh）可以在罐口上方，落定的不准飛出去
    if (b.y < R && !b.fresh) bounce(W, b, 'y', R, -1);
  }
}

/** 走一步 dt 秒。呼叫端每幀先把 W.impact 歸零、把 W.landed 清空，再分子步呼叫。 */
export function step(W, dt) {
  integrate(W, dt);
  for (let it = 0; it < W.P.iterations; it++) {
    solveLinks(W);
    solveBeanPairs(W);
    solveWalls(W);
  }
}

/** 開機安置：隨機撒 n 顆，靜置重力預跑 settleSteps 步，進畫面時豆子已經落定（參數表 B）。 */
export function seed(W, n, isDouble) {
  const { radius: R, link, settleSteps, maxBeans, gravity } = W.P;
  W.bodies = [];
  W.links = [];
  W.landed = [];
  if (!W.w || !W.h) return;
  for (let i = 0; i < Math.min(n, maxBeans); i++) {
    const x = R + link / 2 + Math.random() * (W.w - 2 * R - link);
    const y = R + Math.random() * (W.h - 2 * R);
    addBody(W, isDouble(i), x, y);
  }
  const g = [W.gx, W.gy];
  W.gx = 0;
  W.gy = gravity;
  for (let i = 0; i < settleSteps; i++) step(W, 1 / 60);
  W.gx = g[0];
  W.gy = g[1];
  W.landed = [];
}

/** 點一下：影響半徑內的豆往上彈、往離開手指的方向推（參數表 B「點一下彈」）。 */
export function tapAt(W, x, y) {
  const { tapRadius, tapUp, tapSide } = W.P;
  for (const b of W.bodies) {
    const d = Math.hypot(b.x - x, b.y - y);
    if (d >= tapRadius) continue;
    const k = 1 - d / tapRadius;
    b.vy -= tapUp * k;
    b.vx += (b.x - x) * tapSide * k;
  }
}
