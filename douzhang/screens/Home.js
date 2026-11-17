// 主畫面。三態：待機、計時中、休息（鈴響是另一頁 screens/Bell.js）。
// 2026-11-17 AG 換核心（種番茄＋時間帳本）：拿掉「這顆要做」那張卡、第一次的輸入框、收工那行、估幾顆。
// 2026-11-18 AH2 多米看主畫面比較頁：待機照原樣（標籤膠囊、大時間、背景音、開始鈕、番茄堆）；
// 計時中與休息改成「番茄就是時鐘」：左上標籤、右上「⋯」，中間一圈進度環圍著那顆番茄，時間在環下面。
// 計時中點畫面空白處就記一筆；原本那排鈕與底部「結束這顆」收進「⋯」。
// AH3：番茄堆只在待機畫面掛上，剛收的那顆休息完回到待機才從上面掉進去（罐子靠 jarSeen 知道哪顆還沒看過）。
// 子元件全放模組層級（規矩檔：元件不准定義在元件函式裡）。
import { useEffect, useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { DomyButton, DomyIconButton, pressFeedback, useTabBarClearance } from '@domy/design';
import { CharacterColors, useTokens } from '../design/Tokens';
import { words, startLabel, tagLabel } from '../design/words';
import { MS_PER_MINUTE, params } from '../design/params';
import { DEV_TYPE, PHASE, stoppedEarly, typeOf } from '../core/machine';
import { growProgress, growScale, ripeColor } from '../core/grow';
import { BigButton } from '../ui/BigButton';
import { Clock } from '../ui/Clock';
import { mmss } from '../ui/useNow';
import { EndSheet, MoreSheet, NoteSheet, VoidSheet } from '../ui/FocusSheets';
import { TagPickSheet } from '../ui/TagSheets';
import { SoundSheet } from '../ui/SoundSheet';
import { Jar } from '../ui/Jar';
import { Tomato } from '../ui/Tomato';
import { RingTomato } from '../ui/RingTomato';

const INK = CharacterColors.tomato;

/** 時間下面的小字（休息的小標與那句、提早做完的提醒）。 */
function Caption({ children }) {
  const T = useTokens();
  return (
    <Text
      style={{
        ...T.font.sub,
        color: T.color.textSecondary,
        textAlign: 'center',
        marginTop: T.space.xs,
      }}
    >
      {children}
    </Text>
  );
}

/** 標籤膠囊：小番茄＋「專注・25 分」。待機時可點（開標籤半頁，後面多一個 ›）；計時中、休息只是標示。 */
function TagChip({ type, onPress }) {
  const T = useTokens();
  return (
    <Pressable
      disabled={!onPress}
      accessibilityRole={onPress ? 'button' : undefined}
      onPress={onPress}
      style={({ pressed }) => [
        {
          flexDirection: 'row',
          alignItems: 'center',
          gap: T.space.xs,
          minHeight: T.shape.tapMin,
          paddingHorizontal: T.space.card,
          borderRadius: T.shape.radiusPill,
          backgroundColor: T.color.soft,
        },
        onPress ? pressFeedback(pressed, T.reduceMotion) : null,
      ]}
    >
      <Tomato color={type.color} size={T.shape.blockIcon} />
      <Text style={{ ...T.font.chip, color: T.color.accentText }}>{tagLabel(type, !!onPress)}</Text>
    </Pressable>
  );
}

/** 待機：照 AH 之前的樣子（多米 2026-11-18 選現況）。開發期快轉：長按開始＝5 秒測試顆；設定開了「測試模式」就直接是測試鈕。 */
function IdleBlock({ type, sound, testMode, onTag, onSound, onStart }) {
  const T = useTokens();
  const clearance = useTabBarClearance();
  const devStart = __DEV__ ? () => onStart({ typeId: DEV_TYPE.id }) : undefined;
  return (
    <>
      <View style={{ alignSelf: 'center', marginTop: T.space.m }}>
        <TagChip type={type} onPress={onTag} />
      </View>
      <Clock focus text={mmss(type.len * MS_PER_MINUTE)} />
      <DomyButton
        variant="secondary"
        size="compact"
        title={sound}
        onPress={onSound}
        style={{ alignSelf: 'center', marginTop: T.space.m }}
      />
      <View style={{ flex: 1 }} pointerEvents="none" />
      {__DEV__ && testMode ? (
        <BigButton label={words.startTest(DEV_TYPE.len)} onPress={devStart} />
      ) : (
        <BigButton
          label={startLabel(words.start, type.len)}
          onPress={() => onStart({})}
          onLongPress={devStart}
        />
      )}
      <View style={{ height: T.shape.pileRoom + clearance }} pointerEvents="none" />
    </>
  );
}

/** 計時中與休息最上面那條：左邊標籤，右邊「⋯」（只有計時中有；休息時沒有半頁）。 */
function TopBar({ type, onMore }) {
  const T = useTokens();
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginTop: T.space.m,
      }}
    >
      <TagChip type={type} />
      {onMore ? (
        <DomyIconButton title={words.more} label={words.moreA11y} tone="neutral" onPress={onMore} />
      ) : null}
    </View>
  );
}

