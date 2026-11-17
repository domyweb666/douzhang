// 聚焦模式（2026-11-17 多米看比較頁選 A「翻牌」）：計時中橫放的整頁時鐘。
// 黑底、四張深灰牌倒數、下面一行這顆在做什麼（前面一顆這個類型的小番茄）。淺色深色都是這一組。
// 2026-11-18 AH6：翻牌左邊多一顆在長的番茄（多米「翻牌旁邊也放那顆在長的番茄」）。
// 平常只有時鐘；點一下畫面，底下出現「記一筆」「結束這顆」「回主畫面」，過幾秒自己收起來。
// 記一筆與結束都要打字或選，橫向時鍵盤會蓋掉大半個畫面，所以按了先回直向的主畫面再開那張半頁。
// 版面大小跟著畫面寬（params.zen 的比例）；顏色與翻牌的數字在 Tokens。
import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo,
  Animated,
  Pressable,
  Text,
  View,
  useAnimatedValue,
  useWindowDimensions,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { CharacterColors, useTokens } from '../design/Tokens';
import { words } from '../design/words';
import { params } from '../design/params';
import { growProgress, growScale, ripeColor } from '../core/grow';
import { clockDigits, mmss } from '../ui/useNow';
import { Tomato } from '../ui/Tomato';

const Z = params.zen;
const INK = CharacterColors.tomato;

/**
 * 一張牌。數字換了：牌往後倒、換上新數字、再立回來。減少動態時不翻，直接是新數字。
 * shown 是牌面上現在畫的數字，翻到一半才換成新的。
 */
function FlipCard({ digit, width }) {
  const T = useTokens();
  const [shown, setShown] = useState(digit);
  const fold = useAnimatedValue(0);
  const still = T.reduceMotion;
  const { halfMs, fold: foldTo, perspective } = T.motion.zenFlip;
  useEffect(() => {
    if (still || digit === shown) return undefined;
    let alive = true;
    Animated.timing(fold, { toValue: 1, duration: halfMs, useNativeDriver: true }).start(() => {
      if (!alive) return;
      setShown(digit);
      Animated.timing(fold, { toValue: 0, duration: halfMs, useNativeDriver: true }).start();
    });
    return () => {
      alive = false;
    };
  }, [digit, shown, still, fold, halfMs]);

  const { maxFontSizeMultiplier, ...font } = T.font.zenDigit;
  const height = width * (Z.cardHeight / Z.cardWidth);
  const rotateX = fold.interpolate({ inputRange: [0, 1], outputRange: ['0deg', foldTo] });
  return (
    <Animated.View
      style={{
        width,
        height,
        borderRadius: width * (Z.cardRadius / Z.cardWidth),
        backgroundColor: T.color.zen.card,
        alignItems: 'center',
        justifyContent: 'center',
        transform: [{ perspective: height * perspective }, { rotateX }],
      }}
    >
      <Text
        maxFontSizeMultiplier={maxFontSizeMultiplier}
        style={{
          ...font,
          fontSize: width * (Z.digitSize / Z.cardWidth),
          color: T.color.zen.digit,
        }}
      >
        {still ? digit : shown}
      </Text>
      <View
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: height / 2,
          height: T.shape.zenSeam,
          backgroundColor: T.color.zen.background,
        }}
      />
    </Animated.View>
  );
}

/** 分跟秒中間那兩點。 */
function Colon({ size, gap }) {
  const T = useTokens();
  const dot = {
    width: size,
    height: size,
    borderRadius: size / 2,
    backgroundColor: T.color.zen.dim,
  };
  return (
    <View style={{ gap, paddingHorizontal: size / 2 }}>
      <View style={dot} />
      <View style={dot} />
    </View>
  );
}

/** 四張牌：分分：秒秒。 */
function FlipClock({ digits, screenWidth }) {
  const cardWidth = screenWidth * Z.cardWidth;
  const card = (i) => <FlipCard digit={digits[i]} width={cardWidth} />;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: screenWidth * Z.gap }}>
      {card(0)}
      {card(1)}
      <Colon size={screenWidth * Z.colonDot} gap={screenWidth * Z.colonGap} />
      {card(2)}
      {card(3)}
    </View>
  );
}

/** 翻牌左邊那顆在長的番茄（AH6）：位子固定是全熟大小，番茄從青長成標籤色、從小長到滿（跟主畫面同一套算法）。 */
function ZenTomato({ current, now, color, screenWidth }) {
  const box = screenWidth * Z.tomato;
  const progress = growProgress(current, now);
  const ripe = INK.body[color] || INK.body.red;
  return (
    <View
      accessible={false}
      importantForAccessibility="no-hide-descendants"
      accessibilityElementsHidden
      style={{ width: box, height: box, alignItems: 'center', justifyContent: 'center' }}
    >
      <Tomato
        fill={ripeColor(progress, { unripe: INK.unripe, ripe })}
        size={box * growScale(progress)}
      />
    </View>
  );
}

