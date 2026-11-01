// 收據計算測試：數字要跟 PWA 原型（index.html openWeek／openReceipt）同一份資料算出來的一樣。
import { blank, blankDay } from '../core/store';
import {
  VERDICT,
  dayReceipt,
  daySum,
  dayTimeline,
  shiftWeek,
  weekDays,
  hasRecord,
  podItems,
  rackWeeks,
  taskRows,
  weekReceipt,
  weekStart,
} from '../core/receipt';

const at = (y, m, d, h = 9) => new Date(y, m - 1, d, h, 0, 0).getTime();

/** 一份手寫的週資料，跟 PWA 同格式。 */
function sample() {
  const s = blank();
  s.settings.types = [
    { id: 't1', name: '一般', len: 25 },
    { id: 't2', name: '寫作', len: 50 },
  ];
  // 週一 2026-10-26：估 2 做 3（估少）；一顆延長
  s.days['2026-10-26'] = {
    ...blankDay(),
    tasks: [{ id: 'k1', name: '腳本', est: 2, typeId: 't1' }],
    beans: [
      { t: at(2026, 10, 26, 9), typeId: 't1', len: 25, clue: 'a', taskId: 'k1', flow: 15 },
      { t: at(2026, 10, 26, 10), typeId: 't1', len: 25, clue: '', taskId: 'k1' },
      { t: at(2026, 10, 26, 11), typeId: 't1', len: 25, clue: 'c', taskId: 'k1' },
    ],
    voids: [{ t: at(2026, 10, 26, 12), typeId: 't1', minute: 7, reason: '訊息', text: '' }],
  };
  // 週三 2026-10-28：寫作 50 分一顆（2 單位）；估 1 做 2（估少）；作廢兩次
  s.days['2026-10-28'] = {
    ...blankDay(),
    tasks: [
      { id: 'k2', name: '備課', est: 1, typeId: 't2' },
      { id: 'k3', name: '第一次', est: 5, typeId: 't2', novel: true },
      { id: 'k4', name: '沒做', est: 2, typeId: 't2' },
    ],
    beans: [{ t: at(2026, 10, 28, 9), typeId: 't2', len: 50, clue: 'd', taskId: 'k2' }],
    voids: [
      { t: at(2026, 10, 28, 10), typeId: 't2', minute: 3, reason: '', text: '' },
      { t: at(2026, 10, 28, 11), typeId: 't2', minute: 20, reason: '訊息', text: '看留言' },
    ],
  };
  // 週五 2026-10-30：葉子
  s.days['2026-10-30'] = { ...blankDay(), leaf: true, closed: true };
  // 下一週的週一 2026-11-02：估 3 做 3（剛好）
  s.days['2026-11-02'] = {
    ...blankDay(),
    tasks: [{ id: 'k5', name: '剪片', est: 3, typeId: 't1' }],
    beans: [1, 2, 3].map((i) => ({
      t: at(2026, 11, 2, 8 + i),
      typeId: 't1',
      len: 25,
      taskId: 'k5',
    })),
  };
  // 空的一天不該出現在豆棚
  s.days['2026-10-27'] = blankDay();
  return s;
}

describe('週與豆棚', () => {
  test('週從週一起算：10/26（一）到 11/1（日）都算 10/26 那週', () => {
    expect(weekStart('2026-10-26')).toBe('2026-10-26');
    expect(weekStart('2026-10-30')).toBe('2026-10-26');
    expect(weekStart('2026-11-01')).toBe('2026-10-26');
    expect(weekStart('2026-11-02')).toBe('2026-11-02');
  });

  test('豆棚只列有豆、有作廢或掛葉子的日子，由新到舊分週；空的一天不出現', () => {
    const weeks = rackWeeks(sample());
    expect(weeks.map((w) => w.weekStart)).toEqual(['2026-11-02', '2026-10-26']);
    expect(weeks[1].days).toEqual(['2026-10-30', '2026-10-28', '2026-10-26']);
    expect(hasRecord(blankDay())).toBe(false);
  });

  test('豆莢上的格子依時間排：50 分那顆是 2 單位，作廢是空心格', () => {
    const items = podItems(sample().days['2026-10-28']);
    expect(items.map((i) => i.kind)).toEqual(['bean', 'void', 'void']);
    expect(items[0].units).toBe(2);
  });
});

describe('一天的收據', () => {
  test('豆與作廢依時間排成一列列，沒留話的顆句子是空字串、延長與雙豆有標記', () => {
    const rows = dayReceipt(sample().days['2026-10-26']);
    expect(rows.map((r) => r.kind)).toEqual(['bean', 'bean', 'bean', 'void']);
    expect(rows[0].flow).toBe(15);
    expect(rows[1].clue).toBe('');
    expect(rows[3]).toMatchObject({ minute: 7, reason: '訊息' });
    expect(dayReceipt(sample().days['2026-10-28'])[0].double).toBe(true);
  });

  test('估算對帳：每件事實際收了幾單位（50 分算 2）', () => {
    const rows = taskRows(sample().days['2026-10-28']);
    expect(rows.map((r) => [r.task.name, r.actual])).toEqual([
      ['備課', 2],
      ['第一次', 0],
      ['沒做', 0],
    ]);
  });
});

