// 主畫面（方向 A：卡片＋滿版按鈕）。四態：第一次、待機、計時中、休息。
// 豆罐在 D1 才進來，這裡先留一塊空位；豆棚、設定兩個字在，內容是 E1、G1 的事。
// 子元件全放模組層級（規矩檔：元件不准定義在元件函式裡）。
import { useState } from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words, typeChipLabel } from '../design/words';
import { params } from '../design/params';
import { DEV_TYPE, PHASE, typeOf } from '../core/machine';
import { BigButton } from '../ui/BigButton';
import { Clock } from '../ui/Clock';
import { mmss } from '../ui/useNow';
import { EndSheet, NoteSheet, VoidSheet } from '../ui/FocusSheets';
import { EstimateSheet, TypeSheet } from '../ui/TypeSheets';
import { Jar } from '../ui/Jar';
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

/** 左上豆棚、右上設定（導覽 A）。豆棚 E1 接。 */
function Nav({ onRack, onSettings }) {
  const T = useTokens();
  const btn = { minWidth: T.shape.tapPrimary, height: T.shape.tapMin, justifyContent: 'center' };
  const txt = { ...T.font.body, color: T.color.accentText };
  return (
    <View
      style={{
        height: T.shape.tapMin,
        marginTop: T.space.s,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
      }}
    >
      <Pressable accessibilityRole="button" onPress={onRack} style={btn}>
        <Text style={txt}>{words.rack}</Text>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        onPress={onSettings}
        style={[btn, { alignItems: 'flex-end' }]}
      >
        <Text style={txt}>{words.settings}</Text>
      </Pressable>
    </View>
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

function FirstInput({ value, onChange }) {
  const T = useTokens();
  return (
    <View>
      <Label>{words.firstPrompt}</Label>
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

function ClueCard({ text }) {
  const T = useTokens();
  return (
    <View>
      <Label>{words.clueLabel}</Label>
      <Text style={{ ...T.font.sentence, color: T.color.textPrimary, marginTop: T.space.s }}>
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

function TypeChip({ type, onPress }) {
  const T = useTokens();
  return (
    <Chip
      label={typeChipLabel(type.name, type.len)}
      onPress={onPress}
      style={{ alignSelf: 'center', marginTop: T.space.m }}
    />
  );
}

/** 計時中的兩個入口：冒出念頭、有人找；記過幾筆就在名字後面帶數字（B1）。 */
function JotChips({ current, onOpen }) {
  const T = useTokens();
  const label = (name, list) => (list?.length ? `${name} ${list.length}` : name);
  return (
    <View
      style={{
        flexDirection: 'row',
        justifyContent: 'center',
        gap: T.space.m,
        marginTop: T.space.m,
      }}
    >
      <Chip label={label(words.noteThought, current.notes)} onPress={() => onOpen('notes')} />
      <Chip label={label(words.notePing, current.pings)} onPress={() => onOpen('pings')} />
    </View>
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

function CardBody({ phase, state, now, firstLine, onFirstLine }) {
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
  if (!state.clue) return <FirstInput value={firstLine} onChange={onFirstLine} />;
  return <ClueCard text={state.clue.text} />;
}

function PrimaryButton({ phase, first, firstLine, onStart, onBackFromRest, onEnd }) {
  // 開發期快轉：長按開始＝一分鐘測試顆。正式 build 沒有這個手勢。
  const devStart = __DEV__ ? () => onStart({ typeId: DEV_TYPE.id, firstLine }) : undefined;
  if (phase === PHASE.rest)
    return <BigButton label={words.backFromRest} onPress={onBackFromRest} />;
  if (phase === PHASE.focus) return <BigButton second label={words.end} onPress={onEnd} />;
  if (phase !== PHASE.idle) return null;
  if (first) {
    return (
      <BigButton
        label={words.startFirst}
        disabled={!firstLine.trim()}
        onPress={() => onStart({ firstLine })}
        onLongPress={devStart}
      />
    );
  }
  return <BigButton label={words.start} onPress={() => onStart({})} onLongPress={devStart} />;
}

export function Home({ state, phase, now, actions, onRack, onSettings }) {
  const T = useTokens();
  const { onStart, onBackFromRest } = actions;
  const [firstLine, setFirstLine] = useState('');
  const [sheet, setSheet] = useState(null); // null｜'notes'｜'pings'｜'end'｜'void'｜'type'｜'estimate'
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
      <Nav onRack={onRack} onSettings={onSettings} />
      <Card>
        <CardBody
          phase={phase}
          state={state}
          now={now}
          firstLine={firstLine}
          onFirstLine={setFirstLine}
        />
      </Card>
      {idle ? <TypeChip type={type} onPress={() => setSheet('type')} /> : null}
      {idle ? <Clock text={`${type.len}:00`} style={{ marginTop: T.space.s }} /> : null}
      {focus ? <JotChips current={state.current} onOpen={setSheet} /> : null}
      {phase === PHASE.rest && state.current.msg ? <RestLine text={state.current.msg} /> : null}
      <Jar
        beans={todayBeans}
        sound={state.settings.sound}
        tilt={state.settings.tilt}
        style={{ marginVertical: T.space.m }}
      />
      <PrimaryButton
        phase={phase}
        first={first}
        firstLine={firstLine}
        onStart={onStart}
        onBackFromRest={onBackFromRest}
        onEnd={() => setSheet('end')}
      />
      {focus ? (
        <FocusSheetHost
          sheet={sheet}
          setSheet={setSheet}
          current={state.current}
          now={now}
          onJot={actions.onJot}
          onDoneEarly={actions.onDoneEarly}
          onVoid={actions.onVoid}
        />
      ) : null}
      {idle ? (
        <TypeSheet
          visible={sheet === 'type'}
          state={state}
          onClose={() => setSheet(null)}
          onPickType={actions.onPickType}
          onOpenEstimate={() => setSheet('estimate')}
        />
      ) : null}
      {idle ? (
        <EstimateSheet
          key={`est-${sheet}`}
          visible={sheet === 'estimate'}
          state={state}
          onClose={() => setSheet(null)}
          onEstimate={actions.onEstimate}
          onPickTask={actions.onPickTask}
        />
      ) : null}
    </View>
  );
}

/** 計時中的三個半頁掛在這裡；key 讓每次打開都是乾淨的輸入框。 */
function FocusSheetHost({ sheet, setSheet, current, now, onJot, onDoneEarly, onVoid }) {
  const close = () => setSheet(null);
  return (
    <>
      <NoteSheet
        key={sheet}
        kind={sheet === 'notes' || sheet === 'pings' ? sheet : null}
        onClose={close}
        onJot={onJot}
      />
      <EndSheet
        visible={sheet === 'end'}
        current={current}
        now={now}
        onClose={close}
        onDoneEarly={onDoneEarly}
        onVoid={(early) => {
          if (early) {
            close();
            onVoid({});
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