/** 時鐘下面那一行：這個類型的小番茄＋這顆在做什麼。太長就截掉，不換行。 */
function DoingLine({ color, text, maxWidth }) {
  const T = useTokens();
  if (!text) return null;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: T.space.s, maxWidth }}>
      <Tomato color={color} size={T.shape.blockIcon * 1.5} />
      <Text numberOfLines={1} style={{ ...T.font.body, color: T.color.zen.dim, flexShrink: 1 }}>
        {text}
      </Text>
    </View>
  );
}

function ZenPill({ label, onPress }) {
  const T = useTokens();
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => ({
        minHeight: T.shape.tapMin,
        justifyContent: 'center',
        paddingHorizontal: T.space.l,
        borderRadius: T.shape.radiusPill,
        backgroundColor: T.color.zen.pill,
        opacity: pressed ? T.opacity.pressed : 1,
      })}
    >
      <Text style={{ ...T.font.chip, color: T.color.zen.digit }}>{label}</Text>
    </Pressable>
  );
}

/** 底下三顆鈕：平常是透明的、點不到（讀屏也讀不到）；visible 時淡入。減少動態時不淡，直接有或沒有。 */
function Controls({ visible, onLeave }) {
  const T = useTokens();
  const insets = useSafeAreaInsets();
  const fade = useAnimatedValue(0);
  const fadeMs = T.reduceMotion ? 0 : T.motion.zenControls.fadeMs;
  useEffect(() => {
    const anim = Animated.timing(fade, {
      toValue: visible ? 1 : 0,
      duration: fadeMs,
      useNativeDriver: true,
    });
    anim.start();
    return () => anim.stop();
  }, [visible, fade, fadeMs]);
  return (
    <Animated.View
      pointerEvents={visible ? 'auto' : 'none'}
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        bottom: insets.bottom + T.space.m,
        flexDirection: 'row',
        justifyContent: 'center',
        gap: T.space.m,
        opacity: fade,
      }}
    >
      <ZenPill label={words.quickNote} onPress={() => onLeave('note')} />
      <ZenPill label={words.endThis} onPress={() => onLeave('end')} />
      <ZenPill label={words.zenLeave} onPress={() => onLeave(null)} />
    </Animated.View>
  );
}

/**
 * 點一下畫面顯示按鈕，過 controlsMs 自己收起來。開著讀屏時不自動收：三秒不夠滑到按鈕上。
 * 回 [visible, reveal]。
 */
function useReveal() {
  const [visible, setVisible] = useState(false);
  const timer = useRef(null);
  useEffect(() => () => clearTimeout(timer.current), []);
  const reveal = () => {
    setVisible(true);
    clearTimeout(timer.current);
    AccessibilityInfo.isScreenReaderEnabled()
      .then((reading) => {
        if (!reading) timer.current = setTimeout(() => setVisible(false), Z.controlsMs);
      })
      .catch(() => {});
  };
  return [visible, reveal];
}

/**
 * current：計時中的那顆；color：它的類型的番茄色。
 * onLeave(sheet)：離開聚焦模式；sheet 是 'note'（記一筆）｜'end'（結束這顆）｜null（只是回主畫面）。
 */
export function Focus({ current, now, color, label, onLeave }) {
  const T = useTokens();
  const { width } = useWindowDimensions();
  const [controls, reveal] = useReveal();
  const left = current.endAt - now;
  // 時鐘那層整片可點；三顆鈕是它的兄弟不是小孩，讀屏才滑得到
  return (
    <View style={{ flex: 1, backgroundColor: T.color.zen.background }}>
      <StatusBar hidden />
      <Pressable
        onPress={reveal}
        accessibilityRole="button"
        accessibilityLabel={words.zenScreenA11y(mmss(left))}
        style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: width * Z.lineGap }}
      >
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: width * Z.tomatoGap }}>
          <ZenTomato current={current} now={now} color={color} screenWidth={width} />
          <FlipClock digits={clockDigits(left)} screenWidth={width * Z.clockScale} />
        </View>
        <DoingLine color={color} text={label} maxWidth={width * (1 - Z.cardWidth)} />
      </Pressable>
      <Controls visible={controls} onLeave={onLeave} />
    </View>
  );
}
