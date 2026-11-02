// 豆罐（畫的那一半）：今天的豆子躺在罐底；收下一顆就從罐口掉進來，落地那一幀「啵」＋短觸覺（參數表 A）。
// D2：傾斜手機豆子跟著滾（expo-sensors，設定可關）、點一下彈、碰撞聲與觸覺（門檻＋最短間隔）、掉幀退成靜止版。
// 物理在 core/jarPhysics.js；數字全從 Tokens 與 params 來。
// 世界物件放 ref（lazy init），只在事件、effect、loop 裡碰；畫面只讀每幀抄出來的快照 state。
import { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, Image, Pressable } from 'react-native';
import * as Haptics from 'expo-haptics';
import { DeviceMotion } from 'expo-sensors';
import { createAudioPlayer, setAudioModeAsync } from 'expo-audio';
import { Token } from '../design/Tokens';
import { MS_PER_SECOND, jarParams, params } from '../design/params';
import { words } from '../design/words';
import { addBody, makeWorld, radiusFor, seed, step, tapAt } from '../core/jarPhysics';
import { TOMATO_ASPECT, tomatoOf } from './tomatoImages';

const SFX = {
  pop: require('../assets/sfx/pop.wav'),
  hits: [
    require('../assets/sfx/hit260.wav'),
    require('../assets/sfx/hit290.wav'),
    require('../assets/sfx/hit320.wav'),
    require('../assets/sfx/hit350.wav'),
  ],
};

const HAPTIC = {
  'impact.rigid': Haptics.ImpactFeedbackStyle.Rigid,
  'impact.light': Haptics.ImpactFeedbackStyle.Light,
};
const DROP = Token.motion.beanDrop; // 數字不隨深淺色變，拿靜態那份
const DROP_REDUCED = Token.motion.beanDropReduced;
const SOUND = Token.sound;

function useReduceMotion() {
  const [reduce, setReduce] = useState(false);
  useEffect(() => {
    AccessibilityInfo.isReduceMotionEnabled()
      .then((v) => setReduce(!!v))
      .catch(() => {});
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', (v) => setReduce(!!v));
    return () => sub.remove();
  }, []);
  return reduce;
}

/** 入罐音與碰撞音。靜音開關撥到靜音就不響（playsInSilentMode: false）。回的是 ref，只在事件裡讀。 */
function useAudio() {
  const players = useRef(null);
  useEffect(() => {
    try {
      setAudioModeAsync({ playsInSilentMode: false }).catch(() => {});
      players.current = { pop: createAudioPlayer(SFX.pop), hits: SFX.hits.map(createAudioPlayer) };
    } catch {
      players.current = null;
    }
    return () => {
      try {
        players.current?.pop.remove();
        players.current?.hits.forEach((p) => p.remove());
      } catch {
        // 已經釋放過
      }
    };
  }, []);
  return players;
}

function play(player, volume) {
  try {
    if (volume != null) player.volume = volume;
    player.seekTo(0);
    player.play();
  } catch {
    // 音效失敗不影響收下
  }
}

/** 落地那一刻的視聽觸：同一事件同一幀（參數表 A 入罐音、入罐觸覺）。 */
function land(players, sound) {
  if (sound && players.current) play(players.current.pop);
  Haptics.impactAsync(HAPTIC[Token.haptic.beanLand]).catch(() => {});
}

/** 碰撞：超過門檻、間隔夠久才一次「嗒」＋輕觸覺；音量隨衝擊（參數表 B）。 */
function hit(players, sound, impact) {
  if (sound && players.current) {
    const hits = players.current.hits;
    const volume = Math.min(SOUND.hitVolMax, impact / SOUND.hitVolDiv);
    play(hits[Math.floor(Math.random() * hits.length)], volume);
  }
  Haptics.impactAsync(HAPTIC[Token.haptic.beanHit]).catch(() => {});
}

