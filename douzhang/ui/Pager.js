// 左右滑三頁（2026-11-01 多米：番茄架在左、主畫面在中、設定在右，照 PWA 那樣滑）。
// 2026-11-14 照 Domy 重新設計：上面的小圓點拿掉，換成下面的懸浮分頁列（PageTabs），左右滑照樣能用。
// 用 RN 內建的橫向 ScrollView 分頁，不裝導覽套件（憲法：不准 navigation 套件）。
import { Children, useEffect, useRef } from 'react';
import { ScrollView, View, useWindowDimensions } from 'react-native';
import { DomyTabBar } from '@domy/design';
import { useTokens } from '../design/Tokens';

/**
 * page：現在是第幾頁（呼叫端管）；onPage：滑完時回報新頁碼。
 * page 從外面改（例如點分頁列、鈴響收下後回主畫面）時自己捲過去。labels：每頁的 key。
 * locked：不能左右滑（2026-11-18 AH5 多米：計時中不能切頁）。
 */
export function Pager({ page, onPage, labels, locked, children }) {
  const T = useTokens();
  const { width } = useWindowDimensions();
  const ref = useRef(null);
  useEffect(() => {
    ref.current?.scrollTo({ x: page * width, animated: true });
  }, [page, width]);
  return (
    <ScrollView
      ref={ref}
      horizontal
      pagingEnabled
      scrollEnabled={!locked}
      showsHorizontalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
      contentOffset={{ x: page * width, y: 0 }}
      onMomentumScrollEnd={(e) => onPage(Math.round(e.nativeEvent.contentOffset.x / width))}
    >
      {Children.toArray(children).map((child, i) => (
        <View key={labels[i]} style={{ width, paddingHorizontal: T.space.screen }}>
          {child}
        </View>
      ))}
    </ScrollView>
  );
}

/**
 * 下面的懸浮分頁列（DomyTabBar）。DomyTabBar 吃 react-navigation 形狀的 props，
 * 豆帳沒有導覽套件，這裡用三頁的頁碼湊出那個形狀。tabs：[{ label, Icon }]。
 */
export function PageTabs({ page, onPage, tabs }) {
  const routes = tabs.map((_, i) => ({ key: String(i), name: String(i) }));
  const descriptors = Object.fromEntries(
    tabs.map(({ label, Icon }, i) => [
      String(i),
      {
        options: {
          title: label,
          tabBarIcon: ({ color, size }) => <Icon color={color} size={size} />,
        },
      },
    ]),
  );
  const navigation = {
    emit: () => ({ defaultPrevented: false }),
    navigate: (name) => onPage(Number(name)),
  };
  return (
    <DomyTabBar state={{ index: page, routes }} descriptors={descriptors} navigation={navigation} />
  );
}
