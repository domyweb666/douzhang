// 番茄架行事曆（AG4）與分析（AG5）的計算測試。
import { blank, blankDay } from '../core/store';
import {
  VIEW,
  axisHours,
  dayBlocks,
  hourOfDay,
  monthWeeks,
  reachesToday,
  shiftDay,
  shiftMonth,
  shiftPeriod,
  viewDays,
} from '../core/calendar';
import { RANGE, rangeDays, stats } from '../core/stats';

const MIN = 60 * 1000;
const at = (d, h, m = 0) => new Date(2026, 10, d, h, m, 0).getTime();
/** 一顆番茄：幾號、幾點幾分開始、多長、哪個標籤。 */
const bean = (d, h, m, len, typeId = 't1', extra = {}) => ({
  t: at(d, h, m) + len * MIN,
  start: at(d, h, m),
  typeId,
  len,
  clue: '',
  ...extra,
});
const dayWith = (...beans) => ({ ...blankDay(), beans });
const MIN_HOURS = 28 / 64; // 畫面上最矮 28、一小時 64

describe('畫哪幾天', () => {
  test('天是那一天，3 天是那天與前兩天，週是週一到週日', () => {
    expect(viewDays(VIEW.day, '2026-11-17')).toEqual(['2026-11-17']);
    expect(viewDays(VIEW.three, '2026-11-17')).toEqual(['2026-11-15', '2026-11-16', '2026-11-17']);
    const week = viewDays(VIEW.week, '2026-11-17');
    expect(week[0]).toBe('2026-11-16');
    expect(week[6]).toBe('2026-11-22');
  });

  test('換一段：天動一天、3 天動三天、週動一週、月跳到 1 號；跨月也對', () => {
    expect(shiftDay('2026-11-01', -1)).toBe('2026-10-31');
    expect(shiftPeriod(VIEW.day, '2026-11-17', -1)).toBe('2026-11-16');
    expect(shiftPeriod(VIEW.three, '2026-11-17', -1)).toBe('2026-11-14');
    expect(shiftPeriod(VIEW.week, '2026-11-17', -1)).toBe('2026-11-09');
    expect(shiftPeriod(VIEW.month, '2026-11-17', -1)).toBe('2026-10-01');
    expect(shiftMonth('2026-12-31', 2)).toBe('2027-02-01');
  });

  test('畫面上有今天就不能再往後翻', () => {
    expect(reachesToday(VIEW.day, '2026-11-17', '2026-11-17')).toBe(true);
    expect(reachesToday(VIEW.day, '2026-11-16', '2026-11-17')).toBe(false);
    expect(reachesToday(VIEW.week, '2026-11-16', '2026-11-17')).toBe(true);
    expect(reachesToday(VIEW.week, '2026-11-09', '2026-11-17')).toBe(false);
    expect(reachesToday(VIEW.month, '2026-11-03', '2026-11-17')).toBe(true);
    expect(reachesToday(VIEW.month, '2026-10-03', '2026-11-17')).toBe(false);
  });
});

describe('一天的方塊', () => {
  test('隔得開的各佔整欄，位置是當天第幾小時、高度是幾小時', () => {
    const blocks = dayBlocks(
      dayWith(bean(17, 9, 0, 30), bean(17, 11, 0, 60)),
      '2026-11-17',
      MIN_HOURS,
    );
    expect(blocks.map((b) => [b.top, b.height, b.lane, b.lanes])).toEqual([
      [9, 0.5, 0, 1],
      [11, 1, 0, 1],
    ]);
  });

  test('兩顆 5 分鐘的番茄只差幾分鐘：左右並排、各佔一半，不疊在一起（多米 2026-11-17 回報）', () => {
    const blocks = dayBlocks(
      dayWith(bean(17, 5, 0, 5), bean(17, 5, 8, 5)),
      '2026-11-17',
      MIN_HOURS,
    );
    expect(blocks.map((b) => [b.lane, b.lanes])).toEqual([
      [0, 2],
      [1, 2],
    ]);
    expect(blocks[0].height).toBe(MIN_HOURS); // 再短也畫到最小高度
  });

  test('第三顆在前兩顆都結束後才開始：回到整欄；空出來的欄會被後面的重疊補上', () => {
    const day = dayWith(
      bean(17, 9, 0, 60),
      bean(17, 9, 10, 20),
      bean(17, 9, 40, 20),
      bean(17, 11, 0, 25),
    );
    const blocks = dayBlocks(day, '2026-11-17', MIN_HOURS);
    expect(blocks.map((b) => [b.lane, b.lanes])).toEqual([
      [0, 2],
      [1, 2],
      [1, 2],
      [0, 1],
    ]);
  });

  test('跨過午夜的只畫到當天 24:00；延長的算進長度', () => {
    const late = dayBlocks(dayWith(bean(17, 23, 30, 50)), '2026-11-17', MIN_HOURS)[0];
    expect(late.top + late.height).toBe(24);
    const flowed = dayBlocks(
      dayWith(bean(17, 9, 0, 25, 't1', { flow: 15 })),
      '2026-11-17',
      MIN_HOURS,
    );
    expect(flowed[0].height).toBeCloseTo(40 / 60);
  });

  test('作廢也排進去；沒東西的日子是空的', () => {
    const day = { ...blankDay(), voids: [{ t: at(17, 10, 7), typeId: 't1', minute: 7 }] };
    expect(dayBlocks(day, '2026-11-17', MIN_HOURS)[0].item.kind).toBe('void');
    expect(dayBlocks(undefined, '2026-11-17', MIN_HOURS)).toEqual([]);
  });
});

