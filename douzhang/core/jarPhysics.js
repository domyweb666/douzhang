// 豆罐物理：只算，不畫、不碰資料。從灰盒子 app/Jar.js（候選 1：JS 迴圈）搬來的 makeWorld／addBody／step。
// 所有數字由呼叫端從 design/Tokens.js 的 motion.jarPhysics、motion.beanDrop、shape.beanRadius 餵進來（P），這裡不寫死。
// 輸入只有三種：加一顆（帶自己的半徑）、重力向量（傾斜）、點一下；輸出是每顆的位置與「這一幀落地了哪幾顆、最大撞擊速度」。
// 2026-11-02 V4：番茄大小跟分鐘走，每顆自己一個半徑 r；雙豆（兩粒連桿）拿掉，一顆就是一顆。
// 2026-11-16：每顆多一個角度 angle（弧度，順時針為正）與轉速 spin，給會滾的番茄畫用；算法在 roll()。

export function makeWorld(P) {
  return {
    P,
    bodies: [],
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

/** 這顆多長（分鐘）→ 半徑：面積跟分鐘成正比，所以半徑跟√分鐘走，夾在 sizeMin–sizeMax 倍。 */
export function radiusFor(P, minutes) {
  const k = Math.sqrt(minutes / P.sizeRefMinutes);
  return P.radius * Math.min(P.sizeMax, Math.max(P.sizeMin, k));
}

/** 加一顆，半徑 r。fresh＝從罐口掉進來的，落地那一幀要回報（啵＋觸覺）；落地＝第一次碰到罐底，或撞到下面已經落定的番茄。angle＝一開始歪多少。 */
export function addBody(W, r, x, y, vx = 0, vy = 0, fresh = false, angle = 0) {
  W.bodies.push({
    x,
    y,
    px: x,
    py: y,
    ex: 0,
    ey: 0,
    vx,
    vy,
    r,
    fresh,
    angle,
    spin: 0,
    id: newId(),
  });
}

/** 一開始歪多少：正負 lean 之間隨機。 */
export const randomLean = (P) => (Math.random() * 2 - 1) * P.spin.lean;

export const count = (W) => W.bodies.length;

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

/**
 * 還在掉的那顆撞到下面已經落定的番茄，也算落地（2026-11-15）。
 * 原本只認罐底：第一排滿了之後新的一顆都落在別顆上面，啵與觸覺就不見了。
 * 兩顆都還在掉的互撞不算；落定的那顆要在下面（點一下彈上來撞到的不算）。
 */
function landOnPile(W, a, b) {
  if (a.fresh === b.fresh) return;
  const [falling, resting] = a.fresh ? [a, b] : [b, a];
  if (resting.y <= falling.y) return;
  falling.fresh = false;
  W.landed.push(falling);
}

function solveBeanPairs(W) {
  const { beanRest } = W.P;
  const B = W.bodies;
  for (let i = 0; i < B.length; i++)
    for (let j = i + 1; j < B.length; j++) {
      const a = B[i];
      const b = B[j];
      const m = a.r + b.r;
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
      landOnPile(W, a, b);
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
  const { wallFric } = W.P;
  const { w, h } = W;
  for (const b of W.bodies) {
    const R = b.r;
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

/**
 * 轉動（2026-11-16）：只算每顆的角度，不回頭動位置與速度，所以原本怎麼掉、怎麼堆都不變。
 * 用「這一步實際移動了多少」算，不用 vx／vy：躺好的番茄速度每步都在抖（重力加上去、碰撞再彈回來），位置才是真的沒動。
 * 實際移動還要再平滑過（ex、ey）：擠在堆裡的番茄會原地來回抖不到一個點，不濾掉的話位置沒動、臉卻慢慢轉走（電腦上量，靜置 10 秒最多轉走二十幾度）。
 * 貼著罐底或牆的往「滾動不打滑」靠；兩顆貼在一起的互相帶（像齒輪）；半空中的照原本的轉速慢慢停。
 */
function roll(W, dt) {
  const { grip, air, touch, still, sleep, smooth } = W.P.spin;
  const B = W.bodies;
  const moved = (v) => (Math.abs(v) > still ? v : 0);
  const toward = (b, surface) => {
    b.spin += (moved(surface) / b.r - b.spin) * grip;
  };
  for (const b of B) {
    b.ex += ((b.x - b.px) / dt - b.ex) * smooth;
    b.ey += ((b.y - b.py) / dt - b.ey) * smooth;
    if (b.y >= W.h - b.r - touch) toward(b, b.ex);
    if (b.x <= b.r + touch) toward(b, b.ey);
    if (b.x >= W.w - b.r - touch) toward(b, -b.ey);
  }
  for (let i = 0; i < B.length; i++)
    for (let j = i + 1; j < B.length; j++) {
      const a = B[i];
      const b = B[j];
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const d = Math.hypot(dx, dy);
      if (d > a.r + b.r + touch || d <= 1e-2) continue;
      // 沿著接觸面，兩顆實際的相對移動；扣掉各自轉動帶的，剩下的是接觸點互搓多少，兩顆各分一半
      const along = ((b.ex - a.ex) * -dy + (b.ey - a.ey) * dx) / d;
      const rub = ((moved(along) - a.spin * a.r - b.spin * b.r) * grip) / 2;
      a.spin += rub / a.r;
      b.spin += rub / b.r;
    }
  for (const b of B) {
    b.spin *= air;
    if (Math.abs(b.spin) < sleep) b.spin = 0;
    b.angle += b.spin * dt;
  }
}

/** 走一步 dt 秒。呼叫端每幀先把 W.impact 歸零、把 W.landed 清空，再分子步呼叫。 */
export function step(W, dt) {
  for (const b of W.bodies) {
    b.px = b.x;
    b.py = b.y;
  }
  integrate(W, dt);
  for (let it = 0; it < W.P.iterations; it++) {
    solveBeanPairs(W);
    solveWalls(W);
  }
  roll(W, dt);
}

/** 開機安置：照 radii（每顆的半徑）隨機撒，靜置重力預跑 settleSteps 步，進畫面時番茄已經落定（參數表 B）。 */
export function seed(W, radii) {
  const { settleSteps, maxBeans, gravity } = W.P;
  W.bodies = [];
  W.landed = [];
  if (!W.w || !W.h) return;
  for (const r of radii.slice(0, maxBeans)) {
    const x = r + Math.random() * Math.max(0, W.w - 2 * r);
    const y = r + Math.random() * Math.max(0, W.h - 2 * r);
    addBody(W, r, x, y);
  }
  const g = [W.gx, W.gy];
  W.gx = 0;
  W.gy = gravity;
  for (let i = 0; i < settleSteps; i++) step(W, 1 / 60);
  W.gx = g[0];
  W.gy = g[1];
  W.landed = [];
  // 預跑時是從亂撒的位置互相擠開，轉出來的角度沒有意義：安置好之後每顆重新給一個小歪度、不帶轉速
  for (const b of W.bodies) {
    b.angle = randomLean(W.P);
    b.spin = 0;
  }
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
