// 半頁裡的一列：左邊主字（可帶小副標）、右邊值、選中打勾。類型、估幾顆、結束這顆三個半頁共用。
import { Pressable, Text, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';

export function SheetRow({ title, sub, value, selected, onPress }) {
  const T = useTokens();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected: !!selected }}
      onPress={onPress}
      style={({ pressed }) => ({
        minHeight: T.shape.tapPrimary,
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: T.space.s,
        borderBottomWidth: T.shape.hairline,
        borderBottomColor: T.color.separator,
        opacity: pressed ? T.opacity.pressed : 1,
      })}
    >
      <View style={{ flex: 1 }}>
        <Text style={{ ...T.font.body, color: T.color.textPrimary }}>{title}</Text>
        {sub ? (
          <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.xs }}>
            {sub}
          </Text>
        ) : null}
      </View>
      {value ? <Text style={{ ...T.font.sub, color: T.color.textSecondary }}>{value}</Text> : null}
      {selected ? (
        <Text style={{ ...T.font.body, color: T.color.accentText, marginLeft: T.space.s }}>
          {words.check}
        </Text>
      ) : null}
    </Pressable>
  );
}
