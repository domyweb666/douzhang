// 番茄就是時鐘（2026-11-18 AH2，主畫面比較頁 C）：一圈進度環圍著那顆番茄，走完一圈就熟。
// 計時中：環是標籤的番茄色、裡面那顆從青長成標籤色；休息：環是藤的綠、裡面一顆還沒長的小青番茄。
// 多大、什麼顏色由 core/grow.js 算；這裡只畫。純裝飾，讀屏略過（剩多久在下面的時間）。
import Svg, { Circle } from 'react-native-svg';
import { View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { Tomato } from './Tomato';

/**
 * size：環的直徑。progress：環走了幾成（0–1）。ringColor：走過那段的顏色。
 * fill：裡面那顆的顏色；scale：那顆是全熟大小的幾成。
 */
export function RingTomato({ size, progress, ringColor, fill, scale }) {
  const T = useTokens();
  const stroke = T.shape.ringStroke;
  const r = (size - stroke) / 2;
  const around = 2 * Math.PI * r;
  const done = Math.min(1, Math.max(0, progress));
  return (
    <View
      accessible={false}
      importantForAccessibility="no-hide-descendants"
      accessibilityElementsHidden
      style={{ width: size, height: size, alignItems: 'center', justifyContent: 'center' }}
    >
      <Svg width={size} height={size} style={{ position: 'absolute' }}>
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={T.color.separator}
          strokeWidth={stroke}
        />
        {done > 0 ? (
          <Circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke={ringColor}
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={`${around * done} ${around}`}
            transform={`rotate(-90 ${size / 2} ${size / 2})`}
          />
        ) : null}
      </Svg>
      <Tomato fill={fill} size={size * T.shape.ringTomato * scale} />
    </View>
  );
}
