// 半頁裡的一行輸入框（Domy 輸入框的樣子）：白底、細框，打字時框換產品色。
// 不用 DomyTextField：它規定標籤一定在框外，這幾個框的提示字是詞彙表定的 placeholder，沒有標籤。
import { useState } from 'react';
import { TextInput } from 'react-native';
import { useTokens } from '../design/Tokens';

export function LineInput({ value, onChange, placeholder, maxLength, onSubmit, multiline, style }) {
  const T = useTokens();
  const [focused, setFocused] = useState(false);
  return (
    <TextInput
      autoFocus
      multiline={!!multiline}
      value={value}
      onChangeText={onChange}
      placeholder={placeholder}
      placeholderTextColor={T.color.textSecondary}
      selectionColor={T.color.accent}
      maxLength={maxLength}
      returnKeyType="done"
      blurOnSubmit={!multiline}
      onSubmitEditing={onSubmit}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      style={[
        {
          ...T.font.body,
          color: T.color.textPrimary,
          backgroundColor: T.color.card,
          borderWidth: T.shape.hairline,
          borderColor: focused ? T.color.accent : T.color.fieldBorder,
          borderRadius: T.shape.radiusButton,
          paddingHorizontal: T.space.card,
          paddingVertical: T.space.m,
          minHeight: T.shape.field,
        },
        style,
      ]}
    />
  );
}
