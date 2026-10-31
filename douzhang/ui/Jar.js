// 豆罐（畫的那一半）：今天的豆子躺在罐底；收下一顆就從罐口掉進來，落地那一幀「啵」＋短觸覺（參數表 A）。
// 物理在 core/jarPhysics.js；數字全從 Tokens 與 params 來。減少動態時豆子直接出現在罐底、不掉（參數表減少動態版）。
// 世界物件 W 用 useState 拿一次就一直用同一個（每幀被 loop 改，改完 bump tick 重畫）。
// D1 只有掉豆；傾斜、點彈、碰撞聲是 D2。
import { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, Image, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { createAudioPlayer, setAudioModeAsync } from 'expo-audio';
import { Token, useTokens } from '../design/Tokens';
import { jarParams } from '../design/params';
import { addBody, makeWorld, seed, step } from '../core/jarPhysics';

const SFX = { pop: require('../assets/sfx/pop.wav') };
const IMG = {
  single: require('../assets/img/pea.webp'),
  double: require('../assets/img/pea2.webp'),
};
const HAPTIC = { 'impact.rigid': Haptics.ImpactFeedbackStyle.Rigid };
const DROP = Token.motion.beanDrop; // 數字不隨深淺色變，拿靜態那份
const DROP_REDUCED = Token.motion.beanDropReduced;

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

/** 入罐音。靜音開關撥到靜音就不響（playsInSilentMode: false）。回的是 ref，只在事件裡讀。 */
function useAudio() {
  const player = useRef(null);
  useEffect(() => {
    try {
      setAudioModeAsync({ playsInSilentMode: false }).catch(() => {});
      player.current = createAudioPlayer(SFX.pop);
    } catch {
      player.current = null;
    }
    return () => {
      try {
        player.current?.remove();
      } catch {
        // 已經釋放過
      }
    };
  }, []);
  return player;
}

/** 落地那一刻的視聽觸：同一事件同一幀（參數表 A 入罐音、入罐觸覺）。 */
function land(player, sound) {
  if (sound) {
    try {
      player.current?.seekTo(0);
      player.current?.play();
    } catch {
      // 音效失敗不影響收下
    }
  }
  Haptics.impactAsync(HAPTIC[Token.haptic.beanLand]).catch(() => {});
}

function dropOne(W, two, reduce) {
  if (W.bodies.length >= W.P.maxBeans) return;
  const go = () => {
    const x = W.w / 2 + (Math.random() - 0.5) * W.P.link * 2;
    if (reduce) {
      addBody(W, two, x, W.h - W.P.radius);
      W.onLand?.();
    } else {
      addBody(W, two, x, -W.P.radius * 2, (Math.random() - 0.5) * 2 * DROP.vxSpread, DROP.vy, true);
    }
  };
  setTimeout(go, reduce ? DROP_REDUCED.delayMs : DROP.delayMs);
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

/** 每幀走物理、落地事件交給 W.onLand、把快照放進 state 重畫。 */
function useLoop(worldRef) {
  const [frame, setFrame] = useState({ singles: [], doubles: [] });
  useEffect(() => {
    const W = worldRef.current;
    let raf;
    let last = 0;
    let run = true;
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
      setFrame(snapshot(W));
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => {
      run = false;
      cancelAnimationFrame(raf);
    };
  }, [worldRef]);
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
 * sound：設定的聲音開關。
 */
export function Jar({ beans, sound, style }) {
  const T = useTokens();
  const reduce = useReduceMotion();
  const player = useAudio();
  const worldRef = useRef(null);
  if (worldRef.current === null) {
    // 只建一次（lazy init）；之後只在事件、effect、loop 裡碰它
    worldRef.current = { ...makeWorld(jarParams(Token)), known: null }; // known＝上次看到的顆數
  }
  const P = jarParams(Token);

  useEffect(() => {
    worldRef.current.onLand = () => land(player, sound);
  }, [player, sound]);

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
    if (beans.length === W.known + 1) dropOne(W, !!beans[beans.length - 1].double, reduce);
    else if (beans.length !== W.known) seed(W, beans.length, (i) => !!beans[i]?.double);
    W.known = beans.length;
  }, [beans, reduce]);

  const frame = useLoop(worldRef);
  const R = P.radius;

  return (
    <View
      onLayout={onLayout}
      style={[{ flex: 1, overflow: 'hidden', borderRadius: T.shape.radiusCard }, style]}
      accessibilityLabel={`${frame.singles.length + frame.doubles.length}`}
    >
      {frame.singles.map((b) => (
        <Bean key={b.id} x={b.x} y={b.y} R={R} />
      ))}
      {frame.doubles.map((L) => (
        <DoubleBean key={L.id} cx={L.cx} cy={L.cy} ang={L.ang} R={R} width={P.link + R * 2} />
      ))}
    </View>
  );
}
