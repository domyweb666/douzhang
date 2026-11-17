// 番茄帳 分析（2026-11-17 AG5）：一段時間裡專注多久、收了幾顆、每天各標籤多少、各標籤占多少。
// 純函式，只讀 state 不寫。只陳述，不跟上一段比（產品定稿：不做「比上週少幾 %」）。
import { dayKey } from './store';
import { typeOf } from './machine';
import { weekDays, weekStart } from './receipt';

export const RANGE = { day: 'day', week: 'week', month: 'month' };

/** 這一段包含哪幾天：日＝選中那天；週＝那一週七天；月＝那個月每一天。 */
export function rangeDays(range, selected) {
  if (range === RANGE.week) return weekDays(weekStart(selected));
  if (range !== RANGE.month) return [selected];
  const d = new Date(`${selected}T00:00`);
  const count = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
  return Array.from({ length: count }, (_, i) =>
    dayKey(new Date(d.getFullYear(), d.getMonth(), i + 1).getTime()),
  );
}

const minutesOf = (bean) => bean.len + (bean.flow || 0);

/**
 * 這幾天的小計。回：
 * minutes 總分鐘（含延長）、beans 幾顆、
 * days 每天一筆 { key, minutes, parts: [{ type, minutes }] }（parts 照標籤在設定裡的順序），
 * tags 每個有番茄的標籤一筆 { type, minutes, beans, share }（share 是占總分鐘的幾成，由多到少），
 * list 這幾天每一顆 { t, type, len }（依時間排）。
 * 標籤被刪掉的舊番茄算在第一個標籤上（跟番茄架、罐子同一條規則）。
 */
export function stats(state, keys) {
  const byTag = new Map();
  const list = [];
  const days = keys.map((key) => {
    const perTag = new Map();
    for (const bean of state.days[key]?.beans || []) {
      const type = typeOf(state, bean.typeId);
      const minutes = minutesOf(bean);
      perTag.set(type.id, (perTag.get(type.id) || 0) + minutes);
      const sum = byTag.get(type.id) || { type, minutes: 0, beans: 0 };
      byTag.set(type.id, { type, minutes: sum.minutes + minutes, beans: sum.beans + 1 });
      list.push({ t: bean.t, type, len: bean.len });
    }
    const parts = state.settings.types
      .filter((t) => perTag.has(t.id))
      .map((t) => ({ type: t, minutes: perTag.get(t.id) }));
    return { key, minutes: parts.reduce((a, p) => a + p.minutes, 0), parts };
  });
  const minutes = days.reduce((a, d) => a + d.minutes, 0);
  const tags = [...byTag.values()]
    .map((x) => ({ ...x, share: minutes ? x.minutes / minutes : 0 }))
    .sort((a, b) => b.minutes - a.minutes);
  return { minutes, beans: list.length, days, tags, list: list.sort((a, b) => a.t - b.t) };
}
