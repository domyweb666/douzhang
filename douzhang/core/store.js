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
      demo: false,
      closeTime: '19:00',
      tilt: true,
    },
    current: null,
    clue: null,
    days: {},
    planted: null,
    lastLine: -1,
  };
}

export function blankDay() {
  return { beans: [], voids: [], tasks: [], closed: false, leaf: false, restOver: 0 };
}

const isObject = (x) => x !== null && typeof x === 'object' && !Array.isArray(x);
const arrayOf = (x) => (Array.isArray(x) ? x : []);
const pick = (value, fallback, type) => (typeof value === type ? value : fallback);

/** 把外部讀進來的物件補成完整格式。來源不可信（舊版 PWA、手改過的檔），缺什麼補什麼，型別不對就用預設。 */
export function normalize(raw) {
  if (!isObject(raw) || !isObject(raw.settings) || !isObject(raw.days)) {
    throw new Error('not a douzhang state');
  }
  const base = blank();
  const s = raw.settings;
  const types = arrayOf(s.types)
    .filter((t) => isObject(t) && typeof t.id === 'string' && typeof t.name === 'string')
    .map((t) => ({ id: t.id, name: t.name, len: pick(t.len, DEFAULT_TYPE.len, 'number') }));
  const settings = {
    types: types.length ? types : base.settings.types,
    typeId: pick(s.typeId, base.settings.typeId, 'string'),
    restMode: s.restMode === 'self' ? 'self' : 'auto',
    sound: pick(s.sound, base.settings.sound, 'boolean'),
    demo: false, // 正式版沒有試玩速度，不管舊檔寫什麼
    closeTime: pick(s.closeTime, base.settings.closeTime, 'string'),
    tilt: pick(s.tilt, base.settings.tilt, 'boolean'),
  };
  if (!settings.types.some((t) => t.id === settings.typeId)) settings.typeId = settings.types[0].id;

  const days = {};
  for (const [key, d] of Object.entries(raw.days)) {
    if (!isObject(d)) continue;
    const day = blankDay();
    day.beans = arrayOf(d.beans).filter(isObject);
    day.voids = arrayOf(d.voids).filter(isObject);
    day.tasks = arrayOf(d.tasks).filter(isObject);
    day.closed = pick(d.closed, false, 'boolean');
    day.leaf = pick(d.leaf, false, 'boolean');
    day.restOver = pick(d.restOver, 0, 'number');
    days[key] = day;
  }

  return {
    v: FORMAT_VERSION,
    settings,
    current: isObject(raw.current) ? raw.current : null,
    clue: isObject(raw.clue) && typeof raw.clue.text === 'string' ? raw.clue : null,
    days,
    planted: isObject(raw.planted) ? raw.planted : null,
    lastLine: pick(raw.lastLine, -1, 'number'),
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
