// 左右滑三頁（2026-11-01 多米：番茄架在左、主畫面在中、設定在右，照 PWA 那樣滑）。上面一排小圓點，點了也能跳頁。
// 用 RN 內建的橫向 ScrollView 分頁，不裝導覽套件（憲法：不准 navigation 套件）。
import { Children, useEffect, useRef } from 'react';
import { Pressable, ScrollView, View, useWindowDimensions } from 'react-native';
import { useTokens } from '../design/Tokens';

/** 頁碼小圓點：目前那頁是長膠囊、深一點。 */
function Dots({ labels, page, onPage }) {
  const T = useTokens();
  return (
    <View
      style={{
        height: T.shape.tapMin,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        gap: T.space.s,
      }}
    >
      {labels.map((label, i) => {
        const on = i === page;
        return (
          <Pressable
            key={label}
            accessibilityRole="button"
            accessibilityLabel={label}
            accessibilityState={{ selected: on }}
            hitSlop={T.space.s}
            onPress={() => onPage(i)}
            style={{
              width: on ? T.shape.pageDotActive : T.shape.pageDot,
              height: T.shape.pageDot,
              borderRadius: T.shape.radiusPill,
              backgroundColor: on ? T.color.textSecondary : T.color.separator,
            }}
          />
        );
      })}
    </View>
  );
}

/**
 * page：現在是第幾頁（呼叫端管）；onPage：滑完或點圓點時回報新頁碼。
 * page 從外面改（例如鈴響收下後回主畫面）時自己捲過去。labels：每頁的讀屏名，也是圓點的 key。
 */
export function Pager({ page, onPage, labels, children }) {
  const T = useTokens();
  const { width } = useWindowDimensions();
  const ref = useRef(null);
  useEffect(() => {
    ref.current?.scrollTo({ x: page * width, animated: true });
  }, [page, width]);
  return (
    <View style={{ flex: 1 }}>
      <Dots labels={labels} page={page} onPage={onPage} />
      <ScrollView
        ref={ref}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        contentOffset={{ x: page * width, y: 0 }}
        onMomentumScrollEnd={(e) => onPage(Math.round(e.nativeEvent.contentOffset.x / width))}
      >
        {Children.toArray(children).map((child, i) => (
          <View key={labels[i]} style={{ width, paddingHorizontal: T.space.l }}>
            {child}
          </View>
        ))}
      </ScrollView>
    </View>
  );
}
