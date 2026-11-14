// 番茄火柴人（Y1，2026-11-15）：火柴人身體＋番茄頭套。平常站著不動；play 變成 true 時把 action 播一次，播完站回原樣。
// 姿勢在 core/poses.js（純計算），這裡只管畫與那一兩秒的動畫迴圈。沒在播的時候不跑迴圈、不重畫。
// 減少動態：不播，只畫站姿（照樣回報 onDone，這次的事才算用掉）。純裝飾，讀屏略過。
// 頭套的路徑與線條粗細是圖的一部分（單位是 viewBox 座標），顏色與秒數從 Tokens 來。
import { useEffect, useRef, useState } from 'react';
import Svg, { Circle, Ellipse, G, Line, Path, Polyline, Rect } from 'react-native-svg';
import { CharacterColors, Token, useTokens } from '../design/Tokens';
import { MS_PER_SECOND } from '../design/params';
import { REST, RIG, oneShot, skeleton } from '../core/poses';

const MOTION = Token.motion.mascot; // 數字不隨深淺色變，拿靜態那份
const INK = CharacterColors.mascot;
// 畫布：左右以髖為中心各 102（手從叉腰甩到舉高的途中會伸直，量過三個動作全程最遠到 ±96），上面留到跳起來的頭頂，下面留到影子
const VIEW = { x: 58, y: 14, width: 204, height: 384 };
const LIMB = { leg: 9, arm: 8.5 }; // 線條粗細
const ART = {
  // 番茄頭套（原點在脖子，臉的圓心在 0,-46）
  tomato:
    'M0,-102 C24,-108 60,-94 60,-52 C60,-14 31,4 0,4 C-31,4 -60,-14 -60,-52 C-60,-94 -24,-108 0,-102 Z',
  shine: 'M-47,-60 C-46,-76 -38,-87 -26,-93',
  calyx:
    'M0,-104 C-12,-112 -30,-108 -42,-94 C-30,-98 -20,-97 -12,-94 C-18,-88 -22,-80 -21,-71 C-14,-80 -7,-87 0,-91 C7,-87 14,-80 21,-71 C22,-80 18,-88 12,-94 C20,-97 30,-98 42,-94 C30,-108 12,-112 0,-104 Z',
  stem: 'M-4,-102 C-5,-112 -2,-120 5,-127 L12,-121 C7,-116 5,-109 6,-102 Z',
  face: { cy: -46, r: 30, rim: 33 },
};

