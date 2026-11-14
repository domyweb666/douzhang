// 左右兩頁（番茄架、設定）的大標題：Domy 的 largeTitle，同 DomyScreen 的頁標。
import { DomyText } from '@domy/design';
import { useTokens } from '../design/Tokens';

export function PageTitle({ children }) {
  const T = useTokens();
  return (
    <DomyText variant="largeTitle" accessibilityRole="header" style={{ marginTop: T.space.s }}>
      {children}
    </DomyText>
  );
}
