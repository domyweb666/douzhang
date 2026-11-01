// 豆帳 資料層：單一 JSON 狀態檔，格式與 PWA 原型（index.html）完全相同，PWA 匯出的備份直接讀得進來。
// 只做讀、寫、補欄位、算單位。不碰畫面、不排通知、不決定轉態（那是 machine.js 的事）。
// 安全標準：S1 狀態檔沒有機敏欄位；S6 寫失敗要回報給畫面；I1／I2 壞檔不蓋、缺欄位補預設、不信任外部型別。
import AsyncStorage from '@react-native-async-storage/async-storage';

export const STORAGE_KEY = 'douzhang.v1'; // 跟 PWA 的 localStorage key 同名，只是換了地方住
export const FORMAT_VERSION = 1;
export const MINUTES_PER_UNIT = 25; // 一顆＝25 分；50 分的顆算兩單位（雙豆）
export const REST_DIVISOR = 5; // 休息＝長度 ÷ 5
export const REST_MIN_MINUTES = 3;

export const DEFAULT_TYPE = { id: 't1', name: '一般', len: 25 };

export function blank() {
  return {
    v: FORMAT_VERSION,
    settings: {
      types: [{ ...DEFAULT_TYPE }],
      typeId: DEFAULT_TYPE.id,
      restMode: 'auto',
      sound: true,
      demo: false, // PWA 的「試玩速度」；這裡當開發期「測試模式」開關（2026-11-02），不另開欄位，格式維持 PWA 七欄
      closeTime: '19:00',
      tilt: true,
    },
    current: null,
    clue: null,
    days: {},
    planted: null,
    lastLine: -1,
    taskId: null, // 目前估的那件事（PWA 在執行期才掛上這欄，正式版從 blank 就有）
  };
}

export function blankDay() {
  return { beans: [], voids: [], tasks: [], closed: false, leaf: false, restOver: 0 };
}

const isObject = (x) => x !== null && typeof x === 'object' && !Array.isArray(x);
const arrayOf = (x) => (Array.isArray(x) ? x : []);
const pick = (value, fallback, type) => (typeof value === type ? value : fallback);

/** settings 這一層：每欄驗型別、不對就用預設；選到的類型不存在就退回第一個。 */
function normalizeSettings(s) {
  const base = blank().settings;
  const types = arrayOf(s.types)
    .filter((t) => isObject(t) && typeof t.id === 'string' && typeof t.name === 'string')
    .map((t) => ({ id: t.id, name: t.name, len: pick(t.len, DEFAULT_TYPE.len, 'number') }));
  const settings = {
    types: types.length ? types : base.types,
    typeId: pick(s.typeId, base.typeId, 'string'),
    restMode: s.restMode === 'self' ? 'self' : 'auto',
    sound: pick(s.sound, base.sound, 'boolean'),
    // 測試模式：開發版照存檔讀；正式 build 一律關（安全標準 C4：正式版不帶試玩速度）
    demo: __DEV__ ? pick(s.demo, base.demo, 'boolean') : false,
    closeTime: pick(s.closeTime, base.closeTime, 'string'),
    tilt: pick(s.tilt, base.tilt, 'boolean'),
  };
  if (!settings.types.some((t) => t.id === settings.typeId)) settings.typeId = settings.types[0].id;
  return settings;
}

/** 一天這一層：六欄補齊；每一顆的 len 之後要進 units()，不是數字會算成 NaN，所以在這裡就補成預設（I2）。 */
function normalizeDay(d) {
  const day = blankDay();
  day.beans = arrayOf(d.beans)
    .filter(isObject)
    .map((b) => ({ ...b, len: pick(b.len, DEFAULT_TYPE.len, 'number') }));
  day.voids = arrayOf(d.voids).filter(isObject);
  day.tasks = arrayOf(d.tasks).filter(isObject);
  day.closed = pick(d.closed, false, 'boolean');
  day.leaf = pick(d.leaf, false, 'boolean');
  day.restOver = pick(d.restOver, 0, 'number');
  return day;
}

const isNumber = (x) => typeof x === 'number' && Number.isFinite(x);
const strings = (x) => arrayOf(x).filter((s) => typeof s === 'string');
const stringOr = (x, fallback) => (typeof x === 'string' ? x : fallback);

/**
 * 進行中那顆：PWA 跟正式版的寫法不一樣，匯入 PWA 檔時要轉（A 組審查員記下、G3 處理）：
 * PWA 延長中是 phase 'flow' → 正式版是 focus＋flowed；PWA 有 'bell' 這一態 → 正式版由 endAt 算，存成 focus；
 * 「我自己決定」的休息 PWA 也有 endAt → 正式版是 null（不自己結束）；notes／pings 缺就補空。
 * 會進算術的欄位（開始、結束時刻、長度）不是數字就整顆不要，回待機（I2）。
 */
