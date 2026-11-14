// 滿版按鈕（Domy 膠囊按鈕的樣子）：primary＝茄紫底，每個畫面只出現一次；second＝中性填色底。
// 不直接用 DomyButton：開始鈕要長按（開發期測試顆），DomyButton 沒有 onLongPress，照 Domy README「缺元件就在 App 裡用代號組」。
import { Pressable, Text } from 'react-native';
import * as Haptics from 'expo-haptics';
import { pressFeedback } from '@domy/design';
import { useTokens } from '../design/Tokens';
import { params } from '../design/params';

export function BigButton({ label, onPress, onLongPress, disabled, second, style }) {
  const T = useTokens();
  const bg = disabled ? T.color.fillButton : second ? T.color.fillButton : T.color.accent;
  const fg = disabled ? T.color.disabledText : second ? T.color.textPrimary : T.color.onAccent;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: !!disabled }}
      disabled={disabled}
      onPress={() => {
        if (!second) Haptics.selectionAsync().catch(() => {}); // 同 DomyButton：主要按鈕輕觸一下
        onPress?.();
      }}
      onLongPress={onLongPress}
      delayLongPress={params.devLongPressMs}
      style={({ pressed }) => [
        {
          height: T.shape.tapPrimary,
          borderRadius: T.shape.radiusPill,
          paddingHorizontal: T.space.l,
          backgroundColor: bg,
          alignItems: 'center',
          justifyContent: 'center',
        },
        pressFeedback(pressed, T.reduceMotion),
        style,
      ]}
    >
      <Text numberOfLines={1} style={[T.font.button, { color: fg }]}>
        {label}
      </Text>
    </Pressable>
  );
}