describe('一週的收據（照 PWA openWeek）', () => {
  test('10/26 那週：一般 3 格、寫作 2 格；估少 2 次、估多 0、剛好 0；第一次做與沒收過豆的不列入', () => {
    const w = weekReceipt(sample(), '2026-10-26');
    expect(w.byType).toEqual([
      { name: '一般', units: 3 },
      { name: '寫作', units: 2 },
    ]);
    expect([w.under, w.over, w.even]).toEqual([2, 0, 0]);
  });

  test('對帳不到 3 次先不下結論', () => {
    expect(weekReceipt(sample(), '2026-10-26').verdict).toBe(VERDICT.fewData);
  });

  test('作廢分佈依「類型・原因」分組，達 3 次才有那一行', () => {
    const w = weekReceipt(sample(), '2026-10-26');
    expect(w.voids).toEqual([
      { label: '一般・訊息', count: 1 },
      { label: '寫作', count: 1 },
      { label: '寫作・訊息', count: 1 },
    ]);
    expect(w.totalVoids).toBe(3);
    expect(w.voidHint).toBe(true);
    expect(weekReceipt(sample(), '2026-11-02').voidHint).toBe(false);
  });

  test('延長提示要至少 4 顆且一半以上延長；這週 4 顆只有 1 顆延長，不提示', () => {
    expect(weekReceipt(sample(), '2026-10-26').flowHint).toBe(false);
  });

  test('延長提示：4 顆有 3 顆延長就提示；3 顆全延長不到 4 顆不提示', () => {
    const s = blank();
    const bean = (i, flow) => ({ t: i, typeId: 't1', len: 25, flow });
    s.days['2026-10-27'] = {
      ...blankDay(),
      beans: [bean(1, 15), bean(2, 15), bean(3, 30), bean(4, 0)],
    };
    expect(weekReceipt(s, '2026-10-26').flowHint).toBe(true);
    s.days['2026-10-27'] = { ...blankDay(), beans: [bean(1, 15), bean(2, 15), bean(3, 30)] };
    expect(weekReceipt(s, '2026-10-26').flowHint).toBe(false);
  });

  test('11/2 那週：估 3 做 3 剛好 1 次，沒有作廢', () => {
    const w = weekReceipt(sample(), '2026-11-02');
    expect([w.under, w.over, w.even]).toEqual([0, 0, 1]);
    expect(w.totalVoids).toBe(0);
  });

  test('結論方向：估少超過估多兩倍叫估少，反之估多，否則差不多', () => {
    const s = blank();
    const mk = (est, actual) => ({
      ...blankDay(),
      tasks: [{ id: `k${est}${actual}`, name: 'x', est, typeId: 't1' }],
      beans: Array.from({ length: actual }, (_, i) => ({
        t: i,
        typeId: 't1',
        len: 25,
        taskId: `k${est}${actual}`,
      })),
    });
    s.days['2026-10-26'] = mk(1, 3);
    s.days['2026-10-27'] = mk(1, 2);
    s.days['2026-10-28'] = mk(2, 3);
    expect(weekReceipt(s, '2026-10-26').verdict).toBe(VERDICT.under);
    s.days['2026-10-29'] = mk(3, 1);
    s.days['2026-10-30'] = mk(3, 1);
    s.days['2026-10-31'] = mk(3, 1);
    s.days['2026-11-01'] = mk(3, 1);
    expect(weekReceipt(s, '2026-10-26').verdict).toBe(VERDICT.even);
  });
});

describe('番茄架時間軸（U9）', () => {
  test('這週七天從週一排到週日，換週往前往後各七天', () => {
    expect(weekDays('2026-10-26')).toEqual([
      '2026-10-26',
      '2026-10-27',
      '2026-10-28',
      '2026-10-29',
      '2026-10-30',
      '2026-10-31',
      '2026-11-01',
    ]);
    expect(shiftWeek('2026-10-26', 1)).toBe('2026-11-02');
    expect(shiftWeek('2026-10-26', -1)).toBe('2026-10-19');
  });

  test('番茄照開始時刻排，長度含延長；作廢從作廢時刻倒推；範圍前後各多一小時取整點', () => {
    const s = sample();
    const tl = dayTimeline(s.days['2026-10-26']);
    expect(tl.items.map((i) => i.kind)).toEqual(['bean', 'bean', 'bean', 'void']);
    const first = tl.items[0];
    expect(first.start).toBe(at(2026, 10, 26, 9) - 25 * 60000); // 舊資料沒有 start，用收下時刻倒推
    expect(first.end - first.start).toBe((25 + 15) * 60000);
    expect(tl.items[3].start).toBe(at(2026, 10, 26, 12) - 7 * 60000);
    expect(tl.from).toBe(at(2026, 10, 26, 7)); // 第一顆 8:35 開始 → 8 點再往前一小時
    expect(tl.to).toBe(at(2026, 10, 26, 13)); // 最後 12:00 → 12 點整再往後一小時
  });

  test('有 start 的用 start；空的日子、只有葉子的日子沒有時間軸', () => {
    const d = {
      ...blankDay(),
      beans: [{ t: at(2026, 11, 2, 15), start: at(2026, 11, 2, 10), typeId: 't1', len: 25 }],
    };
    expect(dayTimeline(d).items[0].start).toBe(at(2026, 11, 2, 10));
    expect(dayTimeline({ ...blankDay(), leaf: true }).items).toEqual([]);
    expect(dayTimeline(undefined).items).toEqual([]);
  });

  test('一天的小計算番茄顆數與分鐘（含延長）；沒番茄回 null，不寫 0', () => {
    const s = sample();
    expect(daySum(s.days['2026-10-26'])).toEqual({ beans: 3, minutes: 90 });
    expect(daySum(s.days['2026-10-30'])).toBeNull();
  });
});
