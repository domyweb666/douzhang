// 滿版主要按鈕：每個畫面只出現一次（Tokens 使用規則）。primary＝品牌綠底深字；second＝系統填色底。
import { Pressable, Text } from 'react-native';
import { useTokens } from '../design/Tokens';

export function BigButton({ label, onPress, onLongPress, disabled, second, style }) {
  const T = useTokens();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: !!disabled }}
      disabled={disabled}
      onPress={onPress}
      onLongPress={onLongPress}
      style={({ pressed }) => [
        {
          height: T.shape.tapPrimary,
          borderRadius: T.shape.radiusButton,
          backgroundColor: second ? T.color.fillButton : T.color.accent,
          alignItems: 'center',
          justifyContent: 'center',
          opacity: disabled ? T.opacity.disabled : pressed ? T.opacity.pressed : 1,
        },
        style,
      ]}
    >
      <Text
        style={[
          second ? T.font.button2 : T.font.button,
          { color: second ? T.color.textPrimary : T.color.onAccent },
        ]}
      >
        {label}
      </Text>
    </Pressable>
  );
}
