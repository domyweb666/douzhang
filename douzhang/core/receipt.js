// 豆帳 收據計算：豆棚每天一列、一天的收據、一週的收據。純函式，只讀 state 不寫。
// 算法逐行翻自 PWA 原型 index.html 的 podHTML／weekStart／renderRack／taskRows／openReceipt／openWeek，
// 數字要跟 PWA 同一份資料對得上（E2 立即驗）。這裡只算，不帶任何畫面上的字；字在畫面層從 words.js 拿。
import { dayKey, units } from './store';
import { typeOf } from './machine';
import { params } from '../design/params';

export const VERDICT = { fewData: 'fewData', under: 'under', over: 'over', even: 'even' };

/** 這一天所屬的週（週一起算）的日期鍵。 */
export function weekStart(key) {
  const d = new Date(`${key}T00:00`);
  d.setDate(d.getDate() - ((d.getDay() + 6) % 7));
  return dayKey(d.getTime());
}

/** 一天有沒有東西可掛：有豆、有作廢、或掛了葉子。沒有的日子豆棚不出現（不出現 0）。 */
export const hasRecord = (d) => !!(d && (d.beans.length || d.voids.length || d.leaf));

/** 豆莢上的格子：豆（幾單位）與作廢（空心），依時間排。 */
export function podItems(d) {
  if (!d) return [];
  return [
    ...d.beans.map((b) => ({ t: b.t, kind: 'bean', units: units(b.len) })),
    ...d.voids.map((v) => ({ t: v.t, kind: 'void' })),
  ].sort((a, b) => a.t - b.t);
}

/** 豆棚：有紀錄的日子由新到舊，分週；每週內由新到舊。 */
export function rackWeeks(state) {
  const keys = Object.keys(state.days)
    .filter((k) => hasRecord(state.days[k]))
    .sort()
    .reverse();
  const weeks = {};
  for (const k of keys) (weeks[weekStart(k)] ||= []).push(k);
  return Object.keys(weeks)
    .sort()
    .reverse()
    .map((ws) => ({ weekStart: ws, days: weeks[ws] }));
}

/** 一天的收據：豆與作廢依時間排成一列列。 */
export function dayReceipt(d) {
  if (!d) return [];
  return [
    ...d.beans.map((b) => ({
      t: b.t,
      kind: 'bean',
      start: b.start || b.t,
      clue: b.clue || '',
      double: units(b.len) > 1,
      flow: b.flow || 0,
      notes: (b.notes || []).length,
      pings: (b.pings || []).length,
    })),
    ...d.voids.map((v) => ({
      t: v.t,
      kind: 'void',
      minute: v.minute,
      reason: v.reason || '',
      text: v.text || '',
    })),
  ].sort((a, b) => a.t - b.t);
}

/** 估算對帳：每件估過的事，實際收了幾單位。 */
export function taskRows(d) {
  return d.tasks.map((t) => ({
    task: t,
    actual: d.beans.filter((b) => b.taskId === t.id).reduce((s, b) => s + units(b.len), 0),
  }));
}

/** 估算對帳的三個計數：第一次做的（novel）與還沒收過豆的任務不列入。 */
function tallyTasks(days) {
  const n = { under: 0, over: 0, even: 0 };
  for (const d of days)
    for (const { task, actual } of taskRows(d)) {
      if (task.novel || !actual) continue;
      if (actual > task.est) n.under++;
      else if (actual < task.est) n.over++;
      else n.even++;
    }
  return n;
}

function tallyBeans(state, days) {
  const byType = {};
  let beanN = 0;
  let flowN = 0;
  for (const d of days)
    for (const b of d.beans) {
      const name = typeOf(state, b.typeId).name;
      byType[name] = (byType[name] || 0) + units(b.len);
      beanN++;
      if (b.flow) flowN++;
    }
  return { byType: Object.entries(byType).map(([name, u]) => ({ name, units: u })), beanN, flowN };
}

function tallyVoids(state, days) {
  const voids = {};
  for (const d of days)
    for (const v of d.voids) {
      const label = typeOf(state, v.typeId).name + (v.reason ? `・${v.reason}` : '');
      voids[label] = (voids[label] || 0) + 1;
    }
  return Object.entries(voids).map(([label, count]) => ({ label, count }));
}

function verdictOf({ under, over, even }) {
  if (under + over + even < params.receipt.minTasksForVerdict) return VERDICT.fewData;
  if (under > over * 2) return VERDICT.under;
  if (over > under * 2) return VERDICT.over;
  return VERDICT.even;
}

/** 一週的收據（PWA openWeek）。 */
export function weekReceipt(state, ws) {
  const days = Object.keys(state.days)
    .filter((k) => weekStart(k) === ws)
    .map((k) => state.days[k]);
  const tasks = tallyTasks(days);
  const { byType, beanN, flowN } = tallyBeans(state, days);
  const voids = tallyVoids(state, days);
  const totalVoids = voids.reduce((a, v) => a + v.count, 0);
  return {
    byType,
    ...tasks,
    verdict: verdictOf(tasks),
    voids,
    totalVoids,
    voidHint: totalVoids >= params.receipt.voidsForHint,
    flowHint: beanN >= params.receipt.flowHintMinBeans && flowN * 2 > beanN,
  };
}
