// 分段選擇：幾個並排的膠囊，一次只能選一個（作廢原因、估幾顆、休息怎麼算）。選中＝強調底深字，沒選＝系統填色。
import { Pressable, Text, View } from 'react-native';
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
            onPress={() => onChange(o.value)}
            style={{
              minHeight: T.shape.tapMin,
              minWidth: T.shape.tapMin,
              paddingHorizontal: T.space.m,
              borderRadius: T.shape.radiusPill,
              backgroundColor: on ? T.color.accent : T.color.fillButton,
              justifyContent: 'center',
              alignItems: 'center',
            }}
          >
            <Text style={{ ...T.font.chip, color: on ? T.color.onAccent : T.color.textPrimary }}>
              {o.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}
