// 資料層測試。測試名稱寫成多米讀得懂的中文句子（標準清單 A1）。
import fs from 'fs';
import path from 'path';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  STORAGE_KEY,
  blank,
  normalize,
  load,
  save,
  day,
  dayKey,
  units,
  restMinutes,
} from '../core/store';

jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock'),
);

beforeEach(async () => {
  await AsyncStorage.clear();
});

describe('全新安裝', () => {
  test('全新安裝讀出來是空的，類型只有一般 25 分', async () => {
    const { state, unreadable } = await load();
    expect(unreadable).toBe(false);
    expect(state.settings.types).toEqual([{ id: 't1', name: '一般', len: 25 }]);
    expect(state.settings.typeId).toBe('t1');
    expect(state.clue).toBeNull();
    expect(state.days).toEqual({});
  });

  test('空的狀態檔跟 PWA 的 blank() 欄位一樣多、一樣名', () => {
    expect(Object.keys(blank()).sort()).toEqual(
      ['clue', 'current', 'days', 'lastLine', 'planted', 'settings', 'v'].sort(),
    );
    expect(Object.keys(blank().settings).sort()).toEqual(
      ['closeTime', 'demo', 'restMode', 'sound', 'tilt', 'typeId', 'types'].sort(),
    );
  });
});

describe('存與讀', () => {
  test('存一句再讀回來一模一樣', async () => {
    const s = blank();
    s.clue = { text: '把第二節標題改成問句', at: 1730419200000 };
    day(s, '2026-11-01').beans.push({ t: 1, typeId: 't1', len: 25, clue: s.clue.text });
    expect(await save(s)).toBe(true);
    const { state } = await load();
    expect(state.clue).toEqual(s.clue);
    expect(state.days['2026-11-01'].beans).toHaveLength(1);
  });

  test('讀取本身不會寫檔', async () => {
    await load();
    expect(await AsyncStorage.getItem(STORAGE_KEY)).toBeNull();
  });

  test('壞掉的 JSON 讀不懂時，原本的資料還在（沒被蓋掉），而且會告訴上層讀不懂', async () => {
    await AsyncStorage.setItem(STORAGE_KEY, '{這不是 JSON');
    const { state, unreadable } = await load();
    expect(unreadable).toBe(true);
    expect(state).toEqual(blank());
    expect(await AsyncStorage.getItem(STORAGE_KEY)).toBe('{這不是 JSON');
  });

  test('是 JSON 但不是豆帳的檔，一樣當讀不懂，原本的資料還在', async () => {
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify({ hello: 'world' }));
    const { unreadable } = await load();
    expect(unreadable).toBe(true);
    expect(await AsyncStorage.getItem(STORAGE_KEY)).toBe(JSON.stringify({ hello: 'world' }));
  });

  test('存不進去時回 false，不會把 app 弄當', async () => {
    const original = AsyncStorage.setItem;
    AsyncStorage.setItem = jest.fn(() => Promise.reject(new Error('disk full')));
    expect(await save(blank())).toBe(false);
    AsyncStorage.setItem = original;
  });
});

describe('PWA 舊檔', () => {
  test('PWA 舊檔少了 leaf、restOver 欄位，讀進來會補成預設', () => {
    const old = {
      v: 1,
      settings: { types: [{ id: 't1', name: '一般', len: 25 }], typeId: 't1' },
      days: { '2026-10-30': { beans: [{ t: 1, len: 25 }], voids: [] } },
    };
    const s = normalize(old);
    expect(s.days['2026-10-30'].leaf).toBe(false);
    expect(s.days['2026-10-30'].restOver).toBe(0);
    expect(s.days['2026-10-30'].tasks).toEqual([]);
    expect(s.days['2026-10-30'].closed).toBe(false);
    expect(s.settings.closeTime).toBe('19:00');
    expect(s.settings.sound).toBe(true);
    expect(s.clue).toBeNull();
  });

  test('舊檔的試玩速度 demo 不帶進正式版', () => {
    const s = normalize({ settings: { demo: true }, days: {} });
    expect(s.settings.demo).toBe(false);
  });

  test('舊檔選的類型已經不存在時，退回第一個類型', () => {
    const s = normalize({
      settings: { types: [{ id: 'tX', name: '寫作', len: 50 }], typeId: 'gone' },
      days: {},
    });
    expect(s.settings.typeId).toBe('tX');
  });

  test('欄位型別不對（字串放到數字欄）時用預設，不信任外部型別', () => {
    const s = normalize({
      settings: { types: [{ id: 't1', name: '一般', len: '25' }], closeTime: 1900 },
      days: { '2026-10-30': { beans: 'not an array', restOver: 'x' } },
    });
    expect(s.settings.types[0].len).toBe(25);
    expect(s.settings.closeTime).toBe('19:00');
    expect(s.days['2026-10-30'].beans).toEqual([]);
    expect(s.days['2026-10-30'].restOver).toBe(0);
  });
});

describe('算法照 PWA', () => {
  test('50 分的顆算 2 單位、25 分算 1、15 分算 1', () => {
    expect(units(50)).toBe(2);
    expect(units(25)).toBe(1);
    expect(units(15)).toBe(1);
  });

  test('休息長度：25 分休 5、50 分休 10、15 分休 3（最少 3）', () => {
    expect(restMinutes(25)).toBe(5);
    expect(restMinutes(50)).toBe(10);
    expect(restMinutes(15)).toBe(3);
  });

  test('日期鍵用本地日期，格式 YYYY-MM-DD', () => {
    const noon = new Date(2026, 10, 1, 12, 0, 0).getTime(); // 2026-11-01 本地中午
    expect(dayKey(noon)).toBe('2026-11-01');
  });

  test('取某一天時沒有就建空的，而且是同一個物件（之後往裡面推豆子會留住）', () => {
    const s = blank();
    const d = day(s, '2026-11-01');
    d.beans.push({ t: 1, len: 25 });
    expect(s.days['2026-11-01'].beans).toHaveLength(1);
    expect(day(s, '2026-11-01')).toBe(d);
  });
});

// 多米把 PWA 設定頁匯出的 豆帳備份-*.json 放到 __tests__/fixtures/pwa-export.json 就會多測這條；沒放就跳過。
const fixturePath = path.join(__dirname, 'fixtures', 'pwa-export.json');
if (fs.existsSync(fixturePath)) {
  const raw = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
  const s = normalize(raw);
  const dayCount = Object.keys(s.days).length;
  const beanCount = Object.values(s.days).reduce((n, d) => n + d.beans.length, 0);
  test(`多米的 PWA 備份讀得進來：${dayCount} 天、${beanCount} 顆`, () => {
    expect(dayCount).toBeGreaterThan(0);
    expect(s.settings.types.length).toBeGreaterThan(0);
  });
} else {
  test.skip('多米的 PWA 備份讀得進來（還沒放 fixtures/pwa-export.json，跳過）', () => {});
}