/** play 變成 true 就從頭播一次，回傳「開始播之後過了幾秒」；沒在播是 null。still＝減少動態，不播。 */
function useOneShot(action, play, still, onDone) {
  const [t, setT] = useState(null);
  const done = useRef(onDone);
  useEffect(() => {
    done.current = onDone;
  }, [onDone]);
  useEffect(() => {
    if (!play) return undefined;
    if (still) {
      done.current?.();
      return undefined;
    }
    const total = (MOTION[`${action}Ms`] + MOTION.blendMs) / MS_PER_SECOND;
    let raf;
    let start = null;
    const frame = (stamp) => {
      if (start === null) start = stamp;
      const now = (stamp - start) / MS_PER_SECOND;
      if (now >= total) {
        setT(null);
        done.current?.();
        return;
      }
      setT(now);
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [action, play, still]);
  return t;
}

const points = (list) => list.map(([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`).join(' ');

function Limb({ joints, width, color }) {
  return (
    <Polyline
      points={points(joints)}
      fill="none"
      stroke={color}
      strokeWidth={width}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  );
}

/** 一隻眼睛＋它上面的眉毛。side −1 左、1 右。笑到彎起來時眼睛是一道弧。 */
function Eye({ side, pose }) {
  const cx = side * 11;
  const cy = -48 + pose.lookY;
  const by = -61 + pose.browY + pose.lookY / 2;
  const tilt = (pose.brow * Math.PI) / 180;
  const dx = side * 8 * Math.cos(tilt);
  const dy = 8 * Math.sin(tilt);
  const h = Math.max(1.5, pose.eyeH);
  return (
    <>
      {pose.happy > 0.5 ? (
        <Path
          d={`M${cx - 5},${cy + 3} Q${cx},${cy - 6} ${cx + 5},${cy + 3}`}
          fill="none"
          stroke={INK.ink}
          strokeWidth={3.6}
          strokeLinecap="round"
        />
      ) : (
        <Rect x={cx - 2.3} y={cy - h / 2} width={4.6} height={h} rx={2.3} fill={INK.ink} />
      )}
      <Line
        x1={side * 12 - dx}
        y1={by + dy}
        x2={side * 12 + dx}
        y2={by - dy}
        stroke={INK.ink}
        strokeWidth={3.4}
        strokeLinecap="round"
      />
    </>
  );
}

function Mouth({ pose }) {
  const y = -30 + pose.lookY / 2;
  if (pose.mouth === 'open')
    return <Path d={`M-7,${y - 2} Q0,${y + 10} 7,${y - 2} Z`} fill={INK.ink} />;
  return (
    <Path
      d={`M-6,${y - 1} Q0,${y + 5} 6,${y - 1}`}
      fill="none"
      stroke={INK.ink}
      strokeWidth={3}
      strokeLinecap="round"
    />
  );
}

/** 番茄頭套與臉。掛在脖子上：位置、角度、高度比例跟著姿勢。 */
function Head({ at, pose }) {
  return (
    <G
      transform={`translate(${at.x.toFixed(1)} ${at.y.toFixed(1)}) rotate(${at.rotate.toFixed(1)}) scale(1 ${at.scaleY.toFixed(2)})`}
    >
      <Path d={ART.tomato} fill={INK.tomato} />
      <Path
        d={ART.shine}
        fill="none"
        stroke={INK.tomatoShine}
        strokeWidth={6}
        strokeLinecap="round"
      />
      <Path d={ART.stem} fill={INK.stem} />
      <Path d={ART.calyx} fill={INK.calyx} />
      <Circle cx={0} cy={ART.face.cy} r={ART.face.rim} fill={INK.tomatoRim} />
      <Circle cx={0} cy={ART.face.cy} r={ART.face.r} fill={INK.face} />
      <Eye side={-1} pose={pose} />
      <Eye side={1} pose={pose} />
      <Mouth pose={pose} />
    </G>
  );
}

/** 腳下的影子：跳起來時變小變淡。 */
function Shadow({ lift, color }) {
  const shrink = 1 - lift * 0.35;
  return (
    <Ellipse
      cx={RIG.hipX}
      cy={RIG.ground + 7}
      rx={62 * shrink}
      ry={8 * shrink}
      fill={color}
      opacity={MOTION.shadowOpacity * (1 - lift / 2)}
    />
  );
}

/**
 * action：'cheer'｜'bow'｜'wave'。play：變成 true 時播一次（還是 true 就不重播；變回 false 再變 true 會重播）。
 * onDone：播完（或減少動態時立刻）回報一次。height：畫多高，寬照比例。
 */
export function Mascot({ action, play, onDone, height }) {
  const T = useTokens();
  const t = useOneShot(action, play, T.reduceMotion, onDone);
  const pose =
    t === null
      ? REST
      : oneShot(action, t, MOTION[`${action}Ms`] / MS_PER_SECOND, MOTION.blendMs / MS_PER_SECOND);
  const s = skeleton(pose);
  const line = T.color.textPrimary;
  // 落地壓扁：以腳下那一點為中心，變寬一點、變矮一點
  const squash = `translate(${RIG.hipX} ${RIG.ground}) scale(${(1 + pose.squash * 0.6).toFixed(3)} ${(1 - pose.squash).toFixed(3)}) translate(${-RIG.hipX} ${-RIG.ground})`;
  return (
    <Svg
      accessible={false}
      importantForAccessibility="no-hide-descendants"
      accessibilityElementsHidden
      width={(height * VIEW.width) / VIEW.height}
      height={height}
      viewBox={`${VIEW.x} ${VIEW.y} ${VIEW.width} ${VIEW.height}`}
    >
      <Shadow lift={s.lift} color={T.color.shadow} />
      <G transform={squash}>
        <Limb joints={s.legs[0]} width={LIMB.leg} color={line} />
        <Limb joints={s.legs[1]} width={LIMB.leg} color={line} />
        <Limb joints={s.torso} width={LIMB.leg} color={line} />
        <Head at={s.head} pose={pose} />
        <Limb joints={s.arms[0]} width={LIMB.arm} color={line} />
        <Limb joints={s.arms[1]} width={LIMB.arm} color={line} />
      </G>
    </Svg>
  );
}
