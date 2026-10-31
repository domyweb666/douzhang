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

/** 左上豆棚、右上設定。A2 只是兩個字在對的位置，按了沒反應（E1、G1 接）。 */
function Nav() {
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
      <Pressable accessibilityRole="button" style={btn}>
        <Text style={txt}>{words.rack}</Text>
      </Pressable>
      <Pressable accessibilityRole="button" style={[btn, { alignItems: 'flex-end' }]}>
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

function TypeChip({ type }) {
  const T = useTokens();
  return (
    <View
      style={{
        alignSelf: 'center',
        marginTop: T.space.m,
        height: T.shape.tapMin,
        paddingHorizontal: T.space.l,
        borderRadius: T.shape.radiusPill,
        backgroundColor: T.color.fillButton,
        justifyContent: 'center',
      }}
    >
      <Text style={{ ...T.font.chip, color: T.color.textPrimary }}>
        {typeChipLabel(type.name, type.len)}
      </Text>
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

/** 計時中與休息共用：大時間＋小標＋一句。 */
function Countdown({ left, label, body }) {
  return (
    <View>
      <Clock focus text={mmss(left)} />
      <Label>{label}</Label>
      <Body>{body}</Body>
    </View>
  );
}

function CardBody({ phase, state, now, firstLine, onFirstLine }) {
  const left = state.current ? state.current.endAt - now : 0;
  if (phase === PHASE.focus)
    return <Countdown left={left} label={words.doing} body={state.current.clue} />;
  if (phase === PHASE.rest) {
    // 「我自己決定」的休息沒有結束時刻：大時間數正數（休息了多久），只有按回來才結束
    const self = state.settings.restMode === 'self';
    const shown = self ? now - state.current.restStart : left;
    return <Countdown left={shown} label={words.rest} body={words.restBody} />;
  }
  if (!state.clue) return <FirstInput value={firstLine} onChange={onFirstLine} />;
  return <ClueCard text={state.clue.text} />;
}

function PrimaryButton({ phase, first, firstLine, onStart, onBackFromRest }) {
  // 開發期快轉：長按開始＝一分鐘測試顆。正式 build 沒有這個手勢。
  const devStart = __DEV__ ? () => onStart({ typeId: DEV_TYPE.id, firstLine }) : undefined;
  if (phase === PHASE.rest)
    return <BigButton label={words.backFromRest} onPress={onBackFromRest} />;
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

export function Home({ state, phase, now, onStart, onBackFromRest }) {
  const T = useTokens();
  const [firstLine, setFirstLine] = useState('');
  const first = !state.clue;
  const type = typeOf(state, state.settings.typeId);
  const idle = phase === PHASE.idle;

  return (
    <View style={{ flex: 1 }}>
      <Nav />
      <Card>
        <CardBody
          phase={phase}
          state={state}
          now={now}
          firstLine={firstLine}
          onFirstLine={setFirstLine}
        />
      </Card>
      {idle ? <TypeChip type={type} /> : null}
      {idle ? <Clock text={`${type.len}:00`} style={{ marginTop: T.space.s }} /> : null}
      {phase === PHASE.rest && state.current.msg ? <RestLine text={state.current.msg} /> : null}
      <View style={{ flex: 1 }} />
      <PrimaryButton
        phase={phase}
        first={first}
        firstLine={firstLine}
        onStart={onStart}
        onBackFromRest={onBackFromRest}
      />
    </View>
  );
}
