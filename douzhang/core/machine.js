// 豆帳 狀態機：待機／計時中／鈴響／休息。純函式，吃 state 回新 state，不碰畫面、不存檔、不排通知。
// 只存 endAt（幾點結束），不存剩幾秒：背景、鎖屏、殺掉再開都靠時間差重算（A3 驗邊界）。
// 資料格式照 PWA：current、clue、days 的欄位名與 index.html 相同。
import { blankDay, dayKey, restAfter } from './store';
import { MS_PER_MINUTE, MS_PER_SECOND, SECONDS_PER_MINUTE, params } from '../design/params';
import { words } from '../design/words';
import { isTodayTask } from './settings';

export const PHASE = { idle: 'idle', focus: 'focus', bell: 'bell', rest: 'rest' };

/** 開發期專用的一分鐘類型。正式 build（__DEV__ 為 false）永遠不會被選到。 */
export const DEV_TYPE = {
  id: 'dev-test',
  name: words.devTypeName,
  len: params.devTestSeconds / SECONDS_PER_MINUTE,
  color: 'red',
};

export function typeOf(state, typeId) {
  if (typeId === DEV_TYPE.id) return DEV_TYPE;
  return state.settings.types.find((t) => t.id === typeId) || state.settings.types[0];
}

/** 休息有沒有到點。「我自己決定」的休息沒有 endAt，永遠不自己結束。 */
const restEnded = (c, now) => c.endAt != null && now >= c.endAt;

/** 現在該顯示哪一態：由 current 與時鐘算出來，不另外存。 */
export function phaseOf(state, now) {
  const c = state.current;
  if (!c) return PHASE.idle;
  if (c.phase === PHASE.focus) return now >= c.endAt ? PHASE.bell : PHASE.focus;
  if (c.phase === PHASE.rest) return restEnded(c, now) ? PHASE.idle : PHASE.rest;
  return PHASE.idle;
}

/** 休息到點就算回待機了：把過期的 rest 收掉。每次 tick 與開機讀檔後呼叫。 */
export function settle(state, now) {
  const c = state.current;
  if (c && c.phase === PHASE.rest && restEnded(c, now)) return { ...state, current: null };
  return state;
}

/**
 * 開始一顆。2026-11-17 AG1 起不用先有一句（「接」降成選填筆記）：按了就開始。
 * state.clue 是舊版留下來的那句，不動它、也不再帶進這顆。
 */
export function start(state, now, { typeId = state.settings.typeId } = {}) {
  const type = typeOf(state, typeId);
  return {
    ...state,
    current: {
      phase: PHASE.focus,
      typeId: type.id,
      len: type.len,
      startedAt: now,
      endAt: now + type.len * MS_PER_MINUTE,
      notes: [],
      pings: [],
      flowed: false,
      // 只掛今天估過的那件事：昨天估的不跟著過夜（B+C 審查員）
      taskId: isTodayTask(state, now, state.taskId) ? state.taskId : null,
      clue: '',
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
  // 收工後又做了一顆：那天回到沒收工，收工入口會再出現（PWA finish 同做法）
  const days = { ...state.days, [key]: { ...prev, beans: [...prev.beans, bean], closed: false } };
  const clue = line ? { text: line, at: now } : state.clue;
  // 響了沒理、拖到超過這顆的休息長度才回來收：休息早過了，直接待機（PRD S8）
  // 那天第幾顆決定這次是短休息還是長休息（2026-11-17 設定 A）
  const rest = restAfter(state.settings, c.len, days[key].beans.length);
  // 測試顆的休息跟它一樣短（V3），不然看一次掉番茄要等 3 分鐘；輪到長休息時照樣標成長休息，數顆數才看得到
  const restMs =
    c.typeId === DEV_TYPE.id ? params.devTestSeconds * MS_PER_SECOND : rest.minutes * MS_PER_MINUTE;
  const self = state.settings.restMode === 'self';
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
      endAt: self ? null : now + restMs,
      long: !self && rest.long, // 「我自己決定」的休息沒有長短
      rang: false,
      msg: picked.text,
    },
  };
}

/** 計時中記一筆：kind 是 'notes'（冒出念頭）或 'pings'（有人找）。倒數不停，只是往這顆裡推一行。 */
export function jot(state, kind, text) {
  const c = state.current;
  const line = (text || '').trim();
  if (!c || c.phase !== PHASE.focus || !line) return state;
  return { ...state, current: { ...c, [kind]: [...(c[kind] || []), line] } };
}

