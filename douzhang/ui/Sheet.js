// 半頁（底部卡）：透明 Modal、點遮罩關。Domy 的樣子：白卡、上緣大圓角、小把手、Title 2 標題、footnote 副標。
// 動畫交給系統 Modal（slide），不自己寫 withTiming（Tokens 使用規則 10）。
// 鍵盤開著放不下時：卡片縮到「狀態列以下、鍵盤以上」，標題釘著、內容可捲。
// 原本整張被鍵盤往上頂，類型半頁的名稱框跑到狀態列底下看不到（多米 2026-11-16 TestFlight 截圖）。
import { useEffect, useRef, useState } from 'react';
import {
  Keyboard,
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTokens } from '../design/Tokens';

/** 鍵盤開著時，卡片下緣不用再留 home indicator 的空位（鍵盤已經蓋住那一段）。 */
function useKeyboardOpen() {
  const [open, setOpen] = useState(false);
  useEffect(() => {
    const show = Keyboard.addListener('keyboardWillShow', () => setOpen(true));
    const hide = Keyboard.addListener('keyboardWillHide', () => setOpen(false));
    return () => {
      show.remove();
      hide.remove();
    };
  }, []);
  return open;
}

/**
 * 鍵盤開好後內容放不下時，把打字的那格盡量捲到可見區最上面，它下面的按鈕才露得出來
 * （「這顆」九種類型時實測：輸入框看得到，「記下來」被切一半）。
 * 回傳要掛在 ScrollView 上的 props。輸入框本來就在最上面的半頁（類型）不會動。
 */
function useKeepInputVisible() {
  const scroll = useRef(null);
  const viewport = useRef(0);
  const content = useRef(0);
  useEffect(() => {
    const shown = Keyboard.addListener('keyboardDidShow', () => {
      const input = TextInput.State.currentlyFocusedInput();
      const view = scroll.current;
      if (!input || !view) return;
      input.measureLayout(view.getInnerViewRef(), (x, y, width, height) => {
        const overflow = content.current - viewport.current;
        if (overflow > 0) view.scrollTo({ y: Math.min(y, overflow) });
      });
    });
    return () => shown.remove();
  }, []);
  return {
    ref: scroll,
    onLayout: (e) => {
      viewport.current = e.nativeEvent.layout.height;
    },
    onContentSizeChange: (width, height) => {
      content.current = height;
    },
  };
}

export function Sheet({ visible, title, sub, onClose, children }) {
  const T = useTokens();
  const insets = useSafeAreaInsets();
  const keyboardOpen = useKeyboardOpen();
  const keepInputVisible = useKeepInputVisible();
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView
        style={{ flex: 1, justifyContent: 'flex-end' }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <Pressable
          onPress={onClose}
          style={{
            flex: 1,
            minHeight: insets.top, // 卡片最高只到狀態列下緣
            backgroundColor: T.color.shadow,
            opacity: T.opacity.scrim,
          }}
        />
        <View
          style={{
            flexShrink: 1,
            backgroundColor: T.color.card,
            borderTopLeftRadius: T.shape.radiusSheet,
            borderTopRightRadius: T.shape.radiusSheet,
            paddingHorizontal: T.space.screen,
            paddingTop: T.space.s,
            paddingBottom: (keyboardOpen ? 0 : insets.bottom) + T.space.l,
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
          <ScrollView
            {...keepInputVisible}
            style={{ marginTop: T.space.card }}
            keyboardShouldPersistTaps="handled"
            alwaysBounceVertical={false}
            showsVerticalScrollIndicator={false}
          >
            {children}
          </ScrollView>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}
