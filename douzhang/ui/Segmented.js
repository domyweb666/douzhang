// 分段選擇：幾個並排的膠囊，一次只能選一個（作廢原因、類型、休息怎麼算）。
// Domy 的選項膠囊：選中＝產品色淡底（soft）＋產品色字，沒選＝中性填色。選中另外加粗，不只靠顏色。
import { Pressable, Text, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { useTokens } from '../design/Tokens';

export function Segmented({ options, value, onChange, style }) {
  const T = useTokens();
  return (
    <View style={[{ flexDirection: 'row', flexWrap: 'wrap', gap: T.space.s }, style]}>
      {options.map((o) => {
        const on = o.value === value;
        return (
          <Pressable
            key={String(o.value)}
            accessibilityRole="button"
            accessibilityState={{ selected: on }}
            onPress={() => {
              if (!on) Haptics.selectionAsync().catch(() => {}); // Tokens.haptic.select：換類型、分段切換
              onChange(o.value);
            }}
            style={({ pressed }) => ({
              minHeight: T.shape.tapMin,
              minWidth: T.shape.tapMin,
              paddingHorizontal: T.space.card,
              borderRadius: T.shape.radiusPill,
              backgroundColor: on ? T.color.soft : T.color.fillButton,
              justifyContent: 'center',
              alignItems: 'center',
              opacity: pressed ? T.opacity.pressed : 1,
            })}
          >
            <Text
              style={{
                ...(on ? T.font.chip : T.font.sub),
                color: on ? T.color.accentText : T.color.textPrimary,
              }}
            >
              {o.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}
