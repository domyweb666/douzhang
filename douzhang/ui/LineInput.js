// 半頁裡的一行輸入框：卡片底、圓角、sentence 字級。
import { TextInput } from 'react-native';
import { useTokens } from '../design/Tokens';

export function LineInput({ value, onChange, placeholder, maxLength, onSubmit, multiline, style }) {
  const T = useTokens();
  return (
    <TextInput
      autoFocus
      multiline={!!multiline}
      value={value}
      onChangeText={onChange}
      placeholder={placeholder}
      placeholderTextColor={T.color.textSecondary}
      maxLength={maxLength}
      returnKeyType="done"
      blurOnSubmit={!multiline}
      onSubmitEditing={onSubmit}
      style={[
        {
          ...T.font.sentence,
          color: T.color.textPrimary,
          backgroundColor: T.color.background,
          borderRadius: T.shape.radiusButton,
          padding: T.space.m,
          minHeight: T.shape.tapPrimary,
        },
        style,
      ]}
    />
  );
}
