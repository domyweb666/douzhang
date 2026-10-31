// 豆帳 狀態機：待機／計時中／鈴響／休息。純函式，吃 state 回新 state，不碰畫面、不存檔、不排通知。
// 只存 endAt（幾點結束），不存剩幾秒：背景、鎖屏、殺掉再開都靠時間差重算（A3 驗邊界）。
// 資料格式照 PWA：current、clue、days 的欄位名與 index.html 相同。
import { blankDay, dayKey, restMinutes } from './store';
import { MS_PER_MINUTE } from '../design/params';
import { words } from '../design/words';

export const PHASE = { idle: 'idle', focus: 'focus', bell: 'bell', rest: 'rest' };

/** 開發期專用的一分鐘類型。正式 build（__DEV__ 為 false）永遠不會被選到。 */
export const DEV_TYPE = { id: 'dev-1min', name: words.devTypeName, len: 1 };

export function typeOf(state, typeId) {
  if (typeId === DEV_TYPE.id) return DEV_TYPE;
  return state.settings.types.find((t) => t.id === typeId) || state.settings.types[0];
}

/** 休息有沒有到點。「我自己決定」的休息沒有 endAt，永遠不自己結束。 */
const restOver = (c, now) => c.endAt != null && now >= c.endAt;

/** 現在該顯示哪一態：由 current 與時鐘算出來，不另外存。 */
export function phaseOf(state, now) {
  const c = state.current;
  if (!c) return PHASE.idle;
  if (c.phase === PHASE.focus) return now >= c.endAt ? PHASE.bell : PHASE.focus;
  if (c.phase === PHASE.rest) return restOver(c, now) ? PHASE.idle : PHASE.rest;
  return PHASE.idle;
}

/** 休息到點就算回待機了：把過期的 rest 收掉。每次 tick 與開機讀檔後呼叫。 */
export function settle(state, now) {
  const c = state.current;
  if (c && c.phase === PHASE.rest && restOver(c, now)) return { ...state, current: null };
  return state;
}

/**
 * 開始一顆。firstLine 只在第一次（沒有那句）時傳：那句同時成為這顆的下一步。
 * 空白的 firstLine 不開始（06 定案：沒有那句，第一顆響完無句可接）。
 */
export function start(state, now, { typeId = state.settings.typeId, firstLine } = {}) {
  const text = (firstLine || '').trim();
  if (!state.clue && !text) return state;
  const type = typeOf(state, typeId);
  const clue = text ? { text, at: now } : state.clue;
  return {
    ...state,
    clue,
    current: {
      phase: PHASE.focus,
      typeId: type.id,
      len: type.len,
      startedAt: now,
      endAt: now + type.len * MS_PER_MINUTE,
      notes: [],
      pings: [],
      flowed: false,
      taskId: null,
      clue: clue ? clue.text : '',
    },
  };
}

/** 收下後那句：24 句輪替，不跟上一次同一句（PWA pickLine，lastLine 同名欄位）。 */
function pickLine(state) {
  const n = words.restLines.length;
  let i = Math.floor(Math.random() * n);
  if (i === state.lastLine) i = (i + 1) % n;
  return { index: i, text: words.restLines[i] };
}

/**
 * 收下這顆：豆子進「開始那天」的帳、有字就換那句、進休息。
 * 空白也收（A2）；要多按一下「這顆不留話」的守門在畫面層（A5）。
 */
export function keep(state, now, text) {
  const c = state.current;
  if (!c || c.phase !== PHASE.focus) return state;
  const line = (text || '').trim();
  const bean = {
    t: now,
    typeId: c.typeId,
    len: c.len,
    clue: line,
    notes: c.notes,
    pings: c.pings,
    flow: c.flowMin || 0,
    taskId: c.taskId,
    start: c.startedAt,
  };
  const key = dayKey(c.startedAt);
  const prev = state.days[key] || blankDay();
  const days = { ...state.days, [key]: { ...prev, beans: [...prev.beans, bean] } };
  const clue = line ? { text: line, at: now } : state.clue;
  // 響了沒理、拖到超過這顆的休息長度才回來收：休息早過了，直接待機（PRD S8）
  const restMs = restMinutes(c.len) * MS_PER_MINUTE;
  if (now - c.endAt >= restMs) return { ...state, days, clue, current: null };
  const picked = pickLine(state);
  return {
    ...state,
    days,
    clue,
    lastLine: picked.index,
    current: {
      phase: PHASE.rest,
      typeId: c.typeId,
      len: c.len,
      restStart: now,
      // 「我自己決定」：沒有結束時刻，畫面數正數，只有按回來才結束
      endAt: state.settings.restMode === 'self' ? null : now + restMs,
      rang: false,
      msg: picked.text,
    },
  };
}

/** 鈴響後再做 15／30 分：一顆只能一次（S11）。到點再響，收下時 flow 記總延長分鐘。 */
export function flow(state, now, minutes) {
  const c = state.current;
  if (!c || c.phase !== PHASE.focus || now < c.endAt || c.flowed) return state;
  return {
    ...state,
    current: {
      ...c,
      endAt: now + minutes * MS_PER_MINUTE,
      flowed: true,
      flowMin: (c.flowMin || 0) + minutes,
    },
  };
}

/** 回來了，開始下一顆：結束休息回待機（不自動開始，開始要人按）。 */
export function backFromRest(state) {
  if (!state.current || state.current.phase !== PHASE.rest) return state;
  return { ...state, current: null };
}

/** 鈴響頁打到一半的字：存進 current.draft（PWA 同名欄位），切走或殺掉再開還在；收下時隨 current 一起消失。 */
export function setDraft(state, text) {
  const c = state.current;
  if (!c || c.phase !== PHASE.focus) return state;
  return { ...state, current: { ...c, draft: text } };
}
