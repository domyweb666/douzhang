// 番茄（2026-11-16 多米看比較頁選 B「描邊表情」）：罐子、番茄架、設定選色三處共用。
// 取代 11-02 的扁平番茄圖：那張是扁的，罐子物理卻把每顆當正圓算，堆起來有縫、蒂會蓋到上面那顆，也沒辦法跟著滾。
// 這顆整個畫在外接圓裡（viewBox 100×100，圓心 50,50、半徑 50＝物理算的那個圓），轉到哪個角度都不會超出去。
// 路徑、線條粗細、透明度是圖的一部分（單位是 viewBox 座標）；顏色從 Tokens 來。純裝飾，讀屏略過。
import { memo } from 'react';
import Svg, { Circle, Ellipse, Path } from 'react-native-svg';
import { CharacterColors } from '../design/Tokens';

const INK = CharacterColors.tomato;
const ART = {
  body: { cx: 50, cy: 53, r: 44, line: 4 },
  shine: { d: 'M19 44 C21 33 28 25 38 21', line: 5, opacity: 0.6 },
  leaf: { cy: 10, rx: 12, ry: 5.5, offset: 13, turn: 14, line: 3.5 }, // 左右各一片，以 x=50 對稱
  stem: { d: 'M50 11 V3.5', line: 4 },
  eye: { cy: 55, r: 3.8, offset: 13 },
  mouth: { d: 'M43.5 63 Q50 69.5 56.5 63', line: 3.2 },
  cheek: { cy: 64, rx: 5.5, ry: 3.2, offset: 23, opacity: 0.3 },
};

/** side −1 左、1 右。 */
function Leaf({ side }) {
  const cx = 50 + side * ART.leaf.offset;
  return (
    <Ellipse
      cx={cx}
      cy={ART.leaf.cy}
      rx={ART.leaf.rx}
      ry={ART.leaf.ry}
      transform={`rotate(${side * ART.leaf.turn} ${cx} ${ART.leaf.cy})`}
      fill={INK.leaf}
      stroke={INK.ink}
      strokeWidth={ART.leaf.line}
    />
  );
}

/**
 * color：類型的番茄色（params.tomatoColors 其中一個）；不認得的色（舊資料、被刪的類型）一律紅。size：畫多寬多高。
 * 用 memo：罐子每幀重畫幾十顆的位置，圖本身只要顏色與大小沒變就不重算。
 */
export const Tomato = memo(function Tomato({ color, size }) {
  return (
    <Svg
      accessible={false}
      importantForAccessibility="no-hide-descendants"
      accessibilityElementsHidden
      width={size}
      height={size}
      viewBox="0 0 100 100"
    >
      <Circle
        cx={ART.body.cx}
        cy={ART.body.cy}
        r={ART.body.r}
        fill={INK.body[color] || INK.body.red}
        stroke={INK.ink}
        strokeWidth={ART.body.line}
      />
      <Path
        d={ART.shine.d}
        fill="none"
        stroke={INK.shine}
        strokeOpacity={ART.shine.opacity}
        strokeWidth={ART.shine.line}
        strokeLinecap="round"
      />
      <Leaf side={-1} />
      <Leaf side={1} />
      <Path
        d={ART.stem.d}
        fill="none"
        stroke={INK.ink}
        strokeWidth={ART.stem.line}
        strokeLinecap="round"
      />
      <Circle cx={50 - ART.eye.offset} cy={ART.eye.cy} r={ART.eye.r} fill={INK.ink} />
      <Circle cx={50 + ART.eye.offset} cy={ART.eye.cy} r={ART.eye.r} fill={INK.ink} />
      <Path
        d={ART.mouth.d}
        fill="none"
        stroke={INK.ink}
        strokeWidth={ART.mouth.line}
        strokeLinecap="round"
      />
      <Ellipse
        cx={50 - ART.cheek.offset}
        cy={ART.cheek.cy}
        rx={ART.cheek.rx}
        ry={ART.cheek.ry}
        fill={INK.shine}
        fillOpacity={ART.cheek.opacity}
      />
      <Ellipse
        cx={50 + ART.cheek.offset}
        cy={ART.cheek.cy}
        rx={ART.cheek.rx}
        ry={ART.cheek.ry}
        fill={INK.shine}
        fillOpacity={ART.cheek.opacity}
      />
    </Svg>
  );
});