/** 提早做完了：剩下的時間繼續倒數，鈴響再停；卡片多一行提醒（PWA done 同名欄位）。 */
export function markDone(state) {
  const c = state.current;
  if (!c || c.phase !== PHASE.focus) return state;
  return { ...state, current: { ...c, done: true } };
}

/** 開始不到 stopNoRecordMinutes 分：這時結束叫「停下來」，不留紀錄（06 結束這顆半頁）。 */
export const stoppedEarly = (current, now) =>
  now - current.startedAt < params.stopNoRecordMinutes * MS_PER_MINUTE;

/**
 * 作廢這顆：只在開始那天記一筆 { t, typeId, minute, reason, text, taskId }，豆子不扣、什麼都不扣（S10）；回待機。
 * 停下來（不到五分鐘）什麼都不記。early 是畫面在打開半頁那一刻固定的判斷，有給就照它，沒給才看現在。
 */
export function voidBean(state, now, { reason = '', text = '', early } = {}) {
  const c = state.current;
  if (!c || c.phase !== PHASE.focus) return state;
  if (early ?? stoppedEarly(c, now)) return { ...state, current: null };
  const minute = Math.floor((now - c.startedAt) / MS_PER_MINUTE);
  const key = dayKey(c.startedAt);
  const prev = state.days[key] || blankDay();
  const entry = {
    t: now,
    typeId: c.typeId,
    minute,
    reason,
    text: (text || '').trim(),
    taskId: c.taskId,
  };
  return {
    ...state,
    days: { ...state.days, [key]: { ...prev, voids: [...prev.voids, entry] } },
    current: null,
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

const hasBeansOrVoids = (d) => !!d && (d.beans.length > 0 || d.voids.length > 0);

/** 現在幾點幾分（本地）→ "HH:MM"，跟設定的收工時間同格式，字串比大小就是比時刻。 */
function clockOf(now) {
  const d = new Date(now);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/**
 * 待機卡片下那一行（PWA renderHome 的 hint，順序照抄）：
 * 'closed' 今天收工了｜'due' 有豆子、過了收工時間、還沒收工｜'leaf' 今天掛了葉子｜null 什麼都不顯示。
 */
export function closeHint(state, now) {
  const d = state.days[dayKey(now)];
  if (d?.closed) return 'closed';
  if (hasBeansOrVoids(d) && clockOf(now) >= state.settings.closeTime) return 'due';
  if (d?.leaf) return 'leaf';
  return null;
}

/**
 * 豆棚頂端那一列（PWA renderRack，不看收工時間）：
 * 'close' 今天有豆子或作廢、還沒收工｜'leaf' 今天什麼都沒有｜null 收工了或掛了葉子。
 */
export function rackTopRow(state, now) {
  const d = state.days[dayKey(now)];
  if (hasBeansOrVoids(d)) return d.closed ? null : 'close';
  return d?.leaf ? null : 'leaf';
}

/** 今天能不能掛葉子：沒有豆子也沒有作廢（S15）。 */
export const canHangLeaf = (state, now) => !hasBeansOrVoids(state.days[dayKey(now)]);

/**
 * 收工：明天的第一句有改才換那句；今天標成收工；把那句「種下去」，明天第一次打開時小標換成「昨天的你留了一句」。
 */
export function closeDay(state, now, text) {
  const line = (text || '').trim();
  const clue = line && line !== state.clue?.text ? { text: line, at: now } : state.clue;
  const key = dayKey(now);
  const prev = state.days[key] || blankDay();
  return {
    ...state,
    clue,
    days: { ...state.days, [key]: { ...prev, closed: true } },
    planted: { text: clue ? clue.text : '', day: key, shown: false },
  };
}

/** 掛一片葉子：今天沒豆子也沒作廢才掛得上；掛了就算收工（S15，不算缺）。 */
export function hangLeaf(state, now) {
  if (!canHangLeaf(state, now)) return state;
  const key = dayKey(now);
  const prev = state.days[key] || blankDay();
  return { ...state, days: { ...state.days, [key]: { ...prev, leaf: true, closed: true } } };
}

/**
 * 昨天以前種下、還沒看過的那句：待機時第一次看到就標成看過。
 * 回 { state, greet }：greet＝這次小標要打招呼——卡片上那句還是種下的那句才打（跨午夜收下了新的一句，就只標看過、不打招呼）。
 * 計時中、休息中不看（畫面上沒有那句），等回到待機再說。
 */
export function seePlanted(state, now) {
  const p = state.planted;
  if (!p || p.shown || p.day === dayKey(now) || state.current) return { state, greet: false };
  return {
    state: { ...state, planted: { ...p, shown: true } },
    greet: state.clue?.text === p.text,
  };
}