describe('共用的時間軸', () => {
  test('從最早那顆的整點前一小時，到最晚結束的整點後一小時；幾天取聯集', () => {
    const a = dayBlocks(dayWith(bean(16, 9, 30, 25)), '2026-11-16', MIN_HOURS);
    const b = dayBlocks(dayWith(bean(17, 14, 10, 50)), '2026-11-17', MIN_HOURS);
    expect(axisHours([a, b])).toEqual({ from: 8, to: 16 });
  });

  test('半夜與深夜不會畫出 0 點以前、24 點以後；都沒東西回 null', () => {
    const early = dayBlocks(
      dayWith(bean(17, 0, 10, 25), bean(17, 23, 0, 50)),
      '2026-11-17',
      MIN_HOURS,
    );
    expect(axisHours([early])).toEqual({ from: 0, to: 24 });
    expect(axisHours([[], []])).toBeNull();
  });

  test('現在是當天第幾小時', () => {
    expect(hourOfDay(at(17, 14, 30))).toBe(14.5);
  });
});

describe('月檢視', () => {
  const s = blank();
  s.days['2026-11-03'] = dayWith(bean(3, 9, 0, 25));
  s.days['2026-11-12'] = dayWith(bean(12, 9, 0, 25), bean(12, 10, 0, 50, 't2'));
  s.days['2026-10-30'] = dayWith(bean(30, 9, 0, 25)); // 上個月的，跟 11 月第一週同一列
  const weeks = monthWeeks(s, '2026-11-17');

  test('2026 年 11 月：1 號是星期日，一共六列，每列七格、週一開頭', () => {
    expect(weeks).toHaveLength(6);
    expect(weeks[0].days[6]).toMatchObject({ key: '2026-11-01', inMonth: true });
    expect(weeks[0].days[0]).toMatchObject({ key: '2026-10-26', inMonth: false });
    expect(weeks[5].days[0]).toMatchObject({ key: '2026-11-30', inMonth: true });
  });

  test('沒番茄的週壓扁；有番茄的週不壓；別的月份的番茄不算', () => {
    expect(weeks.map((w) => w.busy)).toEqual([false, true, true, false, false, false]);
    expect(weeks[2].days[3].beans).toHaveLength(2); // 11/12 星期四
    expect(weeks[0].days[4].beans).toEqual([]); // 10/30 在別的月份
  });
});

describe('分析', () => {
  const s = blank();
  s.days['2026-11-16'] = dayWith(bean(16, 9, 0, 25), bean(16, 10, 0, 50, 't2'));
  s.days['2026-11-17'] = dayWith(bean(17, 9, 0, 25, 't1', { flow: 15 }), bean(17, 11, 0, 30, 't3'));

  test('一段包含哪幾天：日一天、週七天、月整個月', () => {
    expect(rangeDays(RANGE.day, '2026-11-17')).toEqual(['2026-11-17']);
    expect(rangeDays(RANGE.week, '2026-11-17')).toHaveLength(7);
    const month = rangeDays(RANGE.month, '2026-11-17');
    expect(month).toHaveLength(30);
    expect(month[0]).toBe('2026-11-01');
    expect(month[29]).toBe('2026-11-30');
  });

  test('一週：總分鐘含延長、幾顆、各標籤由多到少與占比', () => {
    const w = stats(s, rangeDays(RANGE.week, '2026-11-17'));
    expect(w.minutes).toBe(25 + 50 + 40 + 30);
    expect(w.beans).toBe(4);
    expect(w.tags.map((x) => [x.type.name, x.minutes, x.beans])).toEqual([
      ['專注', 65, 2],
      ['工作', 50, 1],
      ['閱讀', 30, 1],
    ]);
    expect(w.tags.reduce((a, x) => a + x.share, 0)).toBeCloseTo(1);
  });

  test('每天一筆：沒番茄的日子是 0、沒有分段；有番茄的照標籤在設定裡的順序', () => {
    const w = stats(s, rangeDays(RANGE.week, '2026-11-17'));
    expect(w.days.map((d) => d.minutes)).toEqual([75, 70, 0, 0, 0, 0, 0]);
    expect(w.days[1].parts.map((p) => [p.type.id, p.minutes])).toEqual([
      ['t1', 40],
      ['t3', 30],
    ]);
    expect(w.days[2].parts).toEqual([]);
  });

  test('標籤被刪掉的舊番茄算在第一個標籤；整段都沒番茄時全部是 0、不會除以 0', () => {
    const gone = blank();
    gone.days['2026-11-17'] = dayWith(bean(17, 9, 0, 25, 'deleted'));
    expect(stats(gone, ['2026-11-17']).tags[0].type.id).toBe('t1');
    const none = stats(blank(), rangeDays(RANGE.week, '2026-11-17'));
    expect(none).toMatchObject({ minutes: 0, beans: 0, tags: [], list: [] });
  });

  test('一天的清單依收下的時間排', () => {
    const d = stats(s, ['2026-11-17']);
    expect(d.list.map((x) => x.type.id)).toEqual(['t1', 't3']);
  });
});
