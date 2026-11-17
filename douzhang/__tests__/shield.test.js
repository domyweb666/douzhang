// 計時中擋住其他 app（AF1）測試。原生模組換成假的，只看「什麼時候該擋、叫了原生的哪一個、失敗會不會往外丟」。
import { requireOptionalNativeModule } from 'expo';
import { blank } from '../core/store';
import { flow, keep, start, voidBean } from '../core/machine';
import { setShield } from '../core/settings';
import {
  applyShield,
  authorizeShield,
  forgetShield,
  pickShieldApps,
  shieldAvailable,
  shieldCount,
  shouldShield,
} from '../core/shield';

// jest 會把 mock 提到最前面，寫在 import 後面只是給 lint 看。
// 假模組要在工廠裡面建：core/shield.js 一載入就會來拿，那時這個檔的 const 都還沒跑到
jest.mock('expo', () => {
  const native = {
    count: jest.fn(() => 2),
    block: jest.fn(),
    unblock: jest.fn(),
    forget: jest.fn(),
    authorize: jest.fn(() => Promise.resolve(true)),
    pick: jest.fn(() => Promise.resolve(5)),
  };
  return { requireOptionalNativeModule: () => native };
});
const mockNative = requireOptionalNativeModule('AppShield');

const MIN = 60 * 1000;
const T0 = new Date(2026, 10, 17, 9, 0, 0).getTime();
const withClue = () => ({ ...blank(), clue: { text: '把第二節標題改成問句', at: T0 - MIN } });
const shieldOn = () => setShield(withClue(), true);

describe('什麼時候該擋', () => {
  test('預設關；關著的時候計時中也不擋', () => {
    expect(blank().settings.shield).toBe(false);
    expect(shouldShield(start(withClue(), T0), T0 + MIN)).toBe(false);
  });

  test('開著：待機不擋，按開始就擋，一路擋到響之前', () => {
    expect(shouldShield(shieldOn(), T0)).toBe(false);
    const running = start(shieldOn(), T0);
    expect(shouldShield(running, T0)).toBe(true);
    expect(shouldShield(running, T0 + 25 * MIN - 1)).toBe(true);
  });

  test('響了就不擋；再做一下又擋，延長到點再解開', () => {
    const running = start(shieldOn(), T0);
    const rang = T0 + 25 * MIN;
    expect(shouldShield(running, rang)).toBe(false);
    const more = flow(running, rang + MIN, 15);
    expect(shouldShield(more, rang + 2 * MIN)).toBe(true);
    expect(shouldShield(more, rang + 16 * MIN)).toBe(false);
  });

  test('收下後的休息不擋；作廢、停下來都不擋', () => {
    const running = start(shieldOn(), T0);
    const rang = T0 + 25 * MIN;
    expect(shouldShield(keep(running, rang, '下一句'), rang + MIN)).toBe(false);
    expect(shouldShield(voidBean(running, T0 + 10 * MIN), T0 + 10 * MIN)).toBe(false);
    expect(shouldShield(voidBean(running, T0 + MIN), T0 + MIN)).toBe(false);
  });

  test('計時中把開關關掉，當下就不擋', () => {
    const running = start(shieldOn(), T0);
    expect(shouldShield(setShield(running, false), T0 + MIN)).toBe(false);
  });
});

describe('叫原生', () => {
  beforeEach(() => jest.clearAllMocks());

  test('蓋上叫 block、解開叫 unblock；原生丟錯不往外丟', () => {
    expect(shieldAvailable).toBe(true);
    applyShield(true);
    expect(mockNative.block).toHaveBeenCalledTimes(1);
    applyShield(false);
    expect(mockNative.unblock).toHaveBeenCalledTimes(1);
    mockNative.block.mockImplementationOnce(() => {
      throw new Error('boom');
    });
    expect(() => applyShield(true)).not.toThrow();
  });

  test('授權：允許回 true，不允許或出錯都回 false', async () => {
    expect(await authorizeShield()).toBe(true);
    mockNative.authorize.mockResolvedValueOnce(false);
    expect(await authorizeShield()).toBe(false);
    mockNative.authorize.mockRejectedValueOnce(new Error('boom'));
    expect(await authorizeShield()).toBe(false);
  });

  test('選了幾項：開機問一次，選完更新，清空歸零；按鈕的字從詞彙表來', async () => {
    expect(shieldCount()).toBe(2);
    await pickShieldApps();
    expect(mockNative.pick).toHaveBeenCalledWith('取消', '完成');
    expect(shieldCount()).toBe(5);
    forgetShield();
    expect(mockNative.forget).toHaveBeenCalledTimes(1);
    expect(shieldCount()).toBe(0);
  });

  test('選擇畫面開不起來：原本的數字不動', async () => {
    await pickShieldApps();
    mockNative.pick.mockRejectedValueOnce(new Error('boom'));
    await pickShieldApps();
    expect(shieldCount()).toBe(5);
  });
});
