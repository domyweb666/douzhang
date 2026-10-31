// 狀態機測試。名稱是多米讀得懂的中文句子（標準清單 A2）。
import { blank } from '../core/store';
import {
  DEV_TYPE,
  PHASE,
  backFromRest,
  keep,
  phaseOf,
  setDraft,
  settle,
  start,
} from '../core/machine';

const MIN = 60 * 1000;
const T0 = new Date(2026, 10, 1, 9, 0, 0).getTime(); // 2026-11-01 09:00 本地

const withClue = () => ({ ...blank(), clue: { text: '把第二節標題改成問句', at: T0 - MIN } });

describe('第一次', () => {
  test('沒有那句、第一句也空白，按開始不會開始', () => {
    const s = start(blank(), T0, { firstLine: '   ' });
    expect(s.current).toBeNull();
    expect(phaseOf(s, T0)).toBe(PHASE.idle);
  });

  test('第一次寫一句按開始這顆，那句同時成為下一步，直接進計時中', () => {
    const s = start(blank(), T0, { firstLine: '打開讀書筆記，把三個重點各寫一句' });
    expect(s.clue.text).toBe('打開讀書筆記，把三個重點各寫一句');
    expect(s.current.clue).toBe(s.clue.text);
    expect(phaseOf(s, T0)).toBe(PHASE.focus);
  });
});

describe('開始與到點', () => {
  test('開始後 endAt 等於現在加類型長度（一般 25 分）', () => {
    const s = start(withClue(), T0);
    expect(s.current.typeId).toBe('t1');
    expect(s.current.len).toBe(25);
    expect(s.current.endAt).toBe(T0 + 25 * MIN);
    expect(s.current.startedAt).toBe(T0);
  });

  test('開發期測試顆 1 分鐘：endAt 等於現在加 1 分', () => {
    const s = start(withClue(), T0, { typeId: DEV_TYPE.id });
    expect(s.current.len).toBe(1);
    expect(s.current.endAt).toBe(T0 + MIN);
  });

  test('還沒到點是計時中，到點那一刻 phase 變 bell，不用另外存', () => {
    const s = start(withClue(), T0);
    expect(phaseOf(s, T0 + 24 * MIN)).toBe(PHASE.focus);
    expect(phaseOf(s, T0 + 25 * MIN)).toBe(PHASE.bell);
    expect(phaseOf(s, T0 + 60 * MIN)).toBe(PHASE.bell);
  });

  test('待機時開始，那句不變', () => {
    const s = start(withClue(), T0);
    expect(s.clue.text).toBe('把第二節標題改成問句');
  });
});

describe('收下', () => {
  test('收下後那句換成新的、進 rest、endAt 等於現在加休息長度（25 分休 5 分）', () => {
    const now = T0 + 25 * MIN;
    const s = keep(start(withClue(), T0), now, '把第三節也改成問句');
    expect(s.clue.text).toBe('把第三節也改成問句');
    expect(s.current.phase).toBe(PHASE.rest);
    expect(s.current.endAt).toBe(now + 5 * MIN);
    expect(phaseOf(s, now)).toBe(PHASE.rest);
  });

  test('收下的豆子記在開始那一天，帶著那句與長度', () => {
    const s = keep(start(withClue(), T0), T0 + 25 * MIN, '下一句');
    const beans = s.days['2026-11-01'].beans;
    expect(beans).toHaveLength(1);
    expect(beans[0]).toMatchObject({ typeId: 't1', len: 25, clue: '下一句', start: T0 });
  });

  test('空白收下不換那句，但豆子照樣記一顆', () => {
    const s = keep(start(withClue(), T0), T0 + 25 * MIN, '   ');
    expect(s.clue.text).toBe('把第二節標題改成問句');
    expect(s.days['2026-11-01'].beans[0].clue).toBe('');
  });

  test('測試顆收下後休息 3 分（最少 3）', () => {
    const now = T0 + MIN;
    const s = keep(start(withClue(), T0, { typeId: DEV_TYPE.id }), now, 'x');
    expect(s.current.endAt).toBe(now + 3 * MIN);
  });

  test('不在計時中按收下，什麼都不變', () => {
    const idle = withClue();
    expect(keep(idle, T0, 'x')).toBe(idle);
  });
});

