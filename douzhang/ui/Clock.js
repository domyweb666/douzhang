// 大時間。Tokens 的 clock／clockFocus 帶 maxFontSizeMultiplier，那是 Text 的 prop 不是 style，這裡拆開餵。
import { Text } from 'react-native';
import { useTokens } from '../design/Tokens';

/** ring：進度環下面那個（AH2）；focus：待機的大時間；都沒有：舊的最大那號。 */
export function Clock({ text, focus, ring, style }) {
  const T = useTokens();
  const pick = ring ? T.font.clockRing : focus ? T.font.clockFocus : T.font.clock;
  const { maxFontSizeMultiplier, ...font } = pick;
  return (
    <Text
      maxFontSizeMultiplier={maxFontSizeMultiplier}
      style={[font, { color: T.color.textPrimary, textAlign: 'center' }, style]}
    >
      {text}
    </Text>
  );
}
