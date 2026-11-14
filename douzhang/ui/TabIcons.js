// 分頁列的三個圖示（線條 2pt，跟 @domy/design 內建的箭頭同一套畫法）。顏色由 DomyTabBar 給。
// 座標是 24×24 畫布上的圖形本身，不是版面數字。
import Svg, { Circle, Path, Rect } from 'react-native-svg';

const STROKE = 2;
const common = (color) => ({
  stroke: color,
  strokeWidth: STROKE,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
  fill: 'none',
});

/** 番茄架：一週的格子 */
export function RackIcon({ color, size }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" accessibilityElementsHidden>
      <Rect x={3} y={5} width={18} height={16} rx={3} {...common(color)} />
      <Path d="M3 10h18M8 3v4M16 3v4" {...common(color)} />
    </Svg>
  );
}

/** 主畫面：一顆番茄 */
export function HomeIcon({ color, size }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" accessibilityElementsHidden>
      <Circle cx={12} cy={14} r={7} {...common(color)} />
      <Path d="M12 7V3.5M8.5 6l3.5 1.5L15.5 6" {...common(color)} />
    </Svg>
  );
}

/** 設定：兩條滑桿 */
export function SettingsIcon({ color, size }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" accessibilityElementsHidden>
      <Path d="M4 7h9M17 7h3M4 17h3M11 17h9" {...common(color)} />
      <Circle cx={15} cy={7} r={2} {...common(color)} />
      <Circle cx={9} cy={17} r={2} {...common(color)} />
    </Svg>
  );
}