function normalizeCurrent(c, settings) {
  if (!isObject(c)) return null;
  if (c.phase === 'focus' || c.phase === 'flow' || c.phase === 'bell') return focusCurrent(c);
  if (c.phase === 'rest') return restCurrent(c, settings);
  return null;
}

function focusCurrent(c) {
  if (!isNumber(c.startedAt) || !isNumber(c.endAt) || !isNumber(c.len)) return null;
  return {
    ...c,
    phase: 'focus',
    flowed: c.phase === 'flow' || c.flowed === true,
    notes: strings(c.notes), // 會直接畫在鈴響頁：手改過的檔塞物件進來會讓 Text 當掉
    pings: strings(c.pings),
    clue: stringOr(c.clue, ''),
    draft: stringOr(c.draft, ''),
  };
}

function restCurrent(c, settings) {
  if (!isNumber(c.restStart)) return null;
  const rest = { ...c, msg: stringOr(c.msg, '') };
  if (settings.restMode === 'self') return { ...rest, endAt: null };
  return isNumber(c.endAt) ? rest : null;
}

/** 把外部讀進來的物件補成完整格式。來源不可信（舊版 PWA、手改過的檔），缺什麼補什麼，型別不對就用預設。 */
export function normalize(raw) {
  if (!isObject(raw) || !isObject(raw.settings) || !isObject(raw.days)) {
    throw new Error('not a douzhang state');
  }
  const days = {};
  for (const [key, d] of Object.entries(raw.days)) {
    if (isObject(d)) days[key] = normalizeDay(d);
  }
  const settings = normalizeSettings(raw.settings);
  return {
    v: FORMAT_VERSION,
    settings,
    current: normalizeCurrent(raw.current, settings),
    clue: isObject(raw.clue) && typeof raw.clue.text === 'string' ? raw.clue : null,
    days,
    planted: isObject(raw.planted) ? raw.planted : null,
    lastLine: pick(raw.lastLine, -1, 'number'),
    taskId: pick(raw.taskId, null, 'string'),
  };
}

/**
 * 讀狀態。永遠不寫檔（最小驚訝）。
 * 回 { state, unreadable }：讀不懂時 state 是空的、unreadable 為 true，原本存的東西原封不動留在那裡，
 * 要不要蓋掉由上層（machine）決定並告訴使用者。
 */
export async function load() {
  let text = null;
  try {
    text = await AsyncStorage.getItem(STORAGE_KEY);
  } catch {
    return { state: blank(), unreadable: true };
  }
  if (text === null || text === undefined || text === '')
    return { state: blank(), unreadable: false };
  try {
    return { state: normalize(JSON.parse(text)), unreadable: false };
  } catch {
    return { state: blank(), unreadable: true };
  }
}

/**
 * 讀備份檔的字（匯入）：只 JSON.parse（I4），要有 settings、days、數字的 v（I1），再補欄位（I2）。
 * 讀不懂就丟例外，呼叫端顯示「這個檔案讀不懂」，資料不動。
 */
export function parseBackup(text) {
  const raw = JSON.parse(text);
  if (!isObject(raw) || typeof raw.v !== 'number') throw new Error('not a douzhang backup');
  return normalize(raw);
}

/**
 * 原封不動讀出存著的字（自動備份用：本機檔讀不懂時，備份的是那份讀不懂的原文，不是空白）。
 * 沒存過回 null；讀取失敗丟例外——「讀不到」不能當成「沒東西要備份」，不然會沒備份就覆蓋（S3，G 審查員）。
 */
export async function readRaw() {
  const text = await AsyncStorage.getItem(STORAGE_KEY);
  return text || null;
}

/** 寫狀態。回 true／false，不丟例外；false 時畫面要顯示 words.saveFailed（S6）。 */
export async function save(state) {
  try {
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    return true;
  } catch {
    return false;
  }
}

/** 本地日期鍵 YYYY-MM-DD，跟 PWA 的 dkey 同規則（本地時區，不是 UTC）。 */
export function dayKey(timestamp = Date.now()) {
  const d = new Date(timestamp);
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${mm}-${dd}`;
}

/** 取某一天，沒有就在 state 上建一個空的（會改到傳入的 state，呼叫端自己決定何時 save）。 */
export function day(state, key = dayKey()) {
  if (!state.days[key]) state.days[key] = blankDay();
  return state.days[key];
}

/** 一顆占幾個單位：25→1、50→2、15→1（四捨五入，最少 1）。豆莢長度與收據都用這個。 */
export function units(len) {
  return Math.max(1, Math.round(len / MINUTES_PER_UNIT));
}

/** 休息幾分鐘：長度 ÷ 5，最少 3。25→5、50→10、15→3。 */
export function restMinutes(len) {
  return Math.max(REST_MIN_MINUTES, Math.round(len / REST_DIVISOR));
}