function dropOne(W, r, color, still) {
  if (W.bodies.length >= W.P.maxBeans) return;
  const go = () => {
    const x = W.w / 2 + (Math.random() - 0.5) * r * 2;
    if (still) {
      addBody(W, r, x, W.h - r);
      W.onLand?.();
    } else {
      addBody(W, r, x, -r * 2, (Math.random() - 0.5) * 2 * DROP.vxSpread, DROP.vy, true);
    }
    W.bodies[W.bodies.length - 1].color = color; // 物理不管顏色，畫的時候用
  };
  W.timers.push(setTimeout(go, still ? DROP_REDUCED.delayMs : DROP.delayMs)); // 卸載時要清掉
}

/** 照 beans 重新安置，並把每顆的顏色貼回去（seed 照順序加，第 i 顆就是 beans[i]）。 */
function seedBeans(W, beans) {
  seed(
    W,
    beans.map((b) => radiusFor(W.P, b.len)),
  );
  W.bodies.forEach((body, i) => {
    body.color = beans[i]?.color;
  });
}

/** 跟上今天的番茄：多一顆就掉一顆；數目對不上（換日、匯入、清空）就重新安置。 */
function follow(W, beans, still) {
  const last = beans[beans.length - 1];
  if (beans.length === W.known + 1) dropOne(W, radiusFor(W.P, last.len), last.color, still);
  else if (beans.length !== W.known) seedBeans(W, beans);
  W.known = beans.length;
}

/** 傾斜：加速度計換成重力向量的目標值；關掉時回到靜置重力。 */
function useTilt(worldRef, on) {
  useEffect(() => {
    const W = worldRef.current;
    if (!on) {
      W.tgx = 0;
      W.tgy = W.P.gravity;
      return undefined;
    }
    let sub = null;
    DeviceMotion.isAvailableAsync()
      .then((ok) => {
        if (!ok) return;
        DeviceMotion.setUpdateInterval(params.jar.sensorIntervalMs);
        sub = DeviceMotion.addListener(({ accelerationIncludingGravity: a }) => {
          if (!a || a.x == null) return;
          W.tgx = a.x * W.P.tiltScale;
          W.tgy = -a.y * W.P.tiltScale;
        });
      })
      .catch(() => {});
    return () => {
      sub?.remove();
      W.tgx = 0;
      W.tgy = W.P.gravity;
    };
  }, [worldRef, on]);
}

/** 畫面要的快照：每幀從世界抄一份出來（render 只讀這份，不碰可變的世界）。 */
function snapshot(W) {
  return W.bodies.map((b) => ({ id: b.id, x: b.x, y: b.y, r: b.r, color: b.color }));
}

/** 每秒結算一次幀數：連續 lowFpsSeconds 秒低於門檻就回報。 */
function countFrame(fps, t, onLowFps) {
  fps.n++;
  if (t - fps.t <= MS_PER_SECOND) return;
  fps.lowSeconds = fps.n < params.jar.lowFpsThreshold ? fps.lowSeconds + 1 : 0;
  fps.n = 0;
  fps.t = t;
  if (fps.lowSeconds >= params.jar.lowFpsSeconds) onLowFps();
}

/** 兩份快照差不到門檻就算沒動：番茄都躺好時不重畫（退成靜止版要真的省下來）。 */
function samePlace(a, b) {
  const px = params.jar.redrawEpsilonPx;
  if (a.length !== b.length) return false;
  const near = (p, q) => Math.abs(p - q) < px;
  return a.every((s, i) => near(s.x, b[i].x) && near(s.y, b[i].y));
}

