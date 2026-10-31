// 通知測試。expo-notifications 換成假的，只看「排了什麼、什麼順序、問不問」。
import * as Notifications from 'expo-notifications';
import { blank } from '../core/store';
import { keep, start } from '../core/machine';
import { askPermissionOnce, planned, sync } from '../core/notify';

// jest 會把 mock 提到最前面，寫在 import 後面只是給 lint 看
jest.mock('expo-notifications', () => ({
  setNotificationHandler: jest.fn(),
  getPermissionsAsync: jest.fn(),
  requestPermissionsAsync: jest.fn(),
  cancelAllScheduledNotificationsAsync: jest.fn(() => Promise.resolve()),
  scheduleNotificationAsync: jest.fn(() => Promise.resolve('id')),
  SchedulableTriggerInputTypes: { DATE: 'date' },
}));

const MIN = 60 * 1000;
const T0 = new Date(2026, 10, 1, 9, 0, 0).getTime();
const withClue = () => ({ ...blank(), clue: { text: '把第二節標題改成問句', at: T0 - MIN } });

beforeEach(() => jest.clearAllMocks());

describe('該排什麼', () => {
  test('計時中排一則到點通知，時刻等於結束時刻，文案固定不含那句', () => {
    const s = start(withClue(), T0);
    const list = planned(s, T0 + MIN);
    expect(list).toEqual([{ title: '響了。', body: '寫一行給下一顆的自己。', at: T0 + 25 * MIN }]);
    expect(JSON.stringify(list)).not.toContain('把第二節');
  });

  test('休息中（到點提醒）排一則休息完了，時刻等於休息結束時刻', () => {
    const s = keep(start(withClue(), T0), T0 + 25 * MIN, '下一句');
    expect(planned(s, T0 + 26 * MIN)).toEqual([
      { title: '休息完了', body: '回來了，開始下一顆', at: T0 + 30 * MIN },
    ]);
  });

  test('待機與鈴響頁（到點已過）什麼都不排', () => {
    expect(planned(withClue(), T0)).toEqual([]);
    const rang = start(withClue(), T0);
    expect(planned(rang, T0 + 25 * MIN)).toEqual([]);
    expect(planned(rang, T0 + 40 * MIN)).toEqual([]);
  });

  test('休息模式是我自己決定時，不排休息通知', () => {
    const s = keep(start(withClue(), T0), T0 + 25 * MIN, 'x');
    s.settings = { ...s.settings, restMode: 'self' };
    expect(planned(s, T0 + 26 * MIN)).toEqual([]);
  });
});

describe('同步到系統', () => {
  test('每次同步先全部取消再排，排的時刻與文案照 planned', async () => {
    const order = [];
    Notifications.cancelAllScheduledNotificationsAsync.mockImplementation(() => {
      order.push('cancel');
      return Promise.resolve();
    });
    Notifications.scheduleNotificationAsync.mockImplementation((req) => {
      order.push(req);
      return Promise.resolve('id');
    });
    await sync(start(withClue(), T0), T0);
    expect(order[0]).toBe('cancel');
    expect(order[1].content).toEqual({
      title: '響了。',
      body: '寫一行給下一顆的自己。',
      sound: 'default',
    });
    expect(order[1].trigger).toEqual({ type: 'date', date: new Date(T0 + 25 * MIN) });
    expect(order).toHaveLength(2);
  });

  test('待機時同步只取消、不排任何東西', async () => {
    await sync(withClue(), T0);
    expect(Notifications.cancelAllScheduledNotificationsAsync).toHaveBeenCalledTimes(1);
    expect(Notifications.scheduleNotificationAsync).not.toHaveBeenCalled();
  });

  test('設定聲音關掉時，排的通知沒有聲音', async () => {
    const s = start(withClue(), T0);
    s.settings = { ...s.settings, sound: false };
    await sync(s, T0);
    expect(Notifications.scheduleNotificationAsync.mock.calls[0][0].content.sound).toBe(false);
  });

  test('系統排不進去（丟例外）時不會把 app 弄當', async () => {
    Notifications.cancelAllScheduledNotificationsAsync.mockRejectedValueOnce(new Error('no'));
    await expect(sync(start(withClue(), T0), T0)).resolves.toBeUndefined();
  });
});

describe('問權限只問一次', () => {
  test('已允許時不跳框，回 true', async () => {
    Notifications.getPermissionsAsync.mockResolvedValue({ granted: true, canAskAgain: true });
    expect(await askPermissionOnce()).toBe(true);
    expect(Notifications.requestPermissionsAsync).not.toHaveBeenCalled();
  });

  test('被拒且不能再問時不跳框，回 false', async () => {
    Notifications.getPermissionsAsync.mockResolvedValue({ granted: false, canAskAgain: false });
    expect(await askPermissionOnce()).toBe(false);
    expect(Notifications.requestPermissionsAsync).not.toHaveBeenCalled();
  });

  test('還沒問過才跳系統框，結果照使用者按的', async () => {
    Notifications.getPermissionsAsync.mockResolvedValue({ granted: false, canAskAgain: true });
    Notifications.requestPermissionsAsync.mockResolvedValue({ granted: true, canAskAgain: true });
    expect(await askPermissionOnce()).toBe(true);
    expect(Notifications.requestPermissionsAsync).toHaveBeenCalledTimes(1);
  });
});
