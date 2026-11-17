// 響了之後的慶祝畫面（2026-11-17 AG3，比較頁 2C「整頁＋今天收了幾顆」）。
// 原本這頁的主角是輸入框（寫一句給下一顆的自己）；換核心後先恭喜、再收下，寫一句變成選填：
// 不寫可以直接收下，不用多按「這顆不留話」。寫了的那句記在這顆上，番茄架那一格看得到。
// 由上到下：這顆熟了的番茄、標題、今天收了幾顆那排、選填的一句、計時中記的念頭與有人找、收下、再做 15／30 分。
import { useState } from 'react';
import { ScrollView, Text, TextInput, View } from 'react-native';
import { useTokens } from '../design/Tokens';
import { words, tagLabel } from '../design/words';
import { params, MS_PER_MINUTE } from '../design/params';
import { dayKey, restMinutes } from '../core/store';
import { typeOf } from '../core/machine';
import { BigButton } from '../ui/BigButton';
import { TextButton } from '../ui/TextButton';
import { Tomato } from '../ui/Tomato';

/** 很久才回來（超過這顆的休息長度）：多一行「響了 N 分鐘前。收下後直接回待機。」 */
function lateMinutes(current, now) {
  const agoMs = now - current.endAt;
  return agoMs >= restMinutes(current.len) * MS_PER_MINUTE ? Math.floor(agoMs / MS_PER_MINUTE) : 0;
}

function Header({ type, late }) {
  const T = useTokens();
  const sub = { ...T.font.sub, color: T.color.textSecondary, textAlign: 'center' };
  return (
    <View style={{ alignItems: 'center', gap: T.space.xs, marginTop: T.space.l }}>
      <Tomato color={type.color} size={T.shape.celebrateTomato} />
      <Text
        accessibilityRole="header"
        style={{ ...T.font.title, color: T.color.textPrimary, textAlign: 'center' }}
      >
        {words.ripeTitle}
      </Text>
      <Text style={sub}>{tagLabel(type)}</Text>
      {late ? <Text style={sub}>{words.rangAgo(late)}</Text> : null}
    </View>
  );
}

/**
 * 「今天收了 N 顆」：開始那天已經收下的，加上這一顆排在最後、比較大。看得到累積，不跟昨天比。
 * 太多顆時只畫最後幾顆（params.celebrateTomatoes），數字照實寫。
 */
function TodayRow({ state, current, type }) {
  const T = useTokens();
  const kept = state.days[dayKey(current.startedAt)]?.beans || [];
  const shown = kept
    .slice()
    .sort((a, b) => a.t - b.t)
    .slice(-(params.celebrateTomatoes - 1));
  return (
    <View
      style={{
        alignItems: 'center',
        gap: T.space.s,
        backgroundColor: T.color.card,
        borderRadius: T.shape.radiusCard,
        padding: T.space.card,
        marginTop: T.space.l,
      }}
    >
      <Text style={{ ...T.font.sub, color: T.color.textSecondary }}>
        {words.todayKept(kept.length + 1)}
      </Text>
      <View
        accessible={false}
        style={{
          flexDirection: 'row',
          flexWrap: 'wrap',
          justifyContent: 'center',
          alignItems: 'flex-end',
          gap: T.space.xs,
        }}
      >
        {shown.map((b) => (
          <Tomato key={b.t} color={typeOf(state, b.typeId).color} size={T.shape.celebrateDot} />
        ))}
        <Tomato color={type.color} size={T.shape.celebrateDotNew} />
      </View>
    </View>
  );
}

/** 選填的一句：先是一列可點的字，點了才變成輸入框（不然一進來鍵盤就蓋住番茄）。打過字的回來直接是輸入框。 */
function NoteField({ draft, onDraft }) {
  const T = useTokens();
  const [open, setOpen] = useState(!!draft);
  if (!open)
    return (
      <TextButton
        secondary
        label={words.noteOptional}
        onPress={() => setOpen(true)}
        style={{ alignSelf: 'center', marginTop: T.space.m }}
      />
    );
  return (
    <TextInput
      autoFocus
      multiline
      maxLength={params.firstLineMaxChars}
      value={draft}
      onChangeText={onDraft}
      placeholder={words.notePlaceholder}
      placeholderTextColor={T.color.textSecondary}
      selectionColor={T.color.accent}
      style={{
        ...T.font.body,
        color: T.color.textPrimary,
        backgroundColor: T.color.card,
        borderWidth: T.shape.hairline,
        borderColor: T.color.fieldBorder,
        borderRadius: T.shape.radiusCard,
        paddingHorizontal: T.space.card,
        paddingVertical: T.space.m,
        marginTop: T.space.m,
        minHeight: T.shape.tapPrimary,
      }}
    />
  );
}

/** 計時中記的念頭與有人找（B1 寫進來）。清單空就什麼都不畫，不寫「沒有紀錄」。 */
function Jotted({ current }) {
  const T = useTokens();
  const rows = [
    ...(current.notes || []).map((v) => ({ k: words.noteThought, v })),
    ...(current.pings || []).map((v) => ({ k: words.notePing, v })),
  ];
  if (!rows.length) return null;
  const sub = { ...T.font.sub, color: T.color.textSecondary };
  return (
    <View style={{ marginTop: T.space.m }}>
      {rows.map((r, i) => (
        <View key={i} style={{ flexDirection: 'row', marginTop: T.space.xs }}>
          <Text style={{ ...sub, marginRight: T.space.m }}>{r.k}</Text>
          <Text style={{ ...sub, flex: 1 }}>{r.v}</Text>
        </View>
      ))}
    </View>
  );
}

/** 「再做 15 分」「再做 30 分」並排的文字鈕；一顆只准延一次，延過就不畫（A5）。 */
function FlowRow({ current, onFlow }) {
  const T = useTokens();
  if (current.flowed) return null;
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-around', marginTop: T.space.xs }}>
      {params.flowMinutes.map((minutes) => (
        <TextButton key={minutes} label={words.flowMore(minutes)} onPress={() => onFlow(minutes)} />
      ))}
    </View>
  );
}

export function Bell({ state, current, now, draft, onDraft, onKeep, onFlow }) {
  const T = useTokens();
  const type = typeOf(state, current.typeId);
  const late = lateMinutes(current, now);
  return (
    <View style={{ flex: 1 }}>
      <ScrollView
        style={{ flex: 1 }}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: T.space.l }}
      >
        <Header type={type} late={late} />
        <TodayRow state={state} current={current} type={type} />
        <NoteField draft={draft} onDraft={onDraft} />
        <Jotted current={current} />
      </ScrollView>
      <BigButton label={late ? words.keepThis : words.keepAndRest} onPress={() => onKeep(draft)} />
      <FlowRow current={current} onFlow={onFlow} />
    </View>
  );
}
