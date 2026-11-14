// 茄紫 Theme 的對比：domy-design 規定的每一組（文字 4.5、非文字 3）都要過，淺深兩種模式。
import { auditTheme } from '@domy/design';
import { douzhangTheme } from '../design/theme';

test('茄紫 Theme 淺深色對比全部及格', () => {
  expect(auditTheme(douzhangTheme)).toEqual([]);
});
