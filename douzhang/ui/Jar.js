// 豆罐（畫的那一半）：今天的豆子躺在罐底；收下一顆就從罐口掉進來，落地那一幀「啵」＋短觸覺（參數表 A）。
// D2：傾斜手機豆子跟著滾（expo-sensors，設定可關）、點一下彈、碰撞聲與觸覺（門檻＋最短間隔）、掉幀退成靜止版。
// 物理在 core/jarPhysics.js；數字全從 Tokens 與 params 來。
// 世界物件放 ref（lazy init），只在事件、effect、loop 裡碰；畫面只讀每幀抄出來的快照 state。
import { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, Image, Pressable } from 'react-native';
import * as Haptics from 'expo-haptics';
import { DeviceMotion } from 'expo-sensors';
import { createAudioPlayer, setAudioModeAsync } from 'expo-audio';
import { Token, useTokens } from '../design/Tokens';
import { jarParams, params } from '../design/params';
import { words } from '../design/words';
import { addBody, makeWorld, seed, step, tapAt } from '../core/jarPhysics';

const SFX = {
  pop: require('../assets/sfx/pop.wav'),
  hits: [
    require('../assets/sfx/hit260.wav'),
    require('../assets/sfx/hit290.wav'),
    require('../assets/sfx/hit320.wav'),
    require('../assets/sfx/hit350.wav'),
  ],
};
const IMG = {
  single: require('../assets/img/pea.webp'),
  double: require('../assets/img/pea2.webp'),
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

function dropOne(W, two, still) {
  if (W.bodies.length >= W.P.maxBeans) return;
  const go = () => {
    const x = W.w / 2 + (Math.random() - 0.5) * W.P.link * 2;
    if (still) {
      addBody(W, two, x, W.h - W.P.radius);
      W.onLand?.();
    } else {
      addBody(W, two, x, -W.P.radius * 2, (Math.random() - 0.5) * 2 * DROP.vxSpread, DROP.vy, true);
    }
  };
  setTimeout(go, still ? DROP_REDUCED.delayMs : DROP.delayMs);
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
  return {
    singles: W.bodies.filter((b) => b.single).map((b) => ({ id: b.id, x: b.x, y: b.y })),
    doubles: W.links.map((L) => ({
      id: L.id,
      cx: (L.a.x + L.b.x) / 2,
      cy: (L.a.y + L.b.y) / 2,
      ang: Math.atan2(L.b.y - L.a.y, L.b.x - L.a.x),
    })),
  };
}

/** 每幀走物理、落地與碰撞事件交給 W.onLand／W.onHit、把快照放進 state 重畫；連續掉幀就回報（退成靜止版）。 */
function useLoop(worldRef, onLowFps) {
  const [frame, setFrame] = useState({ singles: [], doubles: [] });
  useEffect(() => {
    const W = worldRef.current;
    let raf;
    let last = 0;
    let run = true;
    let lastHit = 0;
    const fps = { n: 0, t: 0, lowSeconds: 0 };
    const loop = (t) => {
      if (!run) return;
      const dt = last ? Math.min(W.P.dtMax, (t - last) / 1000) : W.P.dtMax / 2;
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
      fps.n++;
      if (t - fps.t > 1000) {
        fps.lowSeconds = fps.n < params.jar.lowFpsThreshold ? fps.lowSeconds + 1 : 0;
        fps.n = 0;
        fps.t = t;
        if (fps.lowSeconds >= params.jar.lowFpsSeconds) onLowFps();
      }
      setFrame(snapshot(W));
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

function Bean({ x, y, R }) {
  return (
    <Image
      source={IMG.single}
      style={{
        position: 'absolute',
        width: R * 2,
        height: R * 2,
        transform: [{ translateX: x - R }, { translateY: y - R }],
      }}
    />
  );
}

function DoubleBean({ cx, cy, ang, R, width }) {
  return (
    <Image
      source={IMG.double}
      style={{
        position: 'absolute',
        width,
        height: R * 2,
        transform: [
          { translateX: cx - width / 2 },
          { translateY: cy - R },
          { rotate: `${ang}rad` },
        ],
      }}
    />
  );
}

/**
 * beans：今天的豆子（依時間排），每個 { double }。多一顆就掉一顆；數目對不上（換日、匯入、清空）就重新安置。
 * sound：設定的聲音開關。tilt：設定的傾斜開關。
 * 靜止版（減少動態、或連續掉幀）：不傾斜、不彈、新豆直接出現在罐底，啵與觸覺照樣。
 */
export function Jar({ beans, sound, tilt, style }) {
  const T = useTokens();
  const reduce = useReduceMotion();
  const [lowFps, setLowFps] = useState(false);
  const still = reduce || lowFps;
  const players = useAudio();
  const worldRef = useRef(null);
  if (worldRef.current === null) {
    worldRef.current = { ...makeWorld(jarParams(Token)), known: null }; // known＝上次看到的顆數
  }
  const P = jarParams(Token);

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
    if (first) {
      seed(W, beans.length, (i) => !!beans[i]?.double);
      W.known = beans.length;
    }
  };

  useEffect(() => {
    const W = worldRef.current;
    if (W.known === null || !W.w) return;
    if (beans.length === W.known + 1) dropOne(W, !!beans[beans.length - 1].double, still);
    else if (beans.length !== W.known) seed(W, beans.length, (i) => !!beans[i]?.double);
    W.known = beans.length;
  }, [beans, still]);

  useTilt(worldRef, !!tilt && !still);
  const onLowFps = useCallback(() => setLowFps(true), []);
  const frame = useLoop(worldRef, onLowFps);
  const R = P.radius;
  const n = frame.singles.length + frame.doubles.length;

  return (
    <Pressable
      onLayout={onLayout}
      onPress={(e) => {
        if (still) return;
        tapAt(worldRef.current, e.nativeEvent.locationX, e.nativeEvent.locationY);
      }}
      accessibilityLabel={n ? `${words.todayBeans} ${n}` : words.todayBeans}
      style={[{ flex: 1, overflow: 'hidden', borderRadius: T.shape.radiusCard }, style]}
    >
      {frame.singles.map((b) => (
        <Bean key={b.id} x={b.x} y={b.y} R={R} />
      ))}
      {frame.doubles.map((L) => (
        <DoubleBean key={L.id} cx={L.cx} cy={L.cy} ang={L.ang} R={R} width={P.link + R * 2} />
      ))}
    </Pressable>
  );
}
