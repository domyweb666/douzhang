// 番茄火柴人的姿勢（純計算，不碰畫面）。搬自多米 2026-11-15 給的「茄子火柴人動作庫」：
// 身體是八個關節角度，一個動作就是角度隨時間變化的一組數值。豆帳只用三個：慶祝、鞠躬、揮手（Y1 定案，其餘不搬）。
// 角度：0° 垂直向下，正值往畫面右邊轉；手肘與膝蓋是相對上一節的角度。
// 這個檔的數字是動作與骨架本身（等於一張會動的圖），跟動作庫同值，不進 params；秒數由呼叫端從 Tokens.motion.mascot 給。

/** 骨架尺寸，單位是畫布座標（ui/Mascot.js 的 viewBox 同一套）。 */
export const RIG = {
  hipX: 160,
  hipY: 260,
  ground: 380,
  thigh: 62,
  shin: 62,
  torso: 78,
  shoulderDrop: 12,
  shoulderHalf: 6,
  upper: 44,
  fore: 44,
  foot: 12,
};

/** 站姿：手叉腰、微笑。沒在播動作時就畫這個。 */
export const REST = Object.freeze({
  ry: 0, // 整個人往上跳多少（負的是往上）
  lean: 0, // 身體傾斜
  head: 0, // 頭多轉幾度
  hy: 0, // 頭上下
  sh: 0, // 肩膀上下
  lS: -38, // 左肩
  lE: 143, // 左肘
  rS: 38,
  rE: -143,
  lH: -14, // 左髖
  lK: 0, // 左膝
  rH: 14,
  rK: 0,
  eyeH: 12, // 眼睛高度（鞠躬時閉起來）
  lookY: 0, // 視線上下
  brow: 2, // 眉毛角度
  browY: 0,
  squash: 0, // 落地那一下壓扁多少
  tl: 1, // 身體長度比例（鞠躬時往前彎，看起來變短）
  hs: 1, // 頭的高度比例
  happy: 0, // 1＝笑到眼睛彎起來
  mouth: 'smile', // 'smile'｜'open'
});

/** 平滑的 0→1：x 在 a 以前是 0、b 以後是 1。 */
function smooth(a, b, x) {
  const k = Math.max(0, Math.min(1, (x - a) / (b - a)));
  return k * k * (3 - 2 * k);
}

/** 慶祝一跳多久（秒）。播的總長要是它的整數倍，才會停在地上。 */
export const CHEER_JUMP_SECONDS = 0.72;

const ACTIONS = {
  // 慶祝：雙手舉高跳起來，前八成在空中、後兩成落地壓一下
  cheer(t) {
    const p = (t % CHEER_JUMP_SECONDS) / CHEER_JUMP_SECONDS;
    const air = p < 0.8 ? Math.sin((Math.PI * p) / 0.8) : 0;
    const land = p >= 0.8 ? Math.sin((Math.PI * (p - 0.8)) / 0.2) : 0;
    const shake = Math.sin(t * 15);
    return {
      ry: -34 * air,
      squash: 0.07 * land,
      lS: -105,
      lE: -62 - 8 * shake,
      rS: 105,
      rE: 62 + 8 * shake,
      lH: -14 - 12 * air,
      lK: 34 * air,
      rH: 14 + 12 * air,
      rK: -34 * air,
      brow: -4,
      browY: -3,
      happy: 1,
      mouth: 'open',
      head: 0.9 * shake,
    };
  },
  // 鞠躬：手放下、身體往前彎、閉眼，約 0.45 秒彎到底，1.5 秒起開始回正，2 秒站直
  bow(t) {
    const u = smooth(0, 0.45, t) * (1 - smooth(1.5, 2.0, t));
    return {
      lS: -12,
      lE: -4,
      rS: 12,
      rE: 4,
      tl: 1 - 0.3 * u,
      hs: 1 - 0.14 * u,
      hy: 8 * u,
      lookY: 6 * u,
      eyeH: 12 - 10.5 * smooth(0.4, 0.8, u),
      browY: 2 * u,
    };
  },
  // 揮手：右手舉起來左右擺，頭跟著點
  wave(t) {
    return {
      rS: 110,
      rE: 40 + 22 * Math.sin(t * 9),
      lS: -16,
      lE: -6,
      head: 5 + 2 * Math.sin(t * 4.5),
      lean: 2,
      brow: 5,
      browY: -1,
      hy: -1 * Math.sin(t * 4.5),
    };
  },
};

/** 兩個姿勢之間取中間值：數字照比例，文字（嘴型）過半才換。 */
export function blend(from, to, k) {
  const out = {};
  for (const key of Object.keys(to)) {
    const a = from[key];
    const b = to[key];
    out[key] = typeof b === 'number' ? a + (b - a) * k : k < 0.5 ? a : b;
  }
  return out;
}

/**
 * 播一次：從站姿帶進動作，動作跑 seconds 秒，再用 blendSeconds 秒帶回站姿。
 * t 是開始播之後過了幾秒；還沒開始或已經播完都回站姿（所以畫面停下來時一定是站好的）。
 */
export function oneShot(name, t, seconds, blendSeconds) {
  if (t <= 0 || t >= seconds + blendSeconds) return REST;
  const pose = { ...REST, ...ACTIONS[name](Math.min(t, seconds)) };
  const k = Math.min(smooth(0, blendSeconds, t), 1 - smooth(seconds, seconds + blendSeconds, t));
  return blend(REST, pose, k);
}

const dir = (deg) => {
  const r = (deg * Math.PI) / 180;
  return [Math.sin(r), Math.cos(r)];
};
const along = (p, v, len) => [p[0] + v[0] * len, p[1] + v[1] * len];

/** 一隻腳：髖 → 膝 → 踝 → 腳尖（side −1 左、1 右，腳尖朝外）。 */
function leg(hip, hipDeg, kneeDeg, side) {
  const knee = along(hip, dir(hipDeg), RIG.thigh);
  const ankle = along(knee, dir(hipDeg + kneeDeg), RIG.shin);
  return [hip, knee, ankle, [ankle[0] + side * RIG.foot, ankle[1] + 1]];
}

/** 一隻手：肩 → 肘 → 手。 */
function arm(shoulder, shoulderDeg, elbowDeg) {
  const elbow = along(shoulder, dir(shoulderDeg), RIG.upper);
  return [shoulder, elbow, along(elbow, dir(shoulderDeg + elbowDeg), RIG.fore)];
}

/**
 * 姿勢換成要畫的點：兩腳、身體、兩手各是一串相連的點，頭是掛在脖子上的一個位置＋角度＋高度比例。
 * lift：離地多高（0＝站在地上，1＝跳到最高附近），畫地上的影子用。
 */
export function skeleton(p) {
  const hip = [RIG.hipX, RIG.hipY + p.ry];
  const up = dir(180 - p.lean);
  const torso = RIG.torso * p.tl;
  const neck = along(hip, up, torso);
  const shoulder = along(hip, up, torso - RIG.shoulderDrop);
  const sy = shoulder[1] + p.sh;
  return {
    legs: [leg(hip, p.lH, p.lK, -1), leg(hip, p.rH, p.rK, 1)],
    torso: [hip, [neck[0], neck[1] + p.sh / 2]],
    arms: [
      arm([shoulder[0] - RIG.shoulderHalf, sy], p.lS, p.lE),
      arm([shoulder[0] + RIG.shoulderHalf, sy], p.rS, p.rE),
    ],
    head: { x: neck[0], y: neck[1] + p.hy + p.sh / 2, rotate: p.head + p.lean, scaleY: p.hs },
    lift: Math.max(0, -p.ry / 40),
  };
}
