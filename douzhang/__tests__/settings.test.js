// 設定與估算測試。
import { blank, normalize } from '../core/store';
import { keep, start } from '../core/machine';
import {
  addType,
  estimate,
  pickTask,
  pickType,
  removeType,
  renameType,
  setCloseTime,
  setRestMode,
  setShield,
  setSound,
  setTilt,
  setTestMode,
  setTypeColor,
  setTypeLen,
  setRestShort,
  setRestLongEvery,
  setRestLongMinutes,
} from '../core/settings';

const MIN = 60 * 1000;
const T0 = new Date(2026, 10, 1, 9, 0, 0).getTime();
const withClue = () => ({ ...blank(), clue: { text: '那句', at: T0 - MIN } });

describe('任務類型（C1）', () => {
  test('加一種：多一列「新類型」，長度 15 分，選中的不變', () => {
    const s = addType(blank(), T0);
    expect(s.settings.types).toHaveLength(2);
    expect(s.settings.types[1]).toEqual({
      id: `t${T0}`,
      name: '新類型',
      len: 15,
      color: 'orange', // 第一個還沒人用的番茄色
    });
    expect(s.settings.typeId).toBe('t1');
  });

  test('改名最多 20 字，空白變「未命名」', () => {
    const s = renameType(blank(), 't1', '  寫作  ');
    expect(s.settings.types[0].name).toBe('寫作');
    expect(renameType(blank(), 't1', '').settings.types[0].name).toBe('未命名');
    expect(renameType(blank(), 't1', '一'.repeat(30)).settings.types[0].name).toHaveLength(20);
  });

  test('長度選刻度上的值會改；刻度外的值不改', () => {
    expect(setTypeLen(blank(), 't1', 50).settings.types[0].len).toBe(50);
    const s = blank();
    expect(setTypeLen(s, 't1', 37)).toBe(s);
  });

  test('選類型後，下一顆的長度跟著變', () => {
    const s = pickType(setTypeLen(addType(withClue(), T0), `t${T0}`, 50), `t${T0}`);
    expect(s.settings.typeId).toBe(`t${T0}`);
    expect(start(s, T0).current.len).toBe(50);
  });

  test('選不存在的類型什麼都不變', () => {
    const s = blank();
    expect(pickType(s, 'nope')).toBe(s);
  });

  test('只剩一種時不能刪；刪掉選中的那種就退回第一個', () => {
    const one = blank();
    expect(removeType(one, 't1')).toBe(one);
    const two = pickType(addType(blank(), T0), `t${T0}`);
    const s = removeType(two, `t${T0}`);
    expect(s.settings.types).toHaveLength(1);
    expect(s.settings.typeId).toBe('t1');
  });
});

describe('節奏、提醒、手感（G1）', () => {
  test('休息怎麼算只有 auto／self 兩種', () => {
    expect(setRestMode(blank(), 'self').settings.restMode).toBe('self');
    expect(setRestMode(blank(), 'whatever').settings.restMode).toBe('auto');
  });

  test('短休息、長休息只收刻度上的值（設定 A）', () => {
    expect(setRestShort(blank(), 10).settings.restShort).toBe(10);
    expect(setRestShort(setRestShort(blank(), 10), 'auto').settings.restShort).toBe('auto');
    expect(setRestShort(blank(), 7).settings.restShort).toBe('auto');
    expect(setRestLongEvery(blank(), 0).settings.restLongEvery).toBe(0);
    expect(setRestLongEvery(blank(), 6).settings.restLongEvery).toBe(4);
    expect(setRestLongMinutes(blank(), 30).settings.restLongMinutes).toBe(30);
    expect(setRestLongMinutes(blank(), 25).settings.restLongMinutes).toBe(15);
  });

  test('收工時間、聲音、傾斜各改各的', () => {
    const s = setTilt(setSound(setCloseTime(blank(), '21:00'), false), false);
    expect(s.settings.closeTime).toBe('21:00');
    expect(s.settings.sound).toBe(false);
    expect(s.settings.tilt).toBe(false);
  });

  test('擋 app 開關：開、關，存檔讀回來還在；不是布林的值當關（AF1）', () => {
    const on = setShield(blank(), true);
    expect(on.settings.shield).toBe(true);
    expect(normalize(JSON.parse(JSON.stringify(on))).settings.shield).toBe(true);
    expect(setShield(on, false).settings.shield).toBe(false);
    const odd = { ...blank(), settings: { ...blank().settings, shield: 'yes' } };
    expect(normalize(odd).settings.shield).toBe(false);
  });

  test('收工時間只能選刻度上的整點；刻度外的值不改', () => {
    const s = blank();
    expect(setCloseTime(s, '21:30')).toBe(s);
    expect(setCloseTime(s, 'x')).toBe(s);
  });
});

