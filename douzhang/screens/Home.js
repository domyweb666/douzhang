// 主畫面（方向 A：卡片＋滿版按鈕）。四態：第一次、待機、計時中、休息。
// R2（2026-11-01 重新設計）：待機不放大時間，那句是全頁最大的字；長度在開始鈕上，類型入口在鈕上方。
// 豆罐在 D1 才進來，這裡先留一塊空位；豆棚、設定兩個字在，內容是 E1、G1 的事。
// 2026-11-14 照 Domy Design System 重新設計：卡片是 Domy 的白卡圓角、記一筆是 Domy 的次要小鈕、
// 番茄堆停在懸浮分頁列上面。子元件全放模組層級（規矩檔：元件不准定義在元件函式裡）。
import { useCallback, useEffect, useState } from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import { DomyButton, pressFeedback, useTabBarClearance } from '@domy/design';
import { Token, useTokens } from '../design/Tokens';
import { words, startLabel, taskLine, thisRowLabel } from '../design/words';
import { params } from '../design/params';
import { DEV_TYPE, PHASE, canHangLeaf, closeHint, stoppedEarly, typeOf } from '../core/machine';
import { BigButton } from '../ui/BigButton';
import { Clock } from '../ui/Clock';
import { mmss } from '../ui/useNow';
import { EndSheet, NoteSheet, VoidSheet } from '../ui/FocusSheets';
import { ThisSheet } from '../ui/TypeSheets';
import { Jar } from '../ui/Jar';
import { CloseSheet } from '../ui/CloseSheet';
import { TextButton } from '../ui/TextButton';
import { Mascot } from '../ui/Mascot';

function Label({ children }) {
  const T = useTokens();
  return <Text style={{ ...T.font.caption, color: T.color.textSecondary }}>{children}</Text>;
}

function Body({ children }) {
  const T = useTokens();
  return (
    <Text style={{ ...T.font.body, color: T.color.textPrimary, marginTop: T.space.xs }}>
      {children}
    </Text>
  );
}

/** onPress 有給就整張可點（待機時點卡片開「這顆」半頁，V2）。 */
function Card({ children, onPress }) {
  const T = useTokens();
  return (
    <Pressable
      disabled={!onPress}
      accessibilityRole={onPress ? 'button' : undefined}
      onPress={onPress}
      style={({ pressed }) => [
        {
          backgroundColor: T.color.card,
          borderRadius: T.shape.radiusCard,
          padding: T.space.l,
          marginTop: T.space.m,
        },
        onPress ? pressFeedback(pressed, T.reduceMotion) : null,
      ]}
    >
      {children}
    </Pressable>
  );
}

/** wiped：剛清空所有資料，標籤換成 06「空-自己清掉」那句，輸入框照第一次。 */
function FirstInput({ value, onChange, wiped }) {
  const T = useTokens();
  return (
    <View>
      <Label>{wiped ? words.wipedLine : words.firstPrompt}</Label>
      <TextInput
        multiline
        maxLength={params.firstLineMaxChars}
        value={value}
        onChangeText={onChange}
        placeholder={words.firstPlaceholder}
        placeholderTextColor={T.color.textSecondary}
        style={{
          ...T.font.body,
          color: T.color.textPrimary,
          marginTop: T.space.m,
          minHeight: T.shape.tapPrimary,
        }}
      />
    </View>
  );
}

/** 這顆掛的事（今天估過的那件），沒選就沒有。 */
const taskOf = (state, taskId) =>
  (state.days[state.todayKey]?.tasks || []).find((t) => t.id === taskId);

/** 卡片裡的事名那行（V2）：多米要一眼看到「現在在做哪件事」。 */
function TaskLine({ task }) {
  const T = useTokens();
  if (!task) return null;
  return (
    <Text style={{ ...T.font.bodyStrong, color: T.color.textPrimary, marginTop: T.space.xs }}>
      {taskLine(task)}
    </Text>
  );
}

