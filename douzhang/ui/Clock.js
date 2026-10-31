// 大時間。Tokens 的 clock／clockFocus 帶 maxFontSizeMultiplier，那是 Text 的 prop 不是 style，這裡拆開餵。
import { Text } from 'react-native';
import { useTokens } from '../design/Tokens';

export function Clock({ text, focus, style }) {
  const T = useTokens();
  const { maxFontSizeMultiplier, ...font } = focus ? T.font.clockFocus : T.font.clock;
  return (
    <Text
      maxFontSizeMultiplier={maxFontSizeMultiplier}
      style={[font, { color: T.color.textPrimary, textAlign: 'center' }, style]}
    >
      {text}
    </Text>
  );
}
