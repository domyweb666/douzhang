// 計時中長大的番茄（2026-11-17 AG2，比較頁 1A）：藤上掛一顆，越接近到點越大、從青轉黃再轉成這個標籤的番茄色。
// 多大、什麼顏色由 core/grow.js 算；這裡只畫。沒有動畫：每一拍照進度重畫，一顆 25 分鐘的番茄一拍只變一點點。
// 純裝飾，讀屏略過（剩多久已經在上面的大時間）。
import { View } from 'react-native';
import { CharacterColors, useTokens } from '../design/Tokens';
import { growScale, ripeColor } from '../core/grow';
import { Tomato } from './Tomato';

const INK = CharacterColors.tomato;

/** progress：0–1；color：標籤的番茄色；height：這塊空位有多高（放不下全熟的大小就整個縮小）。 */
export function GrowingTomato({ progress, color, height }) {
  const T = useTokens();
  const full = Math.min(T.shape.growSize, height - T.shape.growVine);
  const fill = ripeColor(progress, { unripe: INK.unripe, ripe: INK.body[color] || INK.body.red });
  return (
    <View
      accessible={false}
      importantForAccessibility="no-hide-descendants"
      accessibilityElementsHidden
      style={{ alignItems: 'center' }}
    >
      <View
        style={{
          width: T.shape.growVineWidth,
          height: T.shape.growVine,
          borderRadius: T.shape.radiusPill,
          backgroundColor: INK.vine,
        }}
      />
      <View style={{ marginTop: -T.space.xs }}>
        <Tomato fill={fill} size={full * growScale(progress)} />
      </View>
    </View>
  );
}
