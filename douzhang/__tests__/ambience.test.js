// 白噪音（AG6）測試。expo-audio 換成假的，只看「什麼時候該播、播的是哪一條、音量、音訊模式、失敗會不會往外丟」。
// 好不好聽、接縫順不順、鎖屏後有沒有繼續播要在手機上聽。
import { createAudioPlayer, setAudioModeAsync } from 'expo-audio';
import { blank, normalize } from '../core/store';
import { flow, keep, start, voidBean } from '../core/machine';
import { setAmbience, setAmbienceVolume } from '../core/settings';
import { AMBIENCE_OFF, ambienceFor, applyAmbience, sfxAudioMode, volumeOf } from '../core/ambience';
import { params } from '../design/params';

// jest 會把 mock 提到最前面，寫在 import 後面只是給 lint 看
jest.mock('expo-audio', () => ({
  createAudioPlayer: jest.fn(() => ({
    play: jest.fn(),
    pause: jest.fn(),
    remove: jest.fn(),
    loop: false,
    volume: 1,
  })),
  setAudioModeAsync: jest.fn(() => Promise.resolve()),
}));

const MIN = 60 * 1000;
const T0 = new Date(2026, 10, 17, 9, 0, 0).getTime();
const LOUD = {
  playsInSilentMode: true,
  shouldPlayInBackground: true,
  interruptionMode: 'mixWithOthers',
};
const QUIET = {
  playsInSilentMode: false,
  shouldPlayInBackground: false,
  interruptionMode: 'mixWithOthers',
};
const lastPlayer = () => createAudioPlayer.mock.results.at(-1).value;

beforeEach(() => {
  applyAmbience(AMBIENCE_OFF); // 上一條測試留下來的先停掉
  jest.clearAllMocks();
});

describe('設定', () => {
  test('預設不播、音量中；只收刻度上的值；存檔讀回來還在', () => {
    expect(blank().settings).toMatchObject({ ambience: 'off', ambienceVolume: 'mid' });
    const s = setAmbienceVolume(setAmbience(blank(), 'rain'), 'high');
    expect(s.settings).toMatchObject({ ambience: 'rain', ambienceVolume: 'high' });
    expect(setAmbience(s, 'ocean')).toBe(s);
    expect(setAmbienceVolume(s, 'max')).toBe(s);
    expect(normalize(JSON.parse(JSON.stringify(s))).settings).toMatchObject({
      ambience: 'rain',
      ambienceVolume: 'high',
    });
  });

  test('舊檔沒有這兩欄、或值亂掉：補成不播、音量中', () => {
    const odd = {
      ...blank(),
      settings: { ...blank().settings, ambience: 7, ambienceVolume: null },
    };
    expect(normalize(odd).settings).toMatchObject({ ambience: 'off', ambienceVolume: 'mid' });
  });
});

describe('什麼時候該播', () => {
  const rainy = () => setAmbience(blank(), 'rain');

  test('待機不播；按開始就播選的那種，一路播到響之前；響了就停', () => {
    expect(ambienceFor(rainy(), T0)).toBe('off');
    const running = start(rainy(), T0);
    expect(ambienceFor(running, T0)).toBe('rain');
    expect(ambienceFor(running, T0 + 25 * MIN - 1)).toBe('rain');
    expect(ambienceFor(running, T0 + 25 * MIN)).toBe('off');
  });

  test('再做一下又播；收下後的休息、作廢都不播；選「關」計時中也不播', () => {
    const running = start(rainy(), T0);
    const rang = T0 + 25 * MIN;
    expect(ambienceFor(flow(running, rang + MIN, 15), rang + 2 * MIN)).toBe('rain');
    expect(ambienceFor(keep(running, rang, ''), rang + MIN)).toBe('off');
    expect(ambienceFor(voidBean(running, T0 + 10 * MIN), T0 + 10 * MIN)).toBe('off');
    expect(ambienceFor(start(blank(), T0), T0 + MIN)).toBe('off');
  });

  test('音量三段由小到大，不認得的當中間', () => {
    const v = params.ambience.volumes;
    expect(v.low).toBeLessThan(v.mid);
    expect(v.mid).toBeLessThan(v.high);
    expect(volumeOf('high')).toBe(v.high);
    expect(volumeOf('whatever')).toBe(v.mid);
  });
});

describe('播與停', () => {
  test('播：切成「靜音與背景也播」、循環、照音量；同一種再叫一次只換音量，不重新建', () => {
    applyAmbience('rain', 'low');
    expect(setAudioModeAsync).toHaveBeenLastCalledWith(LOUD);
    expect(createAudioPlayer).toHaveBeenCalledTimes(1);
    const player = lastPlayer();
    expect(player.loop).toBe(true);
    expect(player.volume).toBe(params.ambience.volumes.low);
    expect(player.play).toHaveBeenCalledTimes(1);
    applyAmbience('rain', 'high');
    expect(createAudioPlayer).toHaveBeenCalledTimes(1);
    expect(player.volume).toBe(params.ambience.volumes.high);
  });

  test('換一種：舊的停掉釋放、新的另外建一條開始播', () => {
    applyAmbience('rain', 'mid');
    const rain = lastPlayer();
    applyAmbience('fire', 'mid');
    expect(rain.pause).toHaveBeenCalled();
    expect(rain.remove).toHaveBeenCalled();
    expect(createAudioPlayer).toHaveBeenCalledTimes(2);
    expect(lastPlayer().play).toHaveBeenCalledTimes(1);
  });

  test('停：停掉釋放、音訊模式切回音效那組；沒在播時叫停什麼都不做', () => {
    applyAmbience('fire', 'mid');
    const player = lastPlayer();
    applyAmbience(AMBIENCE_OFF);
    expect(player.remove).toHaveBeenCalled();
    expect(setAudioModeAsync).toHaveBeenLastCalledWith(QUIET);
    jest.clearAllMocks();
    applyAmbience(AMBIENCE_OFF);
    expect(setAudioModeAsync).not.toHaveBeenCalled();
  });

  test('罐子要設音效模式：沒在播才設，白噪音在播時不蓋掉', () => {
    sfxAudioMode();
    expect(setAudioModeAsync).toHaveBeenLastCalledWith(QUIET);
    applyAmbience('rain', 'mid');
    jest.clearAllMocks();
    sfxAudioMode();
    expect(setAudioModeAsync).not.toHaveBeenCalled();
  });

  test('播放器建不起來不往外丟，之後還能再試', () => {
    createAudioPlayer.mockImplementationOnce(() => {
      throw new Error('boom');
    });
    expect(() => applyAmbience('rain', 'mid')).not.toThrow();
    applyAmbience('rain', 'mid');
    expect(lastPlayer().play).toHaveBeenCalled();
  });
});
