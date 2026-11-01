// 文字鈕：44pt 高。預設強調色＋粗一級（「打開通知」這種可點的連結；R5 後強調色沒有色相，靠字重）；secondary＝次要色（「這顆不留話」這種退讓的動作）；
// danger＝紅字（只有「清空所有資料」，S5）。
import { Pressable, Text } from 'react-native';
import { useTokens } from '../design/Tokens';

const textColor = (T, { secondary, danger }) =>
  danger ? T.color.danger : secondary ? T.color.textSecondary : T.color.accentText;

/** flush＝貼齊左邊（導覽列、群組裡的那一列），不加左右內距。 */
/** a11yLabel：字本身讀不出意思時（例如「‹」）給讀屏的名字。 */
export function TextButton({ label, onPress, secondary, danger, flush, style, a11yLabel }) {
  const T = useTokens();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={a11yLabel}
      onPress={onPress}
      style={({ pressed }) => [
        {
          minHeight: T.shape.tapMin,
          justifyContent: 'center',
          paddingHorizontal: flush ? undefined : T.space.s,
          opacity: pressed ? T.opacity.pressed : 1,
        },
        style,
      ]}
    >
      <Text
        style={{
          ...(secondary || danger ? T.font.body : T.font.bodyStrong),
          color: textColor(T, { secondary, danger }),
        }}
      >
        {label}
      </Text>
    </Pressable>
  );
}
