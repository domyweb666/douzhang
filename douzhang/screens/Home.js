// 主畫面。三態：待機、計時中、休息（鈴響是另一頁 screens/Bell.js）。
// 2026-11-17 AG 換核心（種番茄＋時間帳本）：拿掉「這顆要做」那張卡、第一次的輸入框、收工那行、估幾顆。
// 由上到下：標籤膠囊、大時間、（計時中）記一筆與聚焦模式、中間是長大的番茄（休息時是火柴人）、開始鈕、番茄堆。
// 番茄堆在整個畫面後面（W3）。子元件全放模組層級（規矩檔：元件不准定義在元件函式裡）。
import { useCallback, useEffect, useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { DomyButton, pressFeedback, useTabBarClearance } from '@domy/design';
import { Token, useTokens } from '../design/Tokens';
import { words, startLabel, tagLabel } from '../design/words';
import { MS_PER_MINUTE } from '../design/params';
import { DEV_TYPE, PHASE, stoppedEarly, typeOf } from '../core/machine';
import { growProgress } from '../core/grow';
import { BigButton } from '../ui/BigButton';
import { Clock } from '../ui/Clock';
import { mmss } from '../ui/useNow';
import { EndSheet, NoteSheet, VoidSheet } from '../ui/FocusSheets';
import { TagPickSheet } from '../ui/TagSheets';
import { SoundSheet } from '../ui/SoundSheet';
import { Jar } from '../ui/Jar';
import { TextButton } from '../ui/TextButton';
import { Mascot } from '../ui/Mascot';
import { Tomato } from '../ui/Tomato';
import { GrowingTomato } from '../ui/GrowingTomato';

/** 大時間下面的小字（休息的小標與那句、提早做完的提醒）。 */
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

/** 最上面那顆膠囊：小番茄＋「專注・25 分」。待機時可點（開標籤半頁，後面多一個 ›）；計時中、休息只是標示。 */
function TagChip({ type, onPress }) {
  const T = useTokens();
  return (
    <Pressable
      disabled={!onPress}
      accessibilityRole={onPress ? 'button' : undefined}
      onPress={onPress}
      style={({ pressed }) => [
        {
          alignSelf: 'center',
          flexDirection: 'row',
          alignItems: 'center',
          gap: T.space.xs,
          minHeight: T.shape.tapMin,
          paddingHorizontal: T.space.card,
          borderRadius: T.shape.radiusPill,
          backgroundColor: T.color.soft,
          marginTop: T.space.m,
        },
        onPress ? pressFeedback(pressed, T.reduceMotion) : null,
      ]}
    >
      <Tomato color={type.color} size={T.shape.blockIcon} />
      <Text style={{ ...T.font.chip, color: T.color.accentText }}>{tagLabel(type, !!onPress)}</Text>
    </Pressable>
  );
}

/** 大時間：待機是這個標籤的長度，計時中倒數，休息倒數（「我自己決定」的休息數正數）。 */
function TimeBlock({ phase, current, now, type }) {
  if (phase === PHASE.focus)
    return (
      <View>
        <Clock focus text={mmss(current.endAt - now)} />
        {current.done ? <Caption>{words.doneEarlyLine}</Caption> : null}
      </View>
    );
  if (phase === PHASE.rest) {
    const self = current.endAt == null; // 看資料不看設定：休息中改設定也不會卡住
    return (
      <View>
        <Clock focus text={mmss(self ? now - current.restStart : current.endAt - now)} />
        <Caption>{current.long ? words.restLongRow : words.rest}</Caption>
        <Caption>{words.restBody}</Caption>
        {current.msg ? <Caption>{current.msg}</Caption> : null}
      </View>
    );
  }
  return <Clock focus text={mmss(type.len * MS_PER_MINUTE)} />;
}

/**
 * 計時中大時間下面那兩顆：「記一筆」（U6：念頭與有人找合成一顆，半頁裡再選；記過幾筆就在後面帶數字）
 * 與「聚焦模式」（2026-11-17：換成橫向的整頁時鐘），再加白噪音那顆（AG6）。放不下會換行。
 */
function FocusChips({ current, sound, onNote, onZen, onSound }) {
  const T = useTokens();
  const count = (current.notes?.length || 0) + (current.pings?.length || 0);
  return (
    <View
      style={{
        flexDirection: 'row',
        flexWrap: 'wrap',
        justifyContent: 'center',
        gap: T.space.s,
        marginTop: T.space.m,
      }}
    >
      <DomyButton
        variant="secondary"
        size="compact"
        title={words.countLabel(words.quickNote, count)}
        onPress={onNote}
      />
      <DomyButton variant="secondary" size="compact" title={words.zenEnter} onPress={onZen} />
      <DomyButton variant="secondary" size="compact" title={sound} onPress={onSound} />
    </View>
  );
}

function PrimaryButton({ phase, len, testMode, onStart, onBackFromRest, onEnd }) {
  // 開發期快轉：長按開始＝5 秒測試顆；設定開了「測試模式」就直接是測試鈕。正式 build 兩個都沒有。
  const devStart = __DEV__ ? () => onStart({ typeId: DEV_TYPE.id }) : undefined;
  if (phase === PHASE.rest)
    return <BigButton label={words.backFromRest} onPress={onBackFromRest} />;
  // U6：計時中不放大按鈕，結束降成底部文字鈕（不誘人按、也少誤觸）
  if (phase === PHASE.focus)
    return (
      <TextButton secondary label={words.endThis} onPress={onEnd} style={{ alignSelf: 'center' }} />
    );
  if (phase !== PHASE.idle) return null;
  if (__DEV__ && testMode)
    return <BigButton label={words.startTest(DEV_TYPE.len)} onPress={devStart} />;
  return (
    <BigButton
      label={startLabel(words.start, len)}
      onPress={() => onStart({})}
      onLongPress={devStart}
    />
  );
}

/** W3：番茄在整個畫面後面掉、滾、堆在最下面（頁面左右有內距，這層往外撐到螢幕邊）。 */
function FullScreenJar({ state, jarSeen, onLand }) {
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
        onLand={onLand}
      />
    </View>
  );
}