describe('休息與回來', () => {
  test('回來後 phase 回 idle，current 清空', () => {
    const s = backFromRest(keep(start(withClue(), T0), T0 + 25 * MIN, 'x'));
    expect(s.current).toBeNull();
    expect(phaseOf(s, T0 + 26 * MIN)).toBe(PHASE.idle);
  });

  test('休息到點沒按也算回待機；settle 會把過期的休息收掉', () => {
    const resting = keep(start(withClue(), T0), T0 + 25 * MIN, 'x');
    const later = T0 + 31 * MIN;
    expect(phaseOf(resting, later)).toBe(PHASE.idle);
    expect(settle(resting, later).current).toBeNull();
    expect(settle(resting, T0 + 27 * MIN)).toBe(resting);
  });
});

describe('重開讀回來', () => {
  test('重開讀回來停在同一態：計時中還沒到點就是計時中，剩餘時間照時間差算', () => {
    const saved = JSON.parse(JSON.stringify(start(withClue(), T0)));
    expect(phaseOf(saved, T0 + 10 * MIN)).toBe(PHASE.focus);
    expect(saved.current.endAt - (T0 + 10 * MIN)).toBe(15 * MIN);
  });

  test('重開時已經過了結束時刻，直接是鈴響', () => {
    const saved = JSON.parse(JSON.stringify(start(withClue(), T0)));
    expect(phaseOf(saved, T0 + 40 * MIN)).toBe(PHASE.bell);
  });
});

describe('響了沒理（A3）', () => {
  test('鈴響後拖超過休息長度才收下，直接回待機不進休息，豆子與那句照記', () => {
    const rang = T0 + 25 * MIN;
    const s = keep(start(withClue(), T0), rang + 5 * MIN, '拖很久才寫的');
    expect(s.current).toBeNull();
    expect(phaseOf(s, rang + 5 * MIN)).toBe(PHASE.idle);
    expect(s.clue.text).toBe('拖很久才寫的');
    expect(s.days['2026-11-01'].beans).toHaveLength(1);
  });

  test('鈴響後在休息長度內收下，照常進休息', () => {
    const rang = T0 + 25 * MIN;
    const s = keep(start(withClue(), T0), rang + 4 * MIN, 'x');
    expect(s.current.phase).toBe(PHASE.rest);
    expect(s.current.endAt).toBe(rang + 4 * MIN + 5 * MIN);
  });

  test('測試顆拖超過 3 分才收下，也是直接待機', () => {
    const rang = T0 + MIN;
    const s = keep(start(withClue(), T0, { typeId: DEV_TYPE.id }), rang + 3 * MIN, 'x');
    expect(s.current).toBeNull();
  });
});

describe('打一半被打斷（A3）', () => {
  test('草稿存進 current，重開讀回來還在', () => {
    const s = setDraft(start(withClue(), T0), '把第三節');
    const saved = JSON.parse(JSON.stringify(s));
    expect(saved.current.draft).toBe('把第三節');
    expect(phaseOf(saved, T0 + 30 * MIN)).toBe(PHASE.bell);
  });

  test('收下後草稿清掉', () => {
    const s = keep(setDraft(start(withClue(), T0), '把第三節'), T0 + 25 * MIN, '把第三節也改');
    expect(s.current.draft).toBeUndefined();
  });

  test('不在計時中（例如休息）存草稿，什麼都不變', () => {
    const resting = keep(start(withClue(), T0), T0 + 25 * MIN, 'x');
    expect(setDraft(resting, 'y')).toBe(resting);
  });
});
