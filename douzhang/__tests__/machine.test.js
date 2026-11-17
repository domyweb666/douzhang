// 狀態機測試。名稱是多米讀得懂的中文句子（標準清單 A2）。
import { blank, blankDay, normalize } from '../core/store';
import { words } from '../design/words';
import {
  DEV_TYPE,
  PHASE,
  backFromRest,
  canHangLeaf,
  closeDay,
  closeHint,
  flow,
  hangLeaf,
  jot,
  keep,
  markDone,
  phaseOf,
  rackTopRow,
  seePlanted,
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

  test('開發期測試顆 5 秒：endAt 等於現在加 5 秒', () => {
    const s = start(withClue(), T0, { typeId: DEV_TYPE.id });
    expect(s.current.endAt).toBe(T0 + 5000);
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

  test('測試顆收下後休息也只有 5 秒（看掉番茄用，不等 3 分）', () => {
    const now = T0 + 5000;
    const s = keep(start(withClue(), T0, { typeId: DEV_TYPE.id }), now, 'x');
    expect(s.current.endAt).toBe(now + 5000);
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

  test('測試顆拖到剛好 5 秒（等於休息長度）才收下，也是直接待機', () => {
    const rang = T0 + 5000;
    const s = keep(start(withClue(), T0, { typeId: DEV_TYPE.id }), rang + 5000, 'x');
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

  test('作廢這顆：記一筆作廢（第幾分鐘、原因、選填那行），豆子不加，回待機', () => {
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

  test('過了午夜才作廢：記在開始那天', () => {
    const late = new Date(2026, 10, 1, 23, 55, 0).getTime();
    const s = voidBean(start(withClue(), late), late + 8 * MIN);
    expect(s.days['2026-11-01'].voids).toHaveLength(1);
    expect(s.days['2026-11-02']).toBeUndefined();
  });

  test('打開半頁時是「停下來」：過了五分鐘才按也不記', () => {
    const s = voidBean(start(withClue(), T0), T0 + 5 * MIN + 2000, { early: true });
    expect(s.current).toBeNull();
    expect(s.days['2026-11-01']).toBeUndefined();
  });

  test('作廢後那句不變', () => {
    const s = voidBean(start(withClue(), T0), T0 + 10 * MIN, { reason: '卡住' });
    expect(s.clue.text).toBe('把第二節標題改成問句');
  });
});

describe('收工與葉子（F1、F2）', () => {
  const at = (h, m = 0) => new Date(2026, 10, 1, h, m, 0).getTime();
  const NEXT_DAY = at(9) + 24 * 60 * MIN;
  const withBean = () => keep(start(withClue(), at(18)), at(18, 25), '明天寫結尾');

  test('有豆子、過了收工時間（預設 19:00）：待機那行是收工入口；還沒到就沒有', () => {
    expect(closeHint(withBean(), at(19))).toBe('due');
    expect(closeHint(withBean(), at(18, 59))).toBeNull();
  });

  test('今天只有作廢、沒有豆子：過了收工時間也是收工入口', () => {
    const v = voidBean(start(withClue(), at(18)), at(18, 10));
    expect(closeHint(v, at(19))).toBe('due');
  });

  test('今天掛了葉子但還沒收工：那行是「今天掛了一片葉子」', () => {
    const leafOnly = { ...withClue(), days: { '2026-11-01': { ...blankDay(), leaf: true } } };
    expect(closeHint(leafOnly, at(15))).toBe('leaf');
  });

  test('今天沒豆子：到了收工時間也不出現收工入口', () => {
    expect(closeHint(withClue(), at(21))).toBeNull();
  });

  test('收工：今天標成收工、那句種下去、待機那行變「收工了」', () => {
    const s = closeDay(withBean(), at(19, 5), '明天寫結尾');
    expect(s.days['2026-11-01'].closed).toBe(true);
    expect(s.planted).toEqual({ text: '明天寫結尾', day: '2026-11-01', shown: false });
    expect(closeHint(s, at(19, 6))).toBe('closed');
  });

  test('收工時改了明天的第一句：那句換掉；沒改就不換（時間不動）', () => {
    const b = withBean();
    expect(closeDay(b, at(19, 5), '  先列三個重點  ').clue).toEqual({
      text: '先列三個重點',
      at: at(19, 5),
    });
    expect(closeDay(b, at(19, 5), '明天寫結尾').clue).toBe(b.clue);
    expect(closeDay(b, at(19, 5), '').clue).toBe(b.clue);
  });

  test('收工後又收下一顆：那天回到沒收工', () => {
    const closed = closeDay(withBean(), at(19, 5), '');
    const s = keep(start(closed, at(19, 10)), at(19, 35), '再一句');
    expect(s.days['2026-11-01'].closed).toBe(false);
    expect(closeHint(s, at(19, 40))).toBe('due');
  });

  test('隔天第一次在待機看到：種下的那句標成看過並打招呼，第二次不打；當天打開不算', () => {
    const closed = closeDay(backFromRest(withBean()), at(19, 5), '');
    expect(seePlanted(closed, at(22))).toEqual({ state: closed, greet: false });
    const first = seePlanted(closed, NEXT_DAY);
    expect(first.greet).toBe(true);
    expect(first.state.planted.shown).toBe(true);
    expect(seePlanted(first.state, NEXT_DAY)).toEqual({ state: first.state, greet: false });
  });

  test('跨午夜時正在計時：先不標看過；收下新的一句後才標，但不打招呼', () => {
    const closed = closeDay(withBean(), at(19, 5), '');
    const late = new Date(2026, 10, 1, 23, 50, 0).getTime();
    const focusing = start(closed, late);
    expect(seePlanted(focusing, late + 15 * MIN).greet).toBe(false);
    expect(seePlanted(focusing, late + 15 * MIN).state).toBe(focusing);
    const kept = backFromRest(keep(focusing, late + 25 * MIN, '新的一句'));
    const seen = seePlanted(kept, late + 40 * MIN);
    expect(seen.greet).toBe(false);
    expect(seen.state.planted.shown).toBe(true);
  });

  test('今天沒豆子沒作廢：可以掛葉子，掛了算收工', () => {
    const s = hangLeaf(withClue(), at(15));
    expect(s.days['2026-11-01']).toMatchObject({ leaf: true, closed: true, beans: [] });
    expect(closeHint(s, at(15))).toBe('closed');
  });

  test('今天有豆子或作廢：掛不上葉子', () => {
    const b = withBean();
    expect(canHangLeaf(b, at(19))).toBe(false);
    expect(hangLeaf(b, at(19))).toBe(b);
    const v = voidBean(start(withClue(), at(10)), at(10, 10));
    expect(hangLeaf(v, at(11))).toBe(v);
  });

  test('豆棚頂端：有豆子沒收工→收工列；什麼都沒有→葉子列；收工或掛了葉子→沒有', () => {
    expect(rackTopRow(withBean(), at(12))).toBe('close');
    expect(rackTopRow(withClue(), at(12))).toBe('leaf');
    expect(rackTopRow(closeDay(withBean(), at(19), ''), at(19))).toBeNull();
    expect(rackTopRow(hangLeaf(withClue(), at(12)), at(12))).toBeNull();
  });
});

describe('長休息（2026-11-17 設定 A）', () => {
  /** 連續收 n 顆 25 分的，每顆之間休息 5 分就回來；回最後一次收下後的狀態。 */
  const keepMany = (s, n, from = T0) => {
    let t = from;
    for (let i = 0; i < n; i++) {
      if (i) s = backFromRest(s);
      s = keep(start(s, t), t + 25 * MIN, 'x');
      t += 30 * MIN;
    }
    return { s, lastKeep: t - 5 * MIN };
  };

  test('今天第 3 顆收下是 5 分的短休息，第 4 顆收下是 15 分的長休息', () => {
    const third = keepMany(withClue(), 3);
    expect(third.s.current.long).toBe(false);
    expect(third.s.current.endAt).toBe(third.lastKeep + 5 * MIN);
    const fourth = keepMany(withClue(), 4);
    expect(fourth.s.current.long).toBe(true);
    expect(fourth.s.current.endAt).toBe(fourth.lastKeep + 15 * MIN);
  });

  test('作廢的不算顆數：三顆加一次作廢，還不是長休息', () => {
    let { s } = keepMany(withClue(), 3);
    s = voidBean(start(backFromRest(s), T0 + 120 * MIN), T0 + 130 * MIN, { reason: '訊息' });
    s = keep(start(s, T0 + 140 * MIN), T0 + 165 * MIN, 'x');
    expect(s.days['2026-11-01'].beans).toHaveLength(4);
    expect(s.current.long).toBe(true); // 作廢那次沒佔名額，這顆才是第 4 顆
  });

  test('跨日從頭數：昨天收了 3 顆，今天第 1 顆不是長休息', () => {
    const { s } = keepMany(withClue(), 3);
    const tomorrow = T0 + 24 * 60 * MIN;
    const next = keep(start(backFromRest(s), tomorrow), tomorrow + 25 * MIN, 'x');
    expect(next.current.long).toBe(false);
  });

  test('我自己決定的休息沒有長短：第 4 顆也不標長休息、沒有結束時刻', () => {
    const base = withClue();
    base.settings = { ...base.settings, restMode: 'self' };
    const { s } = keepMany(base, 4);
    expect(s.current.long).toBe(false);
    expect(s.current.endAt).toBeNull();
  });

  test('長休息關掉：第 4 顆照短休息', () => {
    const base = withClue();
    base.settings = { ...base.settings, restLongEvery: 0 };
    const { s, lastKeep } = keepMany(base, 4);
    expect(s.current.long).toBe(false);
    expect(s.current.endAt).toBe(lastKeep + 5 * MIN);
  });

  test('響了沒理、拖超過長休息的 15 分才收：直接回待機', () => {
    const { s } = keepMany(withClue(), 3);
    const t = T0 + 120 * MIN;
    const late = keep(start(backFromRest(s), t), t + 25 * MIN + 15 * MIN, 'x');
    expect(late.current).toBeNull();
    const inTime = keep(start(backFromRest(s), t), t + 25 * MIN + 14 * MIN, 'x');
    expect(inTime.current.long).toBe(true);
  });

  test('測試顆輪到長休息：休息還是 5 秒，但標成長休息（數顆數看得到）', () => {
    const { s } = keepMany(withClue(), 3);
    const t = T0 + 120 * MIN;
    const dev = keep(start(backFromRest(s), t, { typeId: DEV_TYPE.id }), t + 5000, 'x');
    expect(dev.current.long).toBe(true);
    expect(dev.current.endAt).toBe(t + 5000 + 5000);
  });
});
