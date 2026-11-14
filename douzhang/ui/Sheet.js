// 半頁（底部卡）：透明 Modal、點遮罩關。Domy 的樣子：白卡、上緣大圓角、小把手、Title 2 標題、footnote 副標。
// 動畫交給系統 Modal（slide），不自己寫 withTiming（Tokens 使用規則 10）。
import { KeyboardAvoidingView, Modal, Platform, Pressable, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTokens } from '../design/Tokens';

export function Sheet({ visible, title, sub, onClose, children }) {
  const T = useTokens();
  const insets = useSafeAreaInsets();
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView
        style={{ flex: 1, justifyContent: 'flex-end' }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <Pressable
          onPress={onClose}
          style={{ flex: 1, backgroundColor: T.color.shadow, opacity: T.opacity.scrim }}
        />
        <View
          style={{
            backgroundColor: T.color.card,
            borderTopLeftRadius: T.shape.radiusSheet,
            borderTopRightRadius: T.shape.radiusSheet,
            paddingHorizontal: T.space.screen,
            paddingTop: T.space.s,
            paddingBottom: insets.bottom + T.space.l,
          }}
        >
          <View
            style={{
              alignSelf: 'center',
              width: T.shape.grabber.width,
              height: T.shape.grabber.height,
              borderRadius: T.shape.radiusPill,
              backgroundColor: T.color.separator,
              marginBottom: T.space.m,
            }}
          />
          <Text
            accessibilityRole="header"
            style={{ ...T.font.section, color: T.color.textPrimary }}
          >
            {title}
          </Text>
          {sub ? (
            <Text
              style={{ ...T.font.caption, color: T.color.textSecondary, marginTop: T.space.xs }}
            >
              {sub}
            </Text>
          ) : null}
          <View style={{ marginTop: T.space.card }}>{children}</View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}
