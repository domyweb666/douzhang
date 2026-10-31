// 半頁（底部卡）：透明 Modal、點遮罩關、卡片圓角 radiusSheet。標題 section、副標 caption，內容由呼叫端放。
// 動畫交給系統 Modal（slide），不自己寫 withTiming（Tokens 使用規則 10）。
import { KeyboardAvoidingView, Modal, Platform, Pressable, Text, View } from 'react-native';
import { useTokens } from '../design/Tokens';

export function Sheet({ visible, title, sub, onClose, children }) {
  const T = useTokens();
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView
        style={{ flex: 1, justifyContent: 'flex-end' }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <Pressable
          onPress={onClose}
          style={{ flex: 1, backgroundColor: T.color.separator, opacity: T.opacity.disabled }}
        />
        <View
          style={{
            backgroundColor: T.color.card,
            borderTopLeftRadius: T.shape.radiusSheet,
            borderTopRightRadius: T.shape.radiusSheet,
            paddingHorizontal: T.space.l,
            paddingTop: T.space.l,
            paddingBottom: T.space.xl,
          }}
        >
          <Text style={{ ...T.font.section, color: T.color.textPrimary }}>{title}</Text>
          {sub ? (
            <Text
              style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.xs }}
            >
              {sub}
            </Text>
          ) : null}
          <View style={{ marginTop: T.space.m }}>{children}</View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}
