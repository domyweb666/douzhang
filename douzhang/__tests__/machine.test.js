// 狀態機測試。名稱是多米讀得懂的中文句子（標準清單 A2）。
import { blank, normalize } from '../core/store';
import { words } from '../design/words';
import {
  DEV_TYPE,
  PHASE,
  backFromRest,
  flow,
  jot,
  keep,
  markDone,
  phaseOf,
  setDraft,
  settle,
  start,
  voidBean,
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

  test('測試顆拖到剛好 3 分（等於休息長度）才收下，也是直接待機', () => {
    const rang = T0 + MIN;
    const s = keep(start(withClue(), T0, { typeId: DEV_TYPE.id }), rang + 3 * MIN, 'x');
    expect(s.current).toBeNull();
  });
});

describe('打一半被打斷（A3）', () => {
  test('草稿存進 current，重開經 normalize 讀回來還在', () => {
    const s = setDraft(start(withClue(), T0), '把第三節');
    const saved = normalize(JSON.parse(JSON.stringify(s)));
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

describe('再做一下（A5）', () => {
  test('鈴響後再做 15 分：結束時刻變成現在加 15 分，這顆標記已延長', () => {
    const rang = T0 + 25 * MIN;
    const s = flow(start(withClue(), T0), rang + MIN, 15);
    expect(s.current.endAt).toBe(rang + MIN + 15 * MIN);
    expect(s.current.flowed).toBe(true);
    expect(s.current.flowMin).toBe(15);
    expect(phaseOf(s, rang + 2 * MIN)).toBe(PHASE.focus);
  });

  test('一顆只能再做一次：第二次按什麼都不變', () => {
    const rang = T0 + 25 * MIN;
    const once = flow(start(withClue(), T0), rang, 15);
    const again = flow(once, rang + 15 * MIN, 30);
    expect(again).toBe(once);
  });

  test('還沒響就不能再做', () => {
    const s = start(withClue(), T0);
    expect(flow(s, T0 + 10 * MIN, 15)).toBe(s);
  });

  test('再做過的顆收下時，豆子記 flow 等於延長的分鐘，長度仍是原本的 25', () => {
    const rang = T0 + 25 * MIN;
    const s = keep(flow(start(withClue(), T0), rang, 30), rang + 30 * MIN, '下一句');
    const bean = s.days['2026-11-01'].beans[0];
    expect(bean.flow).toBe(30);
    expect(bean.len).toBe(25);
  });

  test('沒再做過的顆收下時 flow 是 0', () => {
    const s = keep(start(withClue(), T0), T0 + 25 * MIN, 'x');
    expect(s.days['2026-11-01'].beans[0].flow).toBe(0);
  });
});

describe('休息（A6）', () => {
  const selfMode = () => {
    const s = withClue();
    s.settings = { ...s.settings, restMode: 'self' };
    return s;
  };

  test('到點提醒模式：休息有結束時刻，到點自己回待機（A2 不變）', () => {
    const s = keep(start(withClue(), T0), T0 + 25 * MIN, 'x');
    expect(s.current.endAt).toBe(T0 + 30 * MIN);
    expect(phaseOf(s, T0 + 31 * MIN)).toBe(PHASE.idle);
  });

  test('我自己決定模式：休息沒有結束時刻，放一小時還是休息，只有按回來才結束', () => {
    const s = keep(start(selfMode(), T0), T0 + 25 * MIN, 'x');
    expect(s.current.endAt).toBeNull();
    expect(phaseOf(s, T0 + 85 * MIN)).toBe(PHASE.rest);
    expect(settle(s, T0 + 85 * MIN)).toBe(s);
    expect(backFromRest(s).current).toBeNull();
  });

  test('我自己決定模式重開經 normalize 讀回來，還是休息', () => {
    const s = keep(start(selfMode(), T0), T0 + 25 * MIN, 'x');
    const saved = normalize(JSON.parse(JSON.stringify(s)));
    expect(phaseOf(saved, T0 + 85 * MIN)).toBe(PHASE.rest);
  });

  test('收下後那句從 24 句裡抽，記進 lastLine', () => {
    const s = keep(start(withClue(), T0), T0 + 25 * MIN, 'x');
    expect(words.restLines).toContain(s.current.msg);
    expect(words.restLines[s.lastLine]).toBe(s.current.msg);
  });

  test('抽到跟上一次同一句時改抽下一句，連續兩顆不會同句（亂數固定成一定撞到）', () => {
    const spy = jest.spyOn(Math, 'random').mockReturnValue(0.5); // 24 句 → 永遠抽到第 12 句
    const first = keep(start(withClue(), T0), T0 + 25 * MIN, 'x');
    expect(first.lastLine).toBe(12);
    const second = keep(start(backFromRest(first), T0), T0 + 25 * MIN, 'x');
    expect(second.lastLine).toBe(13);
    expect(second.current.msg).not.toBe(first.current.msg);
    spy.mockRestore();
  });
});

describe('記一筆（B1）', () => {
  test('計時中記一個念頭，推進這顆的 notes，倒數的結束時刻不變', () => {
    const s0 = start(withClue(), T0);
    const s = jot(s0, 'notes', '要回信給出版社');
    expect(s.current.notes).toEqual(['要回信給出版社']);
    expect(s.current.endAt).toBe(s0.current.endAt);
  });

  test('有人找記進 pings，跟念頭分開', () => {
    const s = jot(jot(start(withClue(), T0), 'pings', '小美：下午的會'), 'notes', 'x');
    expect(s.current.pings).toEqual(['小美：下午的會']);
    expect(s.current.notes).toEqual(['x']);
  });

  test('空白不記；不在計時中不記', () => {
    const s = start(withClue(), T0);
    expect(jot(s, 'notes', '   ')).toBe(s);
    const idle = withClue();
    expect(jot(idle, 'notes', 'x')).toBe(idle);
  });

  test('記的念頭跟著豆子進帳', () => {
    const s = keep(jot(start(withClue(), T0), 'notes', 'a'), T0 + 25 * MIN, 'x');
    expect(s.days['2026-11-01'].beans[0].notes).toEqual(['a']);
  });
});

describe('結束這顆（B2）', () => {
  test('提早做完了：標記 done，倒數照常到點才響', () => {
    const s = markDone(start(withClue(), T0));
    expect(s.current.done).toBe(true);
    expect(phaseOf(s, T0 + 10 * MIN)).toBe(PHASE.focus);
    expect(phaseOf(s, T0 + 25 * MIN)).toBe(PHASE.bell);
  });

  test('作廢這顆：開始那天記一筆作廢（第幾分鐘、原因、選填那行），豆子不加，回待機', () => {
    const s = voidBean(start(withClue(), T0), T0 + 7 * MIN + 30 * 1000, {
      reason: '訊息',
      text: '去看留言',
    });
    expect(s.current).toBeNull();
    const d = s.days['2026-11-01'];
    expect(d.beans).toHaveLength(0);
    expect(d.voids).toHaveLength(1);
    expect(d.voids[0]).toMatchObject({ typeId: 't1', minute: 7, reason: '訊息', text: '去看留言' });
  });

  test('開始不到五分鐘就停下來：什麼都不記，回待機', () => {
    const s = voidBean(start(withClue(), T0), T0 + 4 * MIN);
    expect(s.current).toBeNull();
    expect(s.days['2026-11-01']).toBeUndefined();
  });

  test('剛好五分鐘算作廢，會記一筆', () => {
    const s = voidBean(start(withClue(), T0), T0 + 5 * MIN);
    expect(s.days['2026-11-01'].voids).toHaveLength(1);
  });

  test('作廢後那句不變', () => {
    const s = voidBean(start(withClue(), T0), T0 + 10 * MIN, { reason: '卡住' });
    expect(s.clue.text).toBe('把第二節標題改成問句');
  });
});
