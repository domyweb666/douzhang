// 番茄元件測試：五個類型色都有色碼、畫得出來、不認得的色畫成紅的。好不好看要在手機上看。
import { act } from 'react';
import { createRoot } from 'test-renderer';
import { CharacterColors } from '../design/Tokens';
import { params } from '../design/params';
import { Tomato } from '../ui/Tomato';

const BODY = CharacterColors.tomato.body;

async function drawn(color) {
  const root = createRoot();
  await act(async () => {
    root.render(<Tomato color={color} size={56} />);
  });
  return JSON.stringify(root.container.toJSON());
}

test('設定能選的每一個番茄色都有自己的色碼，彼此不重複', () => {
  const codes = params.tomatoColors.map((c) => BODY[c]);
  expect(codes.every(Boolean)).toBe(true);
  expect(new Set(codes).size).toBe(params.tomatoColors.length);
});

test('五個色畫出來各不相同', async () => {
  const pictures = [];
  for (const c of params.tomatoColors) pictures.push(await drawn(c));
  expect(new Set(pictures).size).toBe(params.tomatoColors.length);
});

test('不認得的色（舊資料、被刪的類型）畫成紅的', async () => {
  const red = await drawn('red');
  expect(await drawn(undefined)).toBe(red);
  expect(await drawn('teal')).toBe(red);
});
