// 畫面冒煙測試（2026-11-17 AG 換核心）：新寫的畫面在手機上還沒開過，這裡至少把每一塊真的渲染一次，
// 抓「執行到才會爆」的錯（少傳的 prop、拼錯的代號、算出 NaN）。好不好看、順不順、排版對不對要在手機上看。
import { act } from 'react';
import { createRoot } from 'test-renderer';
import { DomyThemeProvider } from '@domy/design';
import { douzhangTheme } from '../design/theme';
import { blank, blankDay, dayKey } from '../core/store';
import { PHASE, flow, keep, phaseOf, start } from '../core/machine';
import { VIEW, viewDays } from '../core/calendar';
import { RANGE } from '../core/stats';
import { Timeline } from '../ui/Timeline';
import { MonthGrid } from '../ui/MonthGrid';
import { StatsView } from '../ui/Stats';
import { GrowingTomato } from '../ui/GrowingTomato';
import { TagPickSheet } from '../ui/TagSheets';
import { MoreSheet } from '../ui/FocusSheets';
// 憲法 1 不准測試 import screens（怕測試綁死畫面結構）。這個檔是例外：它的工作就是把整頁渲染一次，只看「畫得出來、該有的字在」
/* eslint-disable no-restricted-imports */
import { Bell } from '../screens/Bell';
import { Rack } from '../screens/Rack';
import { Home } from '../screens/Home';
/* eslint-enable no-restricted-imports */

// 罐子要加速度計、音效與每幀重畫，跟這裡要驗的無關；鍵盤與安全區在測試環境沒有原生那一半
jest.mock('../ui/Jar', () => ({ Jar: () => null }));
// 白噪音半頁會帶進 expo-audio，測試環境沒有原生那一半
jest.mock('expo-audio', () => ({
  createAudioPlayer: jest.fn(),
  setAudioModeAsync: jest.fn(() => Promise.resolve()),
}));
jest.mock(
  'react-native-safe-area-context',
  () => require('react-native-safe-area-context/jest/mock').default,
);

// 畫面裡的計時器（罐子、提示）用假時鐘：畫完就丟，不讓它們在測試結束後還在跑
jest.useFakeTimers();
afterEach(() => jest.clearAllTimers());

const MIN = 60 * 1000;
const at = (d, h, m = 0) => new Date(2026, 10, d, h, m, 0).getTime();
const NOW = at(17, 14, 30);
const bean = (d, h, m, len, typeId, extra = {}) => ({
  t: at(d, h, m) + len * MIN,
  start: at(d, h, m),
  typeId,
  len,
  clue: '',
  notes: [],
  pings: [],
  ...extra,
});

/** 一份有各種情況的資料：兩顆很短又很近的、延長的、有留話的、標籤被刪掉的、作廢、一天超過八顆。 */
function sample() {
  const s = blank();
  s.days['2026-11-17'] = {
    ...blankDay(),
    beans: [
      bean(17, 5, 0, 5, 't1'),
      bean(17, 5, 8, 5, 't1'),
      bean(17, 9, 0, 50, 't2', { clue: '腳本初稿寫到第三段', flow: 15 }),
      bean(17, 11, 0, 30, 't3'),
      bean(17, 13, 0, 45, 'deleted'),
    ],
    voids: [{ t: at(17, 12, 7), typeId: 't1', minute: 7, reason: '訊息', text: '' }],
  };
  s.days['2026-11-16'] = {
    ...blankDay(),
    beans: Array.from({ length: 10 }, (_, i) => bean(16, 8 + i, 0, 25, `t${(i % 5) + 1}`)),
  };
  s.days['2026-11-03'] = { ...blankDay(), beans: [bean(3, 23, 30, 50, 't4')] };
  return { ...s, todayKey: dayKey(NOW) };
}

async function draw(element) {
  const root = createRoot();
  await act(async () => {
    root.render(<DomyThemeProvider theme={douzhangTheme}>{element}</DomyThemeProvider>);
  });
  const out = JSON.stringify(root.container.toJSON());
  await act(async () => {
    root.unmount();
  });
  return out;
}

const noop = () => {};
const actions = new Proxy({}, { get: () => noop });
const zen = { onEnter: noop, initialSheet: null, onInitialSheetOpened: noop };