/** 環畫多大：最大 ringSize，不超過中間那塊的寬，也不超過它高度的 ringRoom 成（下面要放時間）。 */
function useRingSize() {
  const T = useTokens();
  const [room, setRoom] = useState(null);
  const onLayout = (e) => setRoom(e.nativeEvent.layout);
  const size = room
    ? Math.min(T.shape.ringSize, room.width, room.height * T.shape.ringRoom)
    : T.shape.ringSize;
  return [size, onLayout];
}

/** 計時中：環是標籤的番茄色，裡面那顆從青長成標籤色（AG2、AH1）；整塊點一下開記一筆。 */
function FocusRing({ current, now, type, onNote }) {
  const T = useTokens();
  const [size, onLayout] = useRingSize();
  const progress = growProgress(current, now);
  const ripe = INK.body[type.color] || INK.body.red;
  return (
    <Pressable
      onLayout={onLayout}
      onPress={onNote}
      accessibilityRole="button"
      accessibilityLabel={words.quickNote}
      accessibilityHint={words.tapNoteHint}
      style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}
    >
      <RingTomato
        size={size}
        progress={progress}
        ringColor={ripe}
        fill={ripeColor(progress, { unripe: INK.unripe, ripe })}
        scale={growScale(progress)}
      />
      <Clock ring text={mmss(current.endAt - now)} style={{ marginTop: T.space.m }} />
      {current.done ? <Caption>{words.doneEarlyLine}</Caption> : null}
    </Pressable>
  );
}

/** 休息：環是藤的綠、倒數休息；裡面一顆還沒長的小青番茄。「我自己決定」的休息沒有終點，環不走、時間往上數。 */
function RestRing({ current, now }) {
  const T = useTokens();
  const [size, onLayout] = useRingSize();
  const self = current.endAt == null; // 看資料不看設定：休息中改設定也不會卡住
  const span = self ? 0 : current.endAt - current.restStart;
  const progress = span > 0 ? (now - current.restStart) / span : 0;
  return (
    <View onLayout={onLayout} style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      <RingTomato
        size={size}
        progress={progress}
        ringColor={INK.vine}
        fill={INK.unripe}
        scale={params.grow.minScale}
      />
      <Clock
        ring
        text={mmss(self ? now - current.restStart : current.endAt - now)}
        style={{ marginTop: T.space.m }}
      />
      <Caption>{current.long ? words.restLongRow : words.rest}</Caption>
      <Caption>{words.restBody}</Caption>
      {current.msg ? <Caption>{current.msg}</Caption> : null}
    </View>
  );
}

/** W3：番茄在整個畫面後面掉、滾、堆在最下面（頁面左右有內距，這層往外撐到螢幕邊）。AH3 起只在待機掛上。 */
function FullScreenJar({ state, jarSeen }) {
  const T = useTokens();
  const clearance = useTabBarClearance(); // 番茄堆在分頁列上面，不被它蓋住
  // 今天的番茄依時間排；大小跟分鐘走（V4）、顏色跟標籤（W1）
  const todayBeans = (state.days[state.todayKey]?.beans || [])
    .slice()
    .sort((a, b) => a.t - b.t)
    .map((b) => ({ len: b.len, color: typeOf(state, b.typeId).color }));
  return (
    <View
      style={{
        position: 'absolute',
        top: 0,
        bottom: clearance - T.space.card,
        left: -T.space.screen,
        right: -T.space.screen,
      }}
    >
      <Jar
        beans={todayBeans}
        seenRef={jarSeen}
        sound={state.settings.sound}
        tilt={state.settings.tilt}
      />
    </View>
  );
}

/**
 * 主畫面現在開著哪張半頁：null｜'more'｜'note'｜'end'｜'void'｜'tag'｜'sound'。
 * initial：從聚焦模式按「記一筆」「結束這顆」回來時是 'note'｜'end'，掛上來就直接開那張；
 * 開了就告訴殼（onOpened）把它清掉，下一顆不會自己跳出來。
 * endEarly：打開「結束這顆」那一刻固定的判斷——那時開始不到五分鐘嗎。
 */
function useHomeSheet({ initialSheet: initial, onInitialSheetOpened: onOpened }, current, now) {
  const [sheet, setSheet] = useState(initial);
  const [endEarly, setEndEarly] = useState(
    () => initial === 'end' && !!current && stoppedEarly(current, now),
  );
  useEffect(() => {
    if (initial) onOpened();
  }, [initial, onOpened]);
  const openEnd = () => {
    setEndEarly(stoppedEarly(current, now));
    setSheet('end');
  };
  return { sheet, setSheet, endEarly, openEnd };
}