describe('估幾顆（C2）', () => {
  test('填名字與顆數：寫進今天的 tasks，成為目前那件事', () => {
    const s = estimate(withClue(), T0, { name: '腳本第 12 集', est: 3 });
    const task = s.days['2026-11-01'].tasks[0];
    expect(task).toMatchObject({ name: '腳本第 12 集', est: 3, typeId: 't1' });
    expect(s.taskId).toBe(task.id);
  });

  test('之後收下的豆掛在那件事下', () => {
    const s = keep(start(estimate(withClue(), T0, { name: 'x', est: 2 }), T0), T0 + 25 * MIN, 'y');
    expect(s.days['2026-11-01'].beans[0].taskId).toBe(`k${T0}`);
  });

  test('沒名字或顆數不在 1 到 7 之間，不記', () => {
    const s = withClue();
    expect(estimate(s, T0, { name: '', est: 2 })).toBe(s);
    expect(estimate(s, T0, { name: 'x', est: 0 })).toBe(s);
    expect(estimate(s, T0, { name: 'x', est: 8 })).toBe(s);
    expect(estimate(s, T0, { name: 'x', est: 2.5 })).toBe(s);
  });

  test('隔天開始的顆不掛昨天的任務', () => {
    const s = estimate(withClue(), T0, { name: 'x', est: 2 });
    const tomorrow = T0 + 24 * 60 * MIN;
    expect(start(s, tomorrow).current.taskId).toBeNull();
  });

  test('只能換成今天估過的事；昨天的或不存在的不換', () => {
    const s = estimate(withClue(), T0, { name: 'x', est: 2 });
    const off = pickTask(s, T0, null);
    expect(pickTask(off, T0, 'nope')).toBe(off);
    expect(pickTask(off, T0 + 24 * 60 * MIN, `k${T0}`)).toBe(off);
    expect(pickTask(off, T0, `k${T0}`).taskId).toBe(`k${T0}`);
  });

  test('換成不掛任務後，收下的豆 taskId 是空的', () => {
    const s = keep(
      start(pickTask(estimate(withClue(), T0, { name: 'x', est: 2 }), T0, null), T0),
      T0 + 25 * MIN,
      'y',
    );
    expect(s.days['2026-11-01'].beans[0].taskId).toBeNull();
  });

  test('目前那件事重開經 normalize 還在', () => {
    const s = estimate(withClue(), T0, { name: 'x', est: 2 });
    expect(normalize(JSON.parse(JSON.stringify(s))).taskId).toBe(`k${T0}`);
  });
});

describe('測試模式（開發期開關）', () => {
  test('預設關；開了存進設定；舊檔沒有這欄讀成關', () => {
    expect(blank().settings.demo).toBe(false);
    expect(setTestMode(blank(), true).settings.demo).toBe(true); // 存在 PWA 的 demo 欄，不多開欄位
    const old = blank();
    delete old.settings.demo;
    expect(normalize(JSON.parse(JSON.stringify(old))).settings.demo).toBe(false);
  });
});

describe('番茄色（W1）', () => {
  test('舊檔沒有顏色依序分配；換色只收五色之一', () => {
    const s = normalize({
      settings: {
        types: [
          { id: 'a', name: '一', len: 25 },
          { id: 'b', name: '二', len: 50 },
        ],
      },
      days: {},
    });
    expect(s.settings.types.map((t) => t.color)).toEqual(['red', 'orange']);
    expect(setTypeColor(s, 'b', 'pink').settings.types[1].color).toBe('pink');
    expect(setTypeColor(s, 'b', 'blue')).toBe(s);
  });
});
