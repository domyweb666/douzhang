// 番茄火柴人元件測試：畫得出來、play 才播、播完回報一次、減少動態不播。好不好看與順不順要在手機上看。
import { act } from 'react';
import { AccessibilityInfo } from 'react-native';
import { createRoot } from 'test-renderer';
import { DomyThemeProvider } from '@domy/design';
import { douzhangTheme } from '../design/theme';
import { Token } from '../design/Tokens';
import { Mascot } from '../ui/Mascot';

const M = Token.motion.mascot;

async function mount(props) {
  const root = createRoot();
  const show = (next) =>
    act(async () => {
      root.render(
        <DomyThemeProvider theme={douzhangTheme}>
          <Mascot height={Token.shape.mascotHeight} {...next} />
        </DomyThemeProvider>,
      );
    });
  await show(props);
  return { root, show };
}
const advance = (ms) =>
  act(async () => {
    jest.advanceTimersByTime(ms);
  });
const shape = (root) => JSON.stringify(root.container.toJSON());

beforeEach(() => jest.useFakeTimers());
afterEach(() => {
  jest.useRealTimers();
  jest.restoreAllMocks();
});

test('沒叫它播就站著：畫得出來，時間過了也不重畫、不回報', async () => {
  const onDone = jest.fn();
  const { root } = await mount({ action: 'cheer', play: false, onDone });
  const before = shape(root);
  expect(before).toContain('RNSVG'); // 真的畫出 SVG 節點
  await advance(3000);
  expect(shape(root)).toBe(before);
  expect(onDone).not.toHaveBeenCalled();
});

test('play 變成 true：中途姿勢會變，播完回到站姿並回報一次', async () => {
  const onDone = jest.fn();
  const { root, show } = await mount({ action: 'cheer', play: false, onDone });
  const standing = shape(root);
  await show({ action: 'cheer', play: true, onDone });
  await advance(M.cheerMs / 2);
  expect(shape(root)).not.toBe(standing);
  expect(onDone).not.toHaveBeenCalled();
  await advance(M.cheerMs + M.blendMs);
  expect(shape(root)).toBe(standing);
  expect(onDone).toHaveBeenCalledTimes(1);
  await advance(3000); // play 還是 true 也不重播
  expect(onDone).toHaveBeenCalledTimes(1);
});

test('減少動態：不播，姿勢不變，照樣回報一次', async () => {
  jest.spyOn(AccessibilityInfo, 'isReduceMotionEnabled').mockResolvedValue(true);
  const onDone = jest.fn();
  const { root, show } = await mount({ action: 'bow', play: false, onDone });
  const standing = shape(root);
  await show({ action: 'bow', play: true, onDone });
  await advance(M.bowMs / 2);
  expect(shape(root)).toBe(standing);
  expect(onDone).toHaveBeenCalledTimes(1);
});