/**
 * 大時間與按鈕中間那塊空位。計時中：藤上那顆長大的番茄（AG2）。休息＝剛收下一顆：番茄火柴人慶祝（Y1），
 * 等番茄落地才演（兩個同時動會搶）；moment 只在主畫面是眼前那一頁時才有（殼給的）。
 * 空位太矮（小手機、最大字級）就不畫，縮太小看起來像壞掉。
 */
function MiddleSpot({ phase, current, now, color, moment, landed, onMascotDone }) {
  const T = useTokens();
  const [room, setRoom] = useState(0);
  const focus = phase === PHASE.focus;
  return (
    <View
      pointerEvents="none"
      onLayout={(e) => setRoom(e.nativeEvent.layout.height)}
      style={{ flex: 1, alignItems: 'center', justifyContent: focus ? 'center' : 'flex-end' }}
    >
      {focus && room >= T.shape.growMin ? (
        <GrowingTomato progress={growProgress(current, now)} color={color} height={room} />
      ) : null}
      {phase === PHASE.rest && room >= T.shape.mascotMin ? (
        <Mascot
          action="cheer"
          play={landed && moment === 'cheer'}
          onDone={onMascotDone}
          height={Math.min(T.shape.mascotHeight, room)}
        />
      ) : null}
    </View>
  );
}

/**
 * 主畫面現在開著哪張半頁：null｜'note'｜'end'｜'void'｜'tag'｜'sound'。
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

/**
 * 剛收的那顆落地了沒。鈴響時主畫面整個卸載，收下後重掛，所以每顆都從 false 起算。
 * 今天滿 40 顆時罐子不再掉新的，等不到落地，所以過 landWaitMs 也當它落地了。
 */
function useLanded() {
  const [landed, setLanded] = useState(false);
  const onLand = useCallback(() => setLanded(true), []);
  useEffect(() => {
    const timer = setTimeout(onLand, Token.motion.mascot.landWaitMs);
    return () => clearTimeout(timer);
  }, [onLand]);
  return [landed, onLand];
}

/** zen：聚焦模式的三樣——onEnter 進去；initialSheet、onInitialSheetOpened 見 useHomeSheet。 */
export function Home({ state, phase, now, moment, jarSeen, actions, zen }) {
  const T = useTokens();
  const clearance = useTabBarClearance();
  const { sheet, setSheet, endEarly, openEnd } = useHomeSheet(zen, state.current, now);
  const [landed, onLand] = useLanded();
  const idle = phase === PHASE.idle;
  const focus = phase === PHASE.focus;
  // 待機看的是選中的標籤；計時中、休息看的是這顆開始時的標籤（中途去設定改選別的也不會變）
  const type = typeOf(state, idle ? state.settings.typeId : state.current.typeId);
  const sound = words.ambienceChip(state.settings.ambience); // 白噪音那顆鈕上的字：選了哪一種（AG6）

  // 前景層 box-none：空白處的點擊穿過去給罐子（點了番茄會彈），按鈕照常按。
  return (
    <View style={{ flex: 1 }}>
      <FullScreenJar state={state} jarSeen={jarSeen} onLand={onLand} />
      <View style={{ flex: 1 }} pointerEvents="box-none">
        <TagChip type={type} onPress={idle ? () => setSheet('tag') : undefined} />
        <TimeBlock phase={phase} current={state.current} now={now} type={type} />
        {idle ? (
          <DomyButton
            variant="secondary"
            size="compact"
            title={sound}
            onPress={() => setSheet('sound')}
            style={{ alignSelf: 'center', marginTop: T.space.m }}
          />
        ) : null}
        {focus ? (
          <FocusChips
            current={state.current}
            sound={sound}
            onNote={() => setSheet('note')}
            onZen={zen.onEnter}
            onSound={() => setSheet('sound')}
          />
        ) : null}
        <MiddleSpot
          phase={phase}
          current={state.current}
          now={now}
          color={type.color}
          moment={moment}
          landed={landed}
          onMascotDone={actions.onMascotDone}
        />
        <PrimaryButton
          phase={phase}
          len={type.len}
          testMode={state.settings.demo}
          onStart={actions.onStart}
          onBackFromRest={actions.onBackFromRest}
          onEnd={openEnd}
        />
        <View style={{ height: T.shape.pileRoom + clearance }} pointerEvents="none" />
      </View>
      <HomeSheets
        phase={phase}
        sheet={sheet}
        setSheet={setSheet}
        state={state}
        early={endEarly}
        actions={actions}
      />
    </View>
  );
}

/** 主畫面的半頁都掛在這裡：計時中的三張（記一筆、結束、作廢）、待機的標籤、兩邊都有的白噪音。休息時沒有半頁。 */
function HomeSheets({ phase, sheet, setSheet, state, early, actions }) {
  const idle = phase === PHASE.idle;
  const focus = phase === PHASE.focus;
  const close = () => setSheet(null);
  return (
    <>
      {focus ? (
        <FocusSheetHost
          sheet={sheet}
          setSheet={setSheet}
          current={state.current}
          early={early}
          onJot={actions.onJot}
          onDoneEarly={actions.onDoneEarly}
          onVoid={actions.onVoid}
        />
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