/**
 * 待機卡片：小標「這顆要做」（V2；昨天收工種下的那句今天第一次打開時是「昨天的你留了一句」，F1）、
 * 有選事就一行事名、下面是那句。
 */
function ClueCard({ text, greet, task }) {
  const T = useTokens();
  return (
    <View>
      <Label>{greet ? words.clueLabel : words.thisToDo}</Label>
      <TaskLine task={task} />
      <Text style={{ ...T.font.hero, color: T.color.textPrimary, marginTop: T.space.s }}>
        {text}
      </Text>
    </View>
  );
}

/** 開始鈕上方那一行（U4）：類型＋今天在做的事，點了開「這顆」半頁（分鐘在開始鈕上）。 */
function ThisRow({ type, onPress }) {
  return (
    <TextButton label={thisRowLabel(type.name)} onPress={onPress} style={{ alignSelf: 'center' }} />
  );
}

/** 卡片下面那一塊，依狀態不同：待機是收工那行、計時中是記一筆、休息是那句輪替＋下一顆。 */
function UnderCard({ phase, state, now, first, setSheet }) {
  if (phase === PHASE.idle)
    return first ? null : (
      <CloseHint hint={closeHint(state, now)} onOpen={() => setSheet('close')} />
    );
  if (phase === PHASE.focus)
    return <JotChip current={state.current} onOpen={() => setSheet('note')} />;
  if (phase !== PHASE.rest) return null;
  return (
    <>
      {state.current.msg ? <RestLine text={state.current.msg} /> : null}
      <NextCard text={state.clue?.text} />
    </>
  );
}

/** 計時中的「記一筆」（U6：念頭與有人找合成一顆，半頁裡再選）；記過幾筆就在後面帶數字。 */
function JotChip({ current, onOpen }) {
  const T = useTokens();
  const count = (current.notes?.length || 0) + (current.pings?.length || 0);
  return (
    <DomyButton
      variant="secondary"
      size="compact"
      title={words.countLabel(words.quickNote, count)}
      onPress={onOpen}
      style={{ alignSelf: 'center', marginTop: T.space.m }}
    />
  );
}

/** 休息時剛寫的那句（U8）：喝水時就讓腦袋先接上下一顆。 */
function NextCard({ text }) {
  if (!text) return null;
  return (
    <Card>
      <Label>{words.nextBean}</Label>
      <Body>{text}</Body>
    </Card>
  );
}

/** 收下後那句（24 句輪替）：休息時放在卡片下面，位置同待機的 chip。 */
function RestLine({ text }) {
  const T = useTokens();
  return (
    <Text
      style={{
        ...T.font.sub,
        color: T.color.textSecondary,
        textAlign: 'center',
        marginTop: T.space.m,
      }}
    >
      {text}
    </Text>
  );
}

/** 計時中與休息共用：大時間＋小標＋（計時中有選事就一行事名）＋一句；提早做完後多一行（B2）。 */
function Countdown({ left, label, body, extra, task }) {
  return (
    <View>
      <Clock focus text={mmss(left)} />
      <Label>{label}</Label>
      <TaskLine task={task} />
      <Body>{body}</Body>
      {extra ? <Label>{extra}</Label> : null}
    </View>
  );
}

function CardBody({ phase, state, now, greet, wiped, firstLine, onFirstLine }) {
  const left = state.current ? state.current.endAt - now : 0;
  if (phase === PHASE.focus)
    return (
      <Countdown
        left={left}
        label={words.doing}
        body={state.current.clue}
        task={taskOf(state, state.current.taskId)}
        extra={state.current.done ? words.doneEarlyLine : null}
      />
    );
  if (phase === PHASE.rest) {
    // 「我自己決定」的休息沒有結束時刻：大時間數正數（休息了多久），只有按回來才結束
    const self = state.current.endAt == null; // 看資料不看設定：休息中改設定也不會卡住
    const shown = self ? now - state.current.restStart : left;
    const label = state.current.long ? words.restLongRow : words.rest; // 今天每滿幾顆那次（設定 A）
    return <Countdown left={shown} label={label} body={words.restBody} />;
  }
  if (!state.clue) return <FirstInput value={firstLine} onChange={onFirstLine} wiped={wiped} />;
  return <ClueCard text={state.clue.text} greet={greet} task={taskOf(state, state.taskId)} />;
}