describe('番茄架', () => {
  test.each([VIEW.day, VIEW.three, VIEW.week])('時間軸 %s 檢視畫得出來，沒有 NaN', async (view) => {
    const s = sample();
    const out = await draw(
      <Timeline state={s} keys={viewDays(view, s.todayKey)} view={view} now={NOW} onOpen={noop} />,
    );
    expect(out).not.toContain('NaN');
    expect(out).toContain('上午 5');
  });

  test('天檢視寫得出標籤、長度、延長與那句；兩顆很近的短番茄各佔一半寬', async () => {
    const s = sample();
    const out = await draw(
      <Timeline state={s} keys={[s.todayKey]} view={VIEW.day} now={NOW} onOpen={noop} />,
    );
    expect(out).toContain('工作・50 分＋15');
    expect(out).toContain('腳本初稿寫到第三段');
    expect(out.match(/"width":"50%"/g)).toHaveLength(2);
  });

  test('沒有番茄的日子時間軸什麼都不畫', async () => {
    const s = sample();
    const out = await draw(
      <Timeline state={s} keys={['2026-11-10']} view={VIEW.day} now={NOW} onOpen={noop} />,
    );
    expect(out).not.toContain('上午');
    expect(out).not.toContain('"children":[{');
  });

  test('月檢視：一天超過八顆寫「+2」', async () => {
    const s = sample();
    const out = await draw(<MonthGrid state={s} monthKey={s.todayKey} onPickDay={noop} />);
    expect(out).toContain('+2');
    expect(out).not.toContain('NaN');
  });

  test.each([RANGE.day, RANGE.week, RANGE.month])('分析 %s 畫得出來，沒有 NaN', async (range) => {
    const s = sample();
    const out = await draw(<StatsView state={s} range={range} selected={s.todayKey} />);
    expect(out).not.toContain('NaN');
    expect(out).toContain('專注');
  });

  test('分析：這一段沒有番茄只寫一句', async () => {
    const s = sample();
    const out = await draw(<StatsView state={s} range={RANGE.day} selected="2026-11-10" />);
    expect(out).toContain('這段時間還沒有番茄。');
  });

  test('整頁：有紀錄時有行事曆／分析的切換；完全沒紀錄時是空狀態', async () => {
    const s = sample();
    const page = await draw(<Rack state={s} now={NOW} onSettings={noop} onBack={noop} />);
    expect(page).toContain('行事曆');
    expect(page).toContain('3 天');
    const empty = { ...blank(), todayKey: dayKey(NOW) };
    const none = await draw(<Rack state={empty} now={NOW} onSettings={noop} onBack={noop} />);
    expect(none).toContain('第一顆響完');
    expect(none).not.toContain('行事曆');
  });
});

describe('主畫面與慶祝畫面', () => {
  const home = (state, now) => (
    <Home
      state={{ ...state, todayKey: dayKey(now) }}
      phase={phaseOf(state, now)}
      now={now}
      jarSeen={{ current: null }}
      actions={actions}
      zen={zen}
    />
  );

  test('待機：選中的標籤與它的長度、開始鈕', async () => {
    const out = await draw(home(sample(), NOW));
    expect(out).toContain('專注・25 分 ›');
    expect(out).toContain('25:00');
    expect(out).toContain('開始・25 分');
    expect(out).toContain('♪ 背景音');
  });

  test('計時中（AH2 番茄就是時鐘）：倒數、標籤、⋯；休息：綠環倒數、回來了', async () => {
    const running = start(sample(), NOW);
    expect(phaseOf(running, NOW + 5 * MIN)).toBe(PHASE.focus);
    const focus = await draw(home(running, NOW + 5 * MIN));
    expect(focus).toContain('20:00');
    expect(focus).toContain('專注・25 分');
    expect(focus).toContain('⋯');
    expect(focus).not.toContain('NaN');
    const rest = await draw(home(keep(running, NOW + 25 * MIN, ''), NOW + 26 * MIN));
    expect(rest).toContain('回來了，開始下一顆');
    expect(rest).toContain('休息');
    expect(rest).not.toContain('NaN');
  });

  test('⋯ 半頁：記一筆（帶筆數）、背景音、聚焦模式、結束這顆', async () => {
    const out = await draw(
      <MoreSheet visible noteCount={2} soundValue="雨" onClose={noop} onPick={noop} />,
    );
    for (const name of ['這一顆', '記一筆', '2', '背景音', '雨', '聚焦模式', '結束這顆'])
      expect(out).toContain(name);
  });

  test('長大的番茄從頭到尾都畫得出來', async () => {
    for (const p of [0, 0.3, 0.6, 1]) {
      const out = await draw(<GrowingTomato progress={p} color="purple" height={200} />);
      expect(out).not.toContain('NaN');
    }
  });

  test('標籤半頁：五個預設標籤加「新標籤」', async () => {
    const s = sample();
    const out = await draw(
      <TagPickSheet visible settings={s.settings} actions={actions} onClose={noop} />,
    );
    for (const name of ['專注', '工作', '閱讀', '學習', '運動', '＋ 新標籤'])
      expect(out).toContain(name);
  });

  test('慶祝畫面：今天第六顆、可以不寫字直接收下、再做 15／30 分；延長過就沒有再做一下', async () => {
    const running = start(sample(), NOW);
    const bell = (state, now) => (
      <Bell
        state={state}
        current={state.current}
        now={now}
        draft=""
        onDraft={noop}
        onKeep={noop}
        onFlow={noop}
      />
    );
    const out = await draw(bell(running, NOW + 25 * MIN));
    expect(out).toContain('熟了，又收下一顆');
    expect(out).toContain('今天收了 6 顆');
    expect(out).toContain('收下，休息一下');
    expect(out).toContain('再做 15 分');
    const flowed = flow(running, NOW + 25 * MIN, 15);
    expect(await draw(bell(flowed, NOW + 41 * MIN))).not.toContain('再做 15 分');
  });
});
