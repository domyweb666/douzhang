// 番茄帳 番茄架的行事曆（2026-11-17 AG4）：天／3 天／週共用一條時間軸，月是一格一天。純函式，只讀 state 不寫。
// 規則沿用蒜日子（E:\蒜日子 docs/SPEC.md 15.3）：重疊的並排、同一群平分欄寬；太短的畫到最小高度；
// 跨過午夜的只畫到當天 24:00。月檢視沿用它的「彈性週」：沒番茄的週壓扁。
// 位置都用「小時」當單位，畫面再乘上一小時多高；這裡不帶任何畫面上的字與尺寸。
import { dayKey } from './store';
import { dayTimeline, shiftWeek, weekDays, weekStart } from './receipt';
import { MS_PER_HOUR } from '../design/params';

export const VIEW = { day: 'day', three: 'three', week: 'week', month: 'month' };
const HOURS_PER_DAY = 24;
const THREE = 3;

const dateOf = (key) => new Date(`${key}T00:00`);

/** 往前或往後幾天的日期鍵。 */
export function shiftDay(key, days) {
  const d = dateOf(key);
  return dayKey(new Date(d.getFullYear(), d.getMonth(), d.getDate() + days).getTime());
}

/** 往前或往後幾個月的 1 號。 */
export function shiftMonth(key, months) {
  const d = dateOf(key);
  return dayKey(new Date(d.getFullYear(), d.getMonth() + months, 1).getTime());
}

/** 這個檢視畫哪幾天：天＝選中那天；3 天＝選中那天與前兩天；週＝那一週七天（週一開頭）。月不走這裡。 */
export function viewDays(view, selected) {
  if (view === VIEW.week) return weekDays(weekStart(selected));
  const count = view === VIEW.three ? THREE : 1;
  return Array.from({ length: count }, (_, i) => shiftDay(selected, i - (count - 1)));
}

/** 按 ‹ › 換一段之後選哪一天：天動一天、3 天動三天、週動一週、月跳到那個月的 1 號。 */
export function shiftPeriod(view, selected, step) {
  if (view === VIEW.month) return shiftMonth(selected, step);
  if (view === VIEW.week) return shiftWeek(weekStart(selected), step);
  return shiftDay(selected, step * (view === VIEW.three ? THREE : 1));
}

/** 畫面上這一段有沒有包含今天或更晚的日子（有的話不給往後翻）。 */
export function reachesToday(view, selected, todayKey) {
  if (view === VIEW.month) return shiftMonth(selected, 1) > todayKey;
  const days = viewDays(view, selected);
  return days[days.length - 1] >= todayKey;
}

/**
 * 一天的方塊排好位置。top、height 的單位是小時（從當天 0 點算）；
 * 重疊的分到不同欄（lane），同一群重疊的平分寬度（lanes＝這一群有幾欄）。
 * minHours：再短也畫這麼高，所以兩顆很短又很近的會被當成重疊、排成左右並排（多米 2026-11-17 回報疊在一起）。
 */
export function dayBlocks(day, key, minHours) {
  const base = dateOf(key).getTime();
  const out = [];
  let cluster = [];
  let clusterEnd = -1;
  const flush = () => {
    const lanes = Math.max(...cluster.map((b) => b.lane)) + 1;
    for (const b of cluster) b.lanes = lanes;
    cluster = [];
  };
  for (const item of dayTimeline(day).items) {
    const top = (item.start - base) / MS_PER_HOUR;
    const end = Math.min(HOURS_PER_DAY, (item.end - base) / MS_PER_HOUR);
    const height = Math.max(minHours, end - top);
    if (cluster.length && top >= clusterEnd) {
      flush();
      clusterEnd = -1;
    }
    let lane = 0;
    while (cluster.some((b) => b.lane === lane && b.top + b.height > top)) lane++;
    const block = { item, top, height, lane, lanes: 1 };
    cluster.push(block);
    out.push(block);
    clusterEnd = Math.max(clusterEnd, top + height);
  }
  if (cluster.length) flush();
  return out;
}

/**
 * 幾天共用的時間軸從幾點畫到幾點：最早那顆的整點前一小時，到最晚那顆結束的整點後一小時。
 * columns：每天排好的方塊（dayBlocks 的結果）。都沒有東西回 null（畫面就空著，不寫 0）。
 */
export function axisHours(columns) {
  const blocks = columns.flat();
  if (!blocks.length) return null;
  const first = Math.min(...blocks.map((b) => b.top));
  const last = Math.max(...blocks.map((b) => b.top + b.height));
  return {
    from: Math.max(0, Math.floor(first) - 1),
    to: Math.min(HOURS_PER_DAY, Math.ceil(last) + 1),
  };
}

/** 現在是當天的第幾小時（畫今天那條線用）。 */
export const hourOfDay = (now) => (now - dateOf(dayKey(now)).getTime()) / MS_PER_HOUR;

/**
 * 這個月的格子：一週一列（週一開頭），每格 { key, inMonth, beans, leaf }；
 * busy＝這週在這個月裡有沒有番茄，沒有的週畫面壓扁成一行。不屬於這個月的格子不帶番茄。
 * leaf（2026-11-18 AH7 多米：葉子留在番茄架）：這個月裡、已經過完、沒有番茄的日子掛一片葉子，不算缺。
 * 今天與以後不掛（今天還沒過完）；第一顆番茄那天以前也不掛（那時還沒在用番茄帳，不是「沒做」）。
 */
export function monthWeeks(state, key, todayKey) {
  const d = dateOf(key);
  const month = d.getMonth();
  const lastKey = dayKey(new Date(d.getFullYear(), month + 1, 0).getTime());
  const firstKey = Object.keys(state.days)
    .filter((k) => state.days[k]?.beans?.length > 0)
    .sort()[0];
  const weeks = [];
  let ws = weekStart(dayKey(new Date(d.getFullYear(), month, 1).getTime()));
  while (ws <= lastKey) {
    const days = weekDays(ws).map((k) => {
      const inMonth = dateOf(k).getMonth() === month;
      const beans = inMonth ? state.days[k]?.beans || [] : [];
      const leaf = inMonth && !!firstKey && k >= firstKey && k < todayKey && beans.length === 0;
      return { key: k, inMonth, beans, leaf };
    });
    weeks.push({ weekStart: ws, days, busy: days.some((x) => x.beans.length > 0) });
    ws = shiftWeek(ws, 1);
  }
  return weeks;
}
