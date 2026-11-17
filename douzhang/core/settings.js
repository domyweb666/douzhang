// 豆帳 設定與估算：改類型、節奏、提醒、手感，估這件事幾顆。純函式，吃 state 回新 state，不存檔。
// 類型沒有「單顆改分鐘」的地方：長度只能從 params.typeLengths 的刻度選（S5 同一把尺）。
import { blankDay, dayKey } from './store';
import { params } from '../design/params';
import { words } from '../design/words';

const withSettings = (state, patch) => ({ ...state, settings: { ...state.settings, ...patch } });
const mapTypes = (state, fn) => withSettings(state, { types: state.settings.types.map(fn) });

export function pickType(state, typeId) {
  if (!state.settings.types.some((t) => t.id === typeId)) return state;
  return withSettings(state, { typeId });
}

/** 新類型拿第一個還沒人用的番茄色，都用過就從頭輪。 */
function freeColor(types) {
  const used = new Set(types.map((t) => t.color));
  const all = params.tomatoColors;
  return all.find((c) => !used.has(c)) || all[types.length % all.length];
}

export function addType(state, now) {
  const type = {
    id: `t${now}`,
    name: words.newTypeName,
    len: params.newTypeMinutes,
    color: freeColor(state.settings.types),
  };
  return withSettings(state, { types: [...state.settings.types, type] });
}

export function renameType(state, id, name) {
  const clean = (name || '').trim().slice(0, params.typeNameMaxChars) || words.unnamedType;
  return mapTypes(state, (t) => (t.id === id ? { ...t, name: clean } : t));
}

export function setTypeLen(state, id, len) {
  if (!params.typeLengths.includes(len)) return state;
  return mapTypes(state, (t) => (t.id === id ? { ...t, len } : t));
}

/** 刪到剩一種就不能再刪（06 限制）；刪掉的是選中的就退回第一個。 */
export function removeType(state, id) {
  const types = state.settings.types.filter((t) => t.id !== id);
  if (!types.length || types.length === state.settings.types.length) return state;
  const typeId = types.some((t) => t.id === state.settings.typeId)
    ? state.settings.typeId
    : types[0].id;
  return withSettings(state, { types, typeId });
}

export const setRestMode = (state, restMode) =>
  withSettings(state, { restMode: restMode === 'self' ? 'self' : 'auto' });
/** 短休息、長休息：只准刻度上的值（下一次收下才用到，休息中改不影響這次）。 */
export const setRestShort = (state, restShort) =>
  params.restShortOptions.includes(restShort) ? withSettings(state, { restShort }) : state;
export const setRestLongEvery = (state, restLongEvery) =>
  params.restLongEveryOptions.includes(restLongEvery)
    ? withSettings(state, { restLongEvery })
    : state;
export const setRestLongMinutes = (state, restLongMinutes) =>
  params.restLongMinuteOptions.includes(restLongMinutes)
    ? withSettings(state, { restLongMinutes })
    : state;
/** 收工時間只准刻度上的值（params.closeTimes）；匯入的舊檔可以是別的值，設定頁就是沒有一格亮。 */
export const setCloseTime = (state, closeTime) =>
  params.closeTimes.includes(closeTime) ? withSettings(state, { closeTime }) : state;
export const setSound = (state, sound) => withSettings(state, { sound: !!sound });
export const setTilt = (state, tilt) => withSettings(state, { tilt: !!tilt });
export const setShield = (state, shield) => withSettings(state, { shield: !!shield });

/** 換這種類型的番茄色（W1）；不是五色之一就不換。 */
export function setTypeColor(state, id, color) {
  if (!params.tomatoColors.includes(color)) return state;
  const types = state.settings.types.map((t) => (t.id === id ? { ...t, color } : t));
  return withSettings(state, { types });
}
export const setTestMode = (state, on) => withSettings(state, { demo: !!on }); // 存在 PWA 的 demo 欄

/** 估這件事幾顆：寫進今天的 tasks，並把它設成目前那件事（之後收下的豆掛它）。 */
export function estimate(state, now, { name, est }) {
  const clean = (name || '').trim().slice(0, params.taskNameMaxChars);
  if (!clean || !Number.isInteger(est) || est < 1 || est > params.estimateMax) return state;
  const key = dayKey(now);
  const prev = state.days[key] || blankDay();
  const task = { id: `k${now}`, name: clean, est, typeId: state.settings.typeId };
  return {
    ...state,
    days: { ...state.days, [key]: { ...prev, tasks: [...prev.tasks, task] } },
    taskId: task.id,
  };
}

/** 這件事是不是今天估過的：豆子只掛今天的事。 */
export const isTodayTask = (state, now, taskId) =>
  !!taskId && (state.days[dayKey(now)]?.tasks || []).some((t) => t.id === taskId);

/** 換目前那件事（今天估過的其中一件），或不掛任務（null）。不是今天的事就不換。 */
export function pickTask(state, now, taskId) {
  if (taskId && !isTodayTask(state, now, taskId)) return state;
  return { ...state, taskId: taskId || null };
}