/** 每幀走物理、落地與碰撞事件交給 W.onLand／W.onHit、有動才把快照放進 state 重畫；連續掉幀就回報（退成靜止版）。 */
function useLoop(worldRef, onLowFps) {
  const [frame, setFrame] = useState([]);
  useEffect(() => {
    const W = worldRef.current;
    let raf;
    let last = 0;
    let run = true;
    let lastHit = 0;
    let shown = [];
    const fps = { n: 0, t: 0, lowSeconds: 0 };
    const loop = (t) => {
      if (!run) return;
      const dt = last ? Math.min(W.P.dtMax, (t - last) / MS_PER_SECOND) : W.P.dtMax / 2;
      last = t;
      W.gx += (W.tgx - W.gx) * W.P.tiltSmooth;
      W.gy += (W.tgy - W.gy) * W.P.tiltSmooth;
      W.impact = 0;
      W.landed = [];
      for (let i = 0; i < W.P.substeps; i++) step(W, dt / W.P.substeps);
      if (W.landed.length) W.onLand?.();
      if (W.impact > SOUND.hitThreshold && t - lastHit > SOUND.hitGapMs) {
        lastHit = t;
        W.onHit?.(W.impact);
      }
      countFrame(fps, t, onLowFps);
      const next = snapshot(W);
      if (!samePlace(shown, next)) {
        shown = next;
        setFrame(next);
      }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => {
      run = false;
      cancelAnimationFrame(raf);
    };
  }, [worldRef, onLowFps]);
  return frame;
}

function Bean({ x, y, r, color }) {
  const height = r * 2 * TOMATO_ASPECT;
  return (
    <Image
      source={tomatoOf(color)}
      style={{
        position: 'absolute',
        width: r * 2,
        height,
        transform: [{ translateX: x - r }, { translateY: y - height / 2 }],
      }}
    />
  );
}

/**
 * beans：今天的番茄（依時間排），每個 { len, color }（分鐘決定大小，類型決定顏色）。多一顆就掉一顆；數目對不上（換日、匯入、清空）就重新安置。
 * seenRef：殼保管的「豆罐上次看到幾顆」。鈴響時主畫面（連豆罐）整個換成鈴響頁，收下後豆罐重掛；
 *   沒有這個數，重掛就把剛收的那顆直接擺在罐底，不掉、不啵（D+E 審查員）。
 * sound：設定的聲音開關。tilt：設定的傾斜開關。
 * 靜止版（減少動態、或連續掉幀）：不傾斜、不彈、新豆直接出現在罐底，啵與觸覺照樣。
 */
export function Jar({ beans, seenRef, sound, tilt, style }) {
  const reduce = useReduceMotion();
  const [lowFps, setLowFps] = useState(false);
  const still = reduce || lowFps;
  const players = useAudio();
  const worldRef = useRef(null);
  if (worldRef.current === null) {
    worldRef.current = { ...makeWorld(jarParams(Token)), known: null, timers: [] }; // known＝上次看到的顆數
  }

  useEffect(() => {
    const W = worldRef.current;
    W.onLand = () => land(players, sound);
    W.onHit = (impact) => hit(players, sound, impact);
  }, [players, sound]);

  const onLayout = (e) => {
    const W = worldRef.current;
    const { width, height } = e.nativeEvent.layout;
    const first = !W.w;
    W.w = width;
    W.h = height;
    if (!first) return;
    // 先擺上次看到的那些，多出來的（鈴響時收下的）再照常掉進來
    const before = seenRef.current;
    W.known = before != null && before <= beans.length ? before : beans.length;
    seedBeans(W, beans.slice(0, W.known));
    follow(W, beans, still);
    seenRef.current = W.known;
  };

  useEffect(() => {
    const W = worldRef.current;
    if (W.known === null || !W.w) return;
    follow(W, beans, still);
    seenRef.current = W.known;
  }, [beans, still, seenRef]);

  useEffect(() => {
    const W = worldRef.current;
    return () => W.timers.forEach(clearTimeout);
  }, []);

  useTilt(worldRef, !!tilt && !still);
  const onLowFps = useCallback(() => setLowFps(true), []);
  const frame = useLoop(worldRef, onLowFps);
  const n = frame.length;

  return (
    <Pressable
      onLayout={onLayout}
      onPress={(e) => {
        if (still) return;
        tapAt(worldRef.current, e.nativeEvent.locationX, e.nativeEvent.locationY);
      }}
      accessibilityLabel={n ? `${words.todayBeans} ${n}` : words.todayBeans}
      style={[{ flex: 1, overflow: 'hidden' }, style]}
    >
      {frame.map((b) => (
        <Bean key={b.id} x={b.x} y={b.y} r={b.r} color={b.color} />
      ))}
    </Pressable>
  );
}