/** zen：聚焦模式的三樣——onEnter 進去；initialSheet、onInitialSheetOpened 見 useHomeSheet。 */
export function Home({ state, phase, now, jarSeen, actions, zen }) {
  const T = useTokens();
  const clearance = useTabBarClearance();
  const { sheet, setSheet, endEarly, openEnd } = useHomeSheet(zen, state.current, now);
  const idle = phase === PHASE.idle;
  const focus = phase === PHASE.focus;
  // 待機看的是選中的標籤；計時中、休息看的是這顆開始時的標籤（中途去設定改選別的也不會變）
  const type = typeOf(state, idle ? state.settings.typeId : state.current.typeId);
  const sound = words.ambienceChip(state.settings.ambience); // 白噪音那顆鈕上的字：選了哪一種（AG6）
  const onMorePick = (next) => {
    if (next === 'zen') {
      setSheet(null);
      zen.onEnter();
    } else if (next === 'end') openEnd();
    else setSheet(next);
  };

  // 待機：前景層 box-none，空白處的點擊穿過去給罐子（點了番茄會彈），按鈕照常按。
  if (idle)
    return (
      <View style={{ flex: 1 }}>
        <FullScreenJar state={state} jarSeen={jarSeen} />
        <View style={{ flex: 1 }} pointerEvents="box-none">
          <IdleBlock
            type={type}
            sound={sound}
            testMode={state.settings.demo}
            onTag={() => setSheet('tag')}
            onSound={() => setSheet('sound')}
            onStart={actions.onStart}
          />
        </View>
        <HomeSheets
          phase={phase}
          sheet={sheet}
          setSheet={setSheet}
          state={state}
          actions={actions}
        />
      </View>
    );

  return (
    <View style={{ flex: 1 }}>
      <TopBar type={type} onMore={focus ? () => setSheet('more') : undefined} />
      {focus ? (
        <FocusRing current={state.current} now={now} type={type} onNote={() => setSheet('note')} />
      ) : (
        <RestRing current={state.current} now={now} />
      )}
      {phase === PHASE.rest ? (
        <BigButton label={words.backFromRest} onPress={actions.onBackFromRest} />
      ) : null}
      <View style={{ height: clearance + T.space.m }} pointerEvents="none" />
      <HomeSheets
        phase={phase}
        sheet={sheet}
        setSheet={setSheet}
        state={state}
        early={endEarly}
        actions={actions}
        onMorePick={onMorePick}
        soundValue={words.ambienceKinds[state.settings.ambience]}
      />
    </View>
  );
}

/** 主畫面的半頁都掛在這裡：計時中的四張（⋯、記一筆、結束、作廢）、待機的標籤、兩邊都有的白噪音。休息時沒有半頁。 */
function HomeSheets({ phase, sheet, setSheet, state, early, actions, onMorePick, soundValue }) {
  const idle = phase === PHASE.idle;
  const focus = phase === PHASE.focus;
  const close = () => setSheet(null);
  const c = state.current;
  return (
    <>
      {focus ? (
        <>
          <MoreSheet
            visible={sheet === 'more'}
            noteCount={(c.notes?.length || 0) + (c.pings?.length || 0)}
            soundValue={soundValue}
            onClose={close}
            onPick={onMorePick}
          />
          <FocusSheetHost
            sheet={sheet}
            setSheet={setSheet}
            current={c}
            early={early}
            onJot={actions.onJot}
            onDoneEarly={actions.onDoneEarly}
            onVoid={actions.onVoid}
          />
        </>
      ) : null}
      {idle ? (
        <TagPickSheet
          key={`tag-${sheet}`} // 每次打開都從標籤格開始，不會停在上次的「新標籤」編輯
          visible={sheet === 'tag'}
          settings={state.settings}
          actions={actions}
          onClose={close}
        />
      ) : null}
      {idle || focus ? (
        <SoundSheet
          visible={sheet === 'sound'}
          preview={idle} // 待機時邊選邊聽；計時中本來就在播
          settings={state.settings}
          actions={actions}
          onClose={close}
        />
      ) : null}
    </>
  );
}

/** 計時中的三個半頁掛在這裡；key 讓每次打開都是乾淨的輸入框。 */
function FocusSheetHost({ sheet, setSheet, current, early, onJot, onDoneEarly, onVoid }) {
  const close = () => setSheet(null);
  return (
    <>
      <NoteSheet key={`note-${sheet}`} visible={sheet === 'note'} onClose={close} onJot={onJot} />
      <EndSheet
        visible={sheet === 'end'}
        current={current}
        early={early}
        onClose={close}
        onDoneEarly={onDoneEarly}
        onVoid={(early) => {
          if (early) {
            close();
            onVoid({ early: true });
          } else setSheet('void');
        }}
      />
      <VoidSheet
        key={`void-${sheet}`}
        visible={sheet === 'void'}
        onClose={close}
        onVoid={(v) => {
          close();
          onVoid(v);
        }}
      />
    </>
  );
}
