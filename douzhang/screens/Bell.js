// 鈴響・寫一句（方向 A：底部收下，貼鍵盤上緣）。
// A2 只有輸入框與收下；「這顆不留話」守門與「再做 15／30」是 A5，念頭列表是 B1。
import { Text, TextInput, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { BigButton } from '../ui/BigButton';

export function Bell({ draft, onDraft, onKeep }) {
  const T = useTokens();
  return (
    <View style={{ flex: 1 }}>
      <View style={{ marginTop: T.space.l }}>
        <Text style={{ ...T.font.title, color: T.color.textPrimary }}>{words.rang}</Text>
        <Text style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.xs }}>
          {words.bellSub}
        </Text>
      </View>
      <TextInput
        autoFocus
        multiline
        maxLength={params.firstLineMaxChars}
        value={draft}
        onChangeText={onDraft}
        placeholder={words.bellPlaceholder}
        placeholderTextColor={T.color.textSecondary}
        style={{
          ...T.font.sentence,
          color: T.color.textPrimary,
          backgroundColor: T.color.card,
          borderRadius: T.shape.radiusButton,
          padding: T.space.m,
          marginTop: T.space.m,
          minHeight: T.shape.tapPrimary * 2,
        }}
      />
      <View style={{ flex: 1 }} />
      <BigButton label={words.keepThis} onPress={() => onKeep(draft)} />
    </View>
  );
}
