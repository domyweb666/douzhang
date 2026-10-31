// 左右兩頁（番茄架、設定）的大標題，取代原本「回去＋置中小標」的導覽列（改成左右滑之後沒有「回去」）。
import { Text } from 'react-native';
import { useTokens } from '../design/Tokens';

export function PageTitle({ children }) {
  const T = useTokens();
  return (
    <Text
      accessibilityRole="header"
      style={{ ...T.font.largeTitle, color: T.color.textPrimary, marginTop: T.space.s }}
    >
      {children}
    </Text>
  );
}