/** 待機卡片下那一行：過了收工時間是收工入口，收工了或掛了葉子是一句話（F1、F2）。 */
function CloseHint({ hint, onOpen }) {
  const T = useTokens();
  if (!hint) return null;
  if (hint === 'due')
    return (
      <TextButton
        label={words.closeDueHint}
        onPress={onOpen}
        style={{ alignSelf: 'center', marginTop: T.space.s }}
      />
    );
  const text = hint === 'closed' ? words.closedHint : words.leafHint;
  return (
    <Text
      style={{
        ...T.font.sub,
        color: T.color.textSecondary,
        textAlign: 'center',
        marginTop: T.space.s,
      }}
    >
      {text}
    </Text>
  );
}

function PrimaryButton({ phase, first, firstLine, len, testMode, onStart, onBackFromRest, onEnd }) {
  // 開發期快轉：長按開始＝5 秒測試顆；設定開了「測試模式」就直接是測試鈕。正式 build 兩個都沒有。
  const devStart = __DEV__ ? () => onStart({ typeId: DEV_TYPE.id, firstLine }) : undefined;
  if (phase === PHASE.rest)
    return <BigButton label={words.backFromRest} onPress={onBackFromRest} />;
  // U6：計時中不放大按鈕，結束降成底部文字鈕（不誘人按、也少誤觸）
  if (phase === PHASE.focus)
    return (
      <TextButton secondary label={words.endThis} onPress={onEnd} style={{ alignSelf: 'center' }} />
    );
  if (phase !== PHASE.idle) return null;
  if (__DEV__ && testMode) {
    return (
      <BigButton
        label={words.startTest(DEV_TYPE.len)}
        disabled={first && !firstLine.trim()}
        onPress={devStart}
      />
    );
  }
  if (first) {
    return (
      <BigButton
        label={startLabel(words.startFirst, len)}
        disabled={!firstLine.trim()}
        onPress={() => onStart({ firstLine })}
        onLongPress={devStart}
      />
    );
  }
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
  // 今天的番茄依時間排；大小跟分鐘走（V4）、顏色跟類型（W1）
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
 * 番茄火柴人現在在不在、演哪個動作、要不要播（Y1）。不在就回 null。
 * 休息＝剛收下一顆：等番茄落地才慶祝（兩個同時動會搶）。今天收工了或掛了葉子：鞠躬。
 * moment 只在主畫面是眼前那一頁時才有（殼給的）；重開 app 沒有 moment，就只是站著。
 */
function mascotOf({ phase, state, now, moment, landed }) {
  if (phase === PHASE.rest) return { action: 'cheer', play: landed && moment === 'cheer' };
  if (phase !== PHASE.idle || !state.clue) return null;
  const hint = closeHint(state, now);
  if (hint !== 'closed' && hint !== 'leaf') return null;
  return { action: 'bow', play: moment === 'bow' };
}

/** 卡片與按鈕中間那塊空位。火柴人站在這塊的底部；空位太矮（小手機、最大字級）就不畫。 */
function MascotSpot({ mascot, onDone }) {
  const T = useTokens();
  const [room, setRoom] = useState(0);
  const height = Math.min(T.shape.mascotHeight, room);
  return (
    <View
      pointerEvents="none"
      onLayout={(e) => setRoom(e.nativeEvent.layout.height)}
      style={{ flex: 1, alignItems: 'center', justifyContent: 'flex-end' }}
    >
      {mascot && height >= T.shape.mascotMin ? (
        <Mascot action={mascot.action} play={mascot.play} onDone={onDone} height={height} />
      ) : null}
    </View>
  );
}

export function Home({ state, phase, now, greet, moment, wiped, jarSeen, actions }) {
  const T = useTokens();
  const clearance = useTabBarClearance();
  const { onStart, onBackFromRest } = actions;
  const [firstLine, setFirstLine] = useState('');
  const [sheet, setSheet] = useState(null); // null｜'note'｜'end'｜'void'｜'this'｜'close'
  const [endEarly, setEndEarly] = useState(false); // 打開「結束這顆」那一刻固定：不到五分鐘嗎
  // 剛收的那顆落地了沒。鈴響時主畫面整個卸載，收下後重掛，所以每顆都從 false 起算。
  // 今天滿 40 顆時罐子不再掉新的，等不到落地，所以過 landWaitMs 也當它落地了。
  const [landed, setLanded] = useState(false);
  const onLand = useCallback(() => setLanded(true), []);
  useEffect(() => {
    const timer = setTimeout(onLand, Token.motion.mascot.landWaitMs);
    return () => clearTimeout(timer);
  }, [onLand]);
  const first = !state.clue;
  const type = typeOf(state, state.settings.typeId);
  const idle = phase === PHASE.idle;
  const focus = phase === PHASE.focus;

  // W3：番茄在整個畫面後面掉、滾、堆在最下面；卡片在上，類型與開始鈕在番茄堆上方。
  // 前景層 box-none：空白處的點擊穿過去給罐子（點了番茄會彈），按鈕與卡片照常按。
  return (
    <View style={{ flex: 1 }}>
      <FullScreenJar state={state} jarSeen={jarSeen} onLand={onLand} />
      <View style={{ flex: 1 }} pointerEvents="box-none">
        <Card onPress={idle && !first ? () => setSheet('this') : undefined}>
          <CardBody
            phase={phase}
            state={state}
            now={now}
            greet={greet}
            wiped={wiped}
            firstLine={firstLine}
            onFirstLine={setFirstLine}
          />
        </Card>
        <UnderCard phase={phase} state={state} now={now} first={first} setSheet={setSheet} />
        <MascotSpot
          mascot={mascotOf({ phase, state, now, moment, landed })}
          onDone={actions.onMascotDone}
        />
        {idle ? <ThisRow type={type} onPress={() => setSheet('this')} /> : null}
        <PrimaryButton
          phase={phase}
          first={first}
          firstLine={firstLine}
          len={type.len}
          testMode={state.settings.demo}
          onStart={onStart}
          onBackFromRest={onBackFromRest}
          onEnd={() => {
            setEndEarly(stoppedEarly(state.current, now));
            setSheet('end');
          }}
        />
        <View style={{ height: T.shape.pileRoom + clearance }} pointerEvents="none" />
      </View>
      {focus ? (
        <FocusSheetHost
          sheet={sheet}
          setSheet={setSheet}
          current={state.current}
          early={endEarly}
          onJot={actions.onJot}
          onDoneEarly={actions.onDoneEarly}
          onVoid={actions.onVoid}
        />
      ) : null}
      {idle ? (
        <IdleSheetHost
          sheet={sheet}
          setSheet={setSheet}
          state={state}
          now={now}
          actions={actions}
        />
      ) : null}
    </View>
  );
}

/** 待機的兩個半頁：這顆、收工。key 讓每次打開都是乾淨的輸入框。 */
function IdleSheetHost({ sheet, setSheet, state, now, actions }) {
  const close = () => setSheet(null);
  return (
    <>
      <ThisSheet
        key={`this-${sheet}`}
        visible={sheet === 'this'}
        state={state}
        onClose={close}
        onPickType={actions.onPickType}
        onEstimate={actions.onEstimate}
        onPickTask={actions.onPickTask}
      />
      <CloseSheet
        key={`close-${sheet}`}
        visible={sheet === 'close'}
        clueText={state.clue?.text}
        leafOk={canHangLeaf(state, now)}
        onClose={close}
        onCloseDay={actions.onCloseDay}
        onHangLeaf={actions.onHangLeaf}
      />
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
