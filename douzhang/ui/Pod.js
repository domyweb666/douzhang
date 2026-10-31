// 豆莢（豆棚每天一列右邊那串）與葉子。角色色只畫豆子、豆莢、葉子（Tokens 使用規則 2）。
// 作廢是空心圈＋收據裡有字，不靠顏色（使用規則 3）。
import { View } from 'react-native';
import { CharacterColors, useTokens } from '../design/Tokens';
import { words } from '../design/words';

export function Pod({ items }) {
  const T = useTokens();
  const dot = T.shape.podDot;
  const fill = T._dark ? CharacterColors.pod.dark : CharacterColors.pod.light;
  const shade = T._dark ? CharacterColors.podShade.dark : CharacterColors.podShade.light;
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: T.space.xs, alignItems: 'center' }}>
      {items.map((it, i) =>
        it.kind === 'void' ? (
          <View
            key={i}
            accessibilityLabel={words.voidA11y}
            style={{
              width: dot,
              height: dot,
              borderRadius: dot,
              borderWidth: T.shape.hairline,
              borderColor: shade,
            }}
          />
        ) : (
          <View
            key={i}
            style={{
              width: it.units > 1 ? dot * 2 + T.space.xs : dot,
              height: dot,
              borderRadius: dot,
              backgroundColor: fill,
            }}
          />
        ),
      )}
    </View>
  );
}

/** 葉子：一片斜放的圓角葉形，沒有數字、沒有空格。 */
export function Leaf() {
  const T = useTokens();
  const dot = T.shape.podDot;
  const fill = T._dark ? CharacterColors.leaf.dark : CharacterColors.leaf.light;
  return (
    <View
      accessibilityLabel={words.leafA11y}
      style={{
        width: dot * 2,
        height: dot,
        backgroundColor: fill,
        borderTopLeftRadius: dot,
        borderBottomRightRadius: dot,
        transform: [{ rotate: T.shape.leafTilt }],
      }}
    />
  );
}
