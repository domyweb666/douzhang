// 番茄帳 白噪音（2026-11-17 AG6，比較頁 6A）：計時中循環播雨或柴火，響了就停。
// 多米選「鎖屏、切到別的 app 也繼續播」：播的時候把音訊模式切成「靜音鍵撥到靜音也播、在背景也播」，
// 停了切回原本那組（罐子的入罐音、碰撞音：靜音就不響、不在背景播）。音訊模式全 app 只有一份，所以統一由這個檔管。
// 跟別的 app 的聲音混在一起播（mixWithOthers）：使用者自己在放的音樂不會被番茄帳打斷。
// 什麼時候該播由純函式 ambienceFor() 算，殼只負責在答案變了的時候叫 applyAmbience()。
// 音檔是捏捏史萊姆那兩條底（各 122 秒，Freesound CC0，來源見 assets/ambience/來源.md）。
import { createAudioPlayer, setAudioModeAsync } from 'expo-audio';
import { PHASE, phaseOf } from './machine';
import { params } from '../design/params';

export const AMBIENCE_OFF = 'off';

const SOURCES = {
  rain: require('../assets/ambience/rain.m4a'),
  fire: require('../assets/ambience/fire.m4a'),
};
const mode = (loud) => ({
  playsInSilentMode: loud,
  shouldPlayInBackground: loud,
  interruptionMode: 'mixWithOthers',
});

let playing = null; // { kind, player }：現在在播的那一條

/** 現在該播哪一種：這顆還在跑才播設定選的那種；鈴響、休息、待機都不播。 */
export function ambienceFor(state, now) {
  return phaseOf(state, now) === PHASE.focus ? state.settings.ambience : AMBIENCE_OFF;
}

/** 音量三段對到 0–1；不認得的當中間那段。 */
export const volumeOf = (level) => params.ambience.volumes[level] ?? params.ambience.volumes.mid;

function stop() {
  if (!playing) return;
  const { player } = playing;
  playing = null;
  try {
    player.pause();
    player.remove();
  } catch {
    // 已經釋放過
  }
  setAudioModeAsync(mode(false)).catch(() => {});
}

/**
 * 播這一種（循環）、換音量，或停掉（kind 是 'off' 或不認得的）。同一種還在播就只換音量，不從頭播。
 * 播不出來不往外丟：沒有聲音照樣計時。
 */
export function applyAmbience(kind, level) {
  try {
    if (!SOURCES[kind]) {
      stop();
      return;
    }
    if (playing && playing.kind !== kind) stop();
    if (!playing) {
      setAudioModeAsync(mode(true)).catch(() => {});
      const player = createAudioPlayer(SOURCES[kind]);
      player.loop = true;
      playing = { kind, player };
    }
    playing.player.volume = volumeOf(level);
    playing.player.play();
  } catch {
    stop();
  }
}

/** 罐子掛上來時用：把音訊模式設成音效那組。白噪音正在播就不動（那時要能在靜音與背景下播）。 */
export function sfxAudioMode() {
  if (!playing) setAudioModeAsync(mode(false)).catch(() => {});
}
