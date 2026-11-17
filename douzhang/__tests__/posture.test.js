// 姿勢判斷測試（聚焦模式）。只驗「直拿、橫放、平放分得出來，要維持一下才算」；真的感測器要真機。
import { POSE, poseOf, startTracker, track } from '../core/posture';
import { params } from '../design/params';

const P = params.zen;
const UP = { x: 0, y: -1, z: 0 }; // 直拿
const SIDE = { x: 1, y: 0, z: 0 }; // 橫放，右邊朝下
const OTHER_SIDE = { x: -1, y: 0, z: 0 }; // 橫放，左邊朝下
const FLAT = { x: 0, y: 0, z: -1 }; // 平放在桌上

/** 每 sampleMs 餵一筆同樣的加速度，餵 ms 這麼久；回最後的追蹤狀態與途中確定換成的姿勢。 */
const hold = (tracker, sample, from, ms) => {
  const changes = [];
  let t = from;
  for (; t <= from + ms; t += P.sampleMs) {
    const next = track(tracker, sample, t, P);
    tracker = next.tracker;
    if (next.changed) changes.push(next.changed);
  }
  return { tracker, changes, t };
};

test('直拿、橫放兩邊、平放分得出來；單位是 g 或 m/s² 都一樣', () => {
  expect(poseOf(UP, P.ratio)).toBe(POSE.portrait);
  expect(poseOf(SIDE, P.ratio)).toBe(POSE.landscape);
  expect(poseOf(OTHER_SIDE, P.ratio)).toBe(POSE.landscape);
  expect(poseOf(FLAT, P.ratio)).toBeNull();
  expect(poseOf({ x: 9.8, y: 0.5, z: 1 }, P.ratio)).toBe(POSE.landscape);
  expect(poseOf({ x: 0, y: 0, z: 0 }, P.ratio)).toBeNull();
});

test('斜 45 度拿著兩個都不算', () => {
  expect(poseOf({ x: 0.7, y: -0.7, z: 0 }, P.ratio)).toBeNull();
});

test('橫放維持夠久才算換成橫放，而且只回報一次', () => {
  const short = hold(startTracker(), SIDE, 0, P.dwellMs - P.sampleMs);
  expect(short.changes).toEqual([]);
  const long = hold(startTracker(), SIDE, 0, P.dwellMs * 3);
  expect(long.changes).toEqual([POSE.landscape]);
});

test('拿起來晃一下又回到直拿：不算', () => {
  const a = hold(startTracker(), SIDE, 0, P.dwellMs - P.sampleMs);
  const b = hold(a.tracker, UP, a.t, P.dwellMs * 2);
  const c = hold(b.tracker, SIDE, b.t, P.dwellMs - P.sampleMs);
  expect([...a.changes, ...b.changes, ...c.changes]).toEqual([]);
});

test('橫放之後平放在桌上：維持橫放，不會跳回直向', () => {
  const a = hold(startTracker(), SIDE, 0, P.dwellMs * 2);
  const b = hold(a.tracker, FLAT, a.t, P.dwellMs * 5);
  expect(b.changes).toEqual([]);
  expect(b.tracker.pose).toBe(POSE.landscape);
});

test('橫放再直拿回來：先回報橫放，再回報直拿', () => {
  const a = hold(startTracker(), SIDE, 0, P.dwellMs * 2);
  const b = hold(a.tracker, UP, a.t, P.dwellMs * 2);
  expect([...a.changes, ...b.changes]).toEqual([POSE.landscape, POSE.portrait]);
});

test('橫放時左右翻面：還是橫放，不回報', () => {
  const a = hold(startTracker(), SIDE, 0, P.dwellMs * 2);
  const b = hold(a.tracker, OTHER_SIDE, a.t, P.dwellMs * 2);
  expect(b.changes).toEqual([]);
});
