// 主畫面（方向 A：卡片＋滿版按鈕）。四態：第一次、待機、計時中、休息。
// R2（2026-11-01 重新設計）：待機不放大時間，那句是全頁最大的字；長度在開始鈕上，類型入口在鈕上方。
// 豆罐在 D1 才進來，這裡先留一塊空位；豆棚、設定兩個字在，內容是 E1、G1 的事。
// 子元件全放模組層級（規矩檔：元件不准定義在元件函式裡）。
import { useState } from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words, startLabel, thisRowLabel } from '../design/words';
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
import { units } from '../core/store';

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

function Card({ children }) {
  const T = useTokens();
  return (
    <View
      style={{
        backgroundColor: T.color.card,
        borderRadius: T.shape.radiusCard,
        padding: T.space.l,
        marginTop: T.space.l,
      }}
    >
      {children}
    </View>
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

/** greet：昨天收工種下的那句，今天第一次打開時小標換成「昨天的你留了一句」（F1）。 */
function ClueCard({ text, greet }) {
  const T = useTokens();
  return (
    <View>
      <Label>{greet ? words.clueLabel : words.nextStep}</Label>
      <Text style={{ ...T.font.hero, color: T.color.textPrimary, marginTop: T.space.s }}>
        {text}
      </Text>
    </View>
  );
}

function Chip({ label, onPress, style }) {
  const T = useTokens();
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        {
          height: T.shape.tapMin,
          paddingHorizontal: T.space.l,
          borderRadius: T.shape.radiusPill,
          backgroundColor: T.color.fillButton,
          justifyContent: 'center',
          opacity: pressed ? T.opacity.pressed : 1,
        },
        style,
      ]}
    >
      <Text style={{ ...T.font.chip, color: T.color.textPrimary }}>{label}</Text>
    </Pressable>
  );
}

/** 開始鈕上方那一行（U4）：類型＋今天在做的事，點了開「這顆」半頁（分鐘在開始鈕上）。 */
function ThisRow({ state, type, onPress }) {
  const task = (state.days[state.todayKey]?.tasks || []).find((t) => t.id === state.taskId);
  return (
    <TextButton
      label={thisRowLabel(type.name, task)}
      onPress={onPress}
      style={{ alignSelf: 'center' }}
    />
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
    <Chip
      label={words.countLabel(words.quickNote, count)}
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

/** 計時中與休息共用：大時間＋小標＋一句；提早做完後多一行（B2）。 */
function Countdown({ left, label, body, extra }) {
  return (
    <View>
      <Clock focus text={mmss(left)} />
      <Label>{label}</Label>
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
        extra={state.current.done ? words.doneEarlyLine : null}
      />
    );
  if (phase === PHASE.rest) {
    // 「我自己決定」的休息沒有結束時刻：大時間數正數（休息了多久），只有按回來才結束
    const self = state.current.endAt == null; // 看資料不看設定：休息中改設定也不會卡住
    const shown = self ? now - state.current.restStart : left;
    return <Countdown left={shown} label={words.rest} body={words.restBody} />;
  }
  if (!state.clue) return <FirstInput value={firstLine} onChange={onFirstLine} wiped={wiped} />;
  return <ClueCard text={state.clue.text} greet={greet} />;
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

function PrimaryButton({ phase, first, firstLine, len, onStart, onBackFromRest, onEnd }) {
  // 開發期快轉：長按開始＝一分鐘測試顆。正式 build 沒有這個手勢。
  const devStart = __DEV__ ? () => onStart({ typeId: DEV_TYPE.id, firstLine }) : undefined;
  if (phase === PHASE.rest)
    return <BigButton label={words.backFromRest} onPress={onBackFromRest} />;
  // U6：計時中不放大按鈕，結束降成底部文字鈕（不誘人按、也少誤觸）
  if (phase === PHASE.focus)
    return (
      <TextButton secondary label={words.endThis} onPress={onEnd} style={{ alignSelf: 'center' }} />
    );
  if (phase !== PHASE.idle) return null;
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

export function Home({ state, phase, now, greet, wiped, jarSeen, actions }) {
  const T = useTokens();
  const { onStart, onBackFromRest } = actions;
  const [firstLine, setFirstLine] = useState('');
  const [sheet, setSheet] = useState(null); // null｜'note'｜'end'｜'void'｜'this'｜'close'
  const [endEarly, setEndEarly] = useState(false); // 打開「結束這顆」那一刻固定：不到五分鐘嗎
  const first = !state.clue;
  const type = typeOf(state, state.settings.typeId);
  const idle = phase === PHASE.idle;
  const focus = phase === PHASE.focus;
  // 今天的豆子依時間排，給豆罐；50 分那顆是雙豆
  const todayBeans = (state.days[state.todayKey]?.beans || [])
    .slice()
    .sort((a, b) => a.t - b.t)
    .map((b) => ({ double: units(b.len) > 1 }));

  return (
    <View style={{ flex: 1 }}>
      <Card>
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
      <Jar
        beans={todayBeans}
        seenRef={jarSeen}
        sound={state.settings.sound}
        tilt={state.settings.tilt}
        style={{ marginVertical: T.space.m }}
      />
      {idle ? <ThisRow state={state} type={type} onPress={() => setSheet('this')} /> : null}
      <PrimaryButton
        phase={phase}
        first={first}
        firstLine={firstLine}
        len={type.len}
        onStart={onStart}
        onBackFromRest={onBackFromRest}
        onEnd={() => {
          setEndEarly(stoppedEarly(state.current, now));
          setSheet('end');
        }}
      />
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
