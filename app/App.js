// 豆帳 灰盒子＋上色（3-3 線框；2026-11-01 加 Skin：套 Tokens.js 給多米比對三方向）。
// 上色只是把灰換成代號裡的值，結構不動。除錯頁「上色」關掉就是原本的灰盒子，給新人測方向時用。
// 右上角小字（例 A·B）是除錯入口：切方向、試玩速度、看字級倍率與螢幕尺寸。
import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import {
  Image, KeyboardAvoidingView, Modal, PixelRatio, Platform, Pressable, SafeAreaView, ScrollView,
  StyleSheet, Switch, Text, TextInput, useWindowDimensions, View,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { StatusBar } from 'expo-status-bar';
import JarProto from './Jar';
import { CharacterColors, useTokens } from './Tokens';

const IMG = {
  pea: require('./assets/img/pea.webp'), pea2: require('./assets/img/pea2.webp'),
  sprout: require('./assets/img/sprout.webp'), empty: require('./assets/img/empty.webp'),
  faceThink: require('./assets/img/face-think.webp'), restWater: require('./assets/img/rest-water.webp'),
  trellis: require('./assets/img/trellis.webp'),
};

const SENT = '打開讀書筆記，把三個重點各寫一句';
const SENT_LONG = '先把《原子習慣》第三章的筆記打開，找出昨天標了星號的三段，各寫一句話說明它跟我自己的早晨流程有什麼關係，寫完貼到課程大綱第二節的開頭，再順手把第二節的標題改成問句，最後檢查字數有沒有超過一百二十個字';
const TYPES = [
  { id: 't1', name: '一般', len: 25 },
  { id: 't2', name: '寫作', len: 50 },
  { id: 't3', name: '短的', len: 15 },
];
const REST_TEXT = '離開螢幕。喝水、看遠處、伸展、閉眼都好。';
const DIRS = ['A', 'B', 'C'];
const STORE_KEY = 'douzhang.graybox.prefs.v1';

const mmss = (ms) => {
  const s = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
};

// ---------- 灰盒子色（上色關掉時換回來；只在這裡，畫面不准直接拿） ----------
const GRAY = {
  background: '#fff', card: '#f4f4f4', textPrimary: '#111', separator: '#ddd', fillButton: '#e6e6e6',
  textSecondary: '#777', accent: '#333', onAccent: '#fff', accentText: '#666', danger: '#111',
};

// ---------- 樣式全部從代號長出來 ----------
const stripTextProps = ({ maxFontSizeMultiplier, ...style }) => style;
function makeStyles(T) {
  const c = T.color, f = T.font, sp = T.space, sh = T.shape;
  return StyleSheet.create({
    safe: { flex: 1, backgroundColor: c.background },
    content: { flex: 1, paddingHorizontal: sp.l, paddingBottom: sp.m + sp.xs },
    fill: { flex: 1 },
    wire: { borderWidth: 1, borderColor: c.textSecondary, borderStyle: 'dashed' },
    nav: { height: sh.tapMin, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: sp.s, marginTop: sp.s },
    navBtn: { minWidth: 60, height: sh.tapMin, justifyContent: 'center', alignItems: 'center', paddingHorizontal: sp.m },
    navTxt: { ...f.body, color: c.accentText },
    navTitle: { ...f.body, fontWeight: '600', color: c.textPrimary },
    debugBtn: { width: sh.tapMin, height: sh.tapMin, justifyContent: 'center', alignItems: 'center' },
    debugTxt: { fontSize: 11, color: c.textSecondary, opacity: 0.6 },
    card: { backgroundColor: c.card, borderRadius: sh.radiusCard, padding: sp.l, marginTop: sp.l, position: 'relative' },
    cardB: { minHeight: 270, marginTop: 0 },
    deco: { position: 'absolute', right: sp.m, top: sp.s, width: 60, height: 60 },
    ill: { width: 110, height: 110, alignSelf: 'center', marginBottom: sp.s },
    lbl: { ...f.caption, color: c.textSecondary, lineHeight: 18 },
    sent: { ...f.sentence, color: c.textPrimary, marginTop: sp.s, paddingRight: 58 },
    body: { ...f.body, color: c.textPrimary, marginTop: sp.xs, lineHeight: 24 },
    h1: { ...f.title, color: c.textPrimary },
    h2: { ...f.section, color: c.textPrimary, marginBottom: sp.s },
    hint: { ...f.caption, color: c.textSecondary, marginTop: 'auto', textAlign: 'right', paddingTop: sp.s },
    chip: { height: sh.tapMin, paddingHorizontal: sp.l - sp.xs, borderRadius: sh.radiusPill, backgroundColor: c.fillButton, justifyContent: 'center', alignItems: 'center' },
    chipOn: { backgroundColor: c.accent },
    chipTxt: { ...f.sub, fontWeight: '600', color: c.textPrimary },
    chipTxtOn: { color: c.onAccent },
    pair: { flexDirection: 'row', gap: sp.m, marginTop: sp.m },
    timeMid: { ...stripTextProps(f.clock), textAlign: 'center', marginTop: sp.s, color: c.textPrimary, letterSpacing: -1 },
    timeBig: { ...stripTextProps(f.clockFocus), textAlign: 'center', color: c.textPrimary, letterSpacing: -1 },
    big: { height: sh.tapPrimary, borderRadius: sh.radiusButton, backgroundColor: c.accent, justifyContent: 'center', alignItems: 'center' },
    bigTxt: { ...f.button, color: c.onAccent },
    big2: { backgroundColor: c.fillButton },
    big2Txt: { ...f.button2, color: c.textPrimary },
    txtBtn: { height: sh.tapMin, justifyContent: 'center', paddingHorizontal: sp.s, alignSelf: 'flex-start' },
    txtBtnTxt: { ...f.sub, fontWeight: '600', color: c.accentText },
    jar: { borderRadius: sh.radiusCard, backgroundColor: c.card, padding: sp.m, overflow: 'hidden', minHeight: 120 },
    pea: { position: 'absolute', width: 36, height: 36 },
    pea2: { width: 68 },
    peaGray: { borderRadius: 18, backgroundColor: c.fillButton },
    circle: { backgroundColor: c.fillButton, justifyContent: 'center', alignItems: 'center' },
    circleOn: { backgroundColor: c.accent },
    circleTime: { ...stripTextProps(f.clockFocus), color: c.textPrimary },
    circleSub: { ...f.body, fontWeight: '700', color: c.textPrimary, marginTop: sp.xs },
    circleTitle: { ...f.title, color: c.onAccent },
    circleTitleSm: { ...f.button2, color: c.onAccent, textAlign: 'center' },
    onAccent: { color: c.onAccent },
    input: { backgroundColor: c.card, borderRadius: sh.radiusButton, padding: sp.m + sp.xs, ...f.body, lineHeight: 24, color: c.textPrimary, marginTop: sp.m, minHeight: 60 },
    inputBig: { ...f.sentence, minHeight: 110 },
    bellHead: { flexDirection: 'row', alignItems: 'flex-start', marginTop: sp.s, gap: sp.m },
    face: { width: 56, height: 56 },
    restRow: { flexDirection: 'row', alignItems: 'center', gap: sp.m },
    restImg: { width: 64, height: 64 },
    row: { flexDirection: 'row', paddingVertical: sp.s - 2, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: c.separator },
    rowK: { ...f.body, color: c.textSecondary, marginRight: sp.m },
    rowV: { ...f.body, color: c.textPrimary, flex: 1 },
    danger: { color: c.danger },
    listRow: { minHeight: 48, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: sp.s - 2, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: c.separator },
    veil: { flex: 1, backgroundColor: 'rgba(0,0,0,0.25)' },
    sheet: { backgroundColor: c.background, borderTopLeftRadius: sh.radiusSheet, borderTopRightRadius: sh.radiusSheet, padding: sp.l, paddingBottom: sp.xl + sp.xs },
    grabber: { width: 36, height: 5, borderRadius: 3, backgroundColor: c.fillButton, alignSelf: 'center', marginBottom: sp.m },
    pod: { flexDirection: 'row', alignItems: 'center', gap: 2, paddingVertical: 5, paddingHorizontal: 9, borderRadius: sh.radiusPill, alignSelf: 'flex-start' },
    podPea: { width: 18, height: 18 },
    trellis: { width: '100%', height: 150, marginBottom: sp.m },
    segRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', minHeight: 56, paddingVertical: sp.s, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: c.separator },
    seg: { flexDirection: 'row', gap: sp.s },
  });
}

// ---------- 樣式與開關用 context 傳，零件留在模組層級（避免每次 re-render 重掛） ----------
const Ctx = createContext(null);
const useS = () => useContext(Ctx);

function Chip({ label, onPress, dim, style, on }) {
  const { S, wire } = useS();
  return (
    <Pressable onPress={onPress} disabled={!onPress} style={[S.chip, on && S.chipOn, onPress && wire && S.wire, dim && { opacity: 0.5 }, style]}>
      <Text style={[S.chipTxt, on && S.chipTxtOn]}>{label}</Text>
    </Pressable>
  );
}
function Big({ label, onPress, style, second }) {
  const { S, wire } = useS();
  return (
    <Pressable onPress={onPress} style={[S.big, second && S.big2, wire && S.wire, style]} accessibilityRole="button">
      <Text style={second ? S.big2Txt : S.bigTxt}>{label}</Text>
    </Pressable>
  );
}
function TextBtn({ label, onPress, style, center }) {
  const { S, wire } = useS();
  return (
    <Pressable onPress={onPress} style={[S.txtBtn, wire && S.wire, style, center && { alignSelf: 'center' }]}><Text style={S.txtBtnTxt}>{label}</Text></Pressable>
  );
}
function Bean({ two, style }) {
  const { S, skin } = useS();
  if (!skin) return <View style={[S.pea, S.peaGray, two && S.pea2, style]} />;
  return <Image source={two ? IMG.pea2 : IMG.pea} style={[S.pea, two && S.pea2, style]} resizeMode="contain" />;
}
function Jar({ style, beans }) {
  const { S, wire } = useS();
  return (
    <Pressable style={[S.jar, wire && S.wire, style]} onPress={() => {}}>
      <Text style={S.lbl}>今天的豆子（傾斜會滾、點一下會彈：feel 做）</Text>
      {Array.from({ length: Math.min(beans, 40) }).map((_, i) => {
        const two = i % 4 === 3;
        const x = ((i * 73) % 300) + 8, y = ((i * 41) % 90) + 8;
        return <Bean key={i} two={two} style={{ left: x, bottom: y }} />;
      })}
    </Pressable>
  );
}
function Circle({ d, onPress, children, style, on }) {
  const { S, wire } = useS();
  return (
    <Pressable onPress={onPress} disabled={!onPress} style={[S.circle, on && S.circleOn, onPress && wire && S.wire, { width: d, height: d, borderRadius: d / 2 }, style]}>{children}</Pressable>
  );
}
function Row({ label, sub, onPress, bold, danger }) {
  const { S, wire } = useS();
  return (
    <Pressable onPress={onPress} style={[S.listRow, wire && S.wire]}>
      <Text style={[S.rowV, bold && { fontWeight: '700' }, danger && S.danger]}>{label}{sub ? <Text style={S.lbl}>　{sub}</Text> : null}</Text>
    </Pressable>
  );
}
function Seg({ value, onChange }) {
  return (
    <View style={useS().S.seg}>
      {DIRS.map((d) => <Chip key={d} label={d} on={d === value} onPress={() => onChange(d)} style={{ paddingHorizontal: 18 }} />)}
    </View>
  );
}
function SegRow({ label, sub, value, onChange }) {
  const { S } = useS();
  return (
    <View style={S.segRow}>
      <View style={{ flex: 1 }}><Text style={S.rowV}>{label}</Text>{sub ? <Text style={S.lbl}>{sub}</Text> : null}</View>
      <Seg value={value} onChange={onChange} />
    </View>
  );
}
function Pod({ n }) {
  const { S, skin, dark } = useS();
  const bg = skin ? (dark ? CharacterColors.pod.dark : CharacterColors.pod.light) : GRAY.fillButton;
  return (
    <View style={[S.pod, { backgroundColor: bg }]}>
      {Array.from({ length: n }).map((_, i) => (skin
        ? <Image key={i} source={IMG.pea} style={S.podPea} resizeMode="contain" />
        : <View key={i} style={[S.podPea, { borderRadius: 9, backgroundColor: '#bbb' }]} />))}
    </View>
  );
}
function Sheet({ children, title, onClose }) {
  const { S } = useS();
  return (
    <Modal visible transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={S.veil} onPress={onClose} />
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <View style={S.sheet}><View style={S.grabber} />{title ? <Text style={S.h2}>{title}</Text> : null}{children}</View>
      </KeyboardAvoidingView>
    </Modal>
  );
}
function Full({ children, title, onClose }) {
  const { S, wire } = useS();
  return (
    <Modal visible animationType="slide" onRequestClose={onClose}>
      <SafeAreaView style={S.safe}>
        <View style={S.nav}>
          <Pressable style={[S.navBtn, wire && S.wire]} onPress={onClose}><Text style={S.navTxt}>‹ 返回</Text></Pressable>
          <Text style={S.navTitle}>{title}</Text><View style={S.navBtn} />
        </View>
        <ScrollView contentContainerStyle={{ padding: 20 }}>{children}</ScrollView>
      </SafeAreaView>
    </Modal>
  );
}

export default function App() {
  const T0 = useTokens();
  const dark = T0._dark;
  const [dirIdle, setDirIdle] = useState('A');   // 待機／計時中／休息 用哪個方向
  const [dirBell, setDirBell] = useState('A');   // 鈴響 用哪個方向
  const [skin, setSkin] = useState(true);        // 上色（關＝灰盒子）
  const [loaded, setLoaded] = useState(false);
  const [wire, setWire] = useState(false);       // 虛線＝點擊範圍
  const [demo, setDemo] = useState(true);        // 1 分鐘＝1 秒
  const [debug, setDebug] = useState(false);
  const [jar, setJar] = useState(false);         // 豆罐手感原型（.uiux/04-手感）

  const [typeId, setTypeId] = useState('t1');
  const [clue, setClue] = useState(SENT);        // 空字串＝第一次
  const [phase, setPhase] = useState('idle');    // idle | focus | rest | bell
  const [endAt, setEndAt] = useState(0);
  const [now, setNow] = useState(Date.now());
  const [notes, setNotes] = useState([]);
  const [flowed, setFlowed] = useState(false);
  const [draft, setDraft] = useState('');
  const [beans, setBeans] = useState(5);
  const [sheet, setSheet] = useState(null);      // end | note | type | flow | rack | settings | null
  const [noteKind, setNoteKind] = useState('念頭');
  const [noteText, setNoteText] = useState('');
  const [firstIn, setFirstIn] = useState('');

  const T = useMemo(() => (skin ? T0 : { ...T0, color: GRAY }), [T0, skin]);
  const S = useMemo(() => makeStyles(T), [T]);
  const ctx = useMemo(() => ({ S, T, skin, wire, dark }), [S, T, skin, wire, dark]);

  // 版面選擇存手機，重開還在
  useEffect(() => {
    AsyncStorage.getItem(STORE_KEY).then((v) => {
      if (v) { const p = JSON.parse(v); if (DIRS.includes(p.dirIdle)) setDirIdle(p.dirIdle); if (DIRS.includes(p.dirBell)) setDirBell(p.dirBell); if (typeof p.skin === 'boolean') setSkin(p.skin); }
    }).catch(() => {}).finally(() => setLoaded(true));
  }, []);
  useEffect(() => {
    if (loaded) AsyncStorage.setItem(STORE_KEY, JSON.stringify({ dirIdle, dirBell, skin })).catch(() => {});
  }, [loaded, dirIdle, dirBell, skin]);

  const type = TYPES.find((t) => t.id === typeId);
  const unit = demo ? 1000 : 60000;
  const dims = useWindowDimensions();

  useEffect(() => {
    const h = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(h);
  }, []);
  useEffect(() => {
    if (phase === 'focus' && now >= endAt) setPhase('bell');
  }, [now, phase, endAt]);

  const start = () => { setNotes([]); setFlowed(false); setDraft(''); setEndAt(Date.now() + type.len * unit); setPhase('focus'); };
  const keep = (text) => {
    if (text) setClue(text);
    setBeans((b) => b + 1);
    setEndAt(Date.now() + Math.max(3, Math.round(type.len / 5)) * unit);
    setPhase('rest');
  };
  const flow = (m) => { setFlowed(true); setEndAt(Date.now() + m * unit); setPhase('focus'); setSheet(null); };
  const saveFirst = () => { if (firstIn.trim()) { setClue(firstIn.trim()); setFirstIn(''); } };
  const startFirst = () => { if (!firstIn.trim()) return; saveFirst(); start(); }; // 第一次：寫完直接開始（06 定案，一步）
  const addNote = () => { setNotes([...notes, { k: noteKind, v: noteText || '（沒寫）' }]); setNoteText(''); setSheet(null); };
  const left = endAt - now;
  const first = !clue;
  const close = () => setSheet(null);
  const dir = phase === 'bell' ? dirBell : dirIdle;
  const placeholderColor = skin ? T.color.textSecondary : '#999';
  const clockProps = { maxFontSizeMultiplier: T0.font.clock.maxFontSizeMultiplier };

  // ---------- 片段（純函式，不是元件） ----------
  const nav = () => (
    <View style={S.nav}>
      <Pressable style={[S.navBtn, wire && S.wire]} onPress={() => setSheet('rack')} accessibilityRole="button"><Text style={S.navTxt}>豆棚</Text></Pressable>
      <Pressable style={S.debugBtn} onPress={() => setDebug(true)} accessibilityLabel="除錯"><Text style={S.debugTxt}>{dirIdle}·{dirBell}</Text></Pressable>
      <Pressable style={[S.navBtn, wire && S.wire]} onPress={() => setSheet('settings')} accessibilityRole="button"><Text style={S.navTxt}>設定</Text></Pressable>
    </View>
  );
  const pair = () => (
    <View style={S.pair}>
      <Chip label="冒出念頭" onPress={() => { setNoteKind('念頭'); setSheet('note'); }} style={{ flex: 1 }} />
      <Chip label="有人找" onPress={() => { setNoteKind('有人找'); setSheet('note'); }} style={{ flex: 1 }} />
    </View>
  );
  const firstInput = () => (
    <View>
      {skin ? <Image source={IMG.empty} style={S.ill} resizeMode="contain" /> : null}
      <Text style={S.lbl}>寫下接下來要做的第一件事，寫到具體的動作</Text>
      <TextInput style={[S.input, wire && S.wire]} multiline value={firstIn} onChangeText={setFirstIn}
        placeholder="例：打開讀書筆記，把三個重點各寫一句" placeholderTextColor={placeholderColor} />
    </View>
  );
  const typeChip = (style) => <Chip label={`${type.name}・${type.len} 分 ›`} onPress={() => setSheet('type')} style={style} />;
  const clueBlock = (deco = true) => (
    <>
      {skin && deco ? <Image source={IMG.sprout} style={S.deco} resizeMode="contain" /> : null}
      <Text style={S.lbl}>昨天的你留了一句</Text><Text style={S.sent}>{clue}</Text>
    </>
  );
  const focusBlock = (left_) => (<><Text {...clockProps} style={[S.timeBig, left_ && { textAlign: 'left' }]}>{mmss(left)}</Text><Text style={S.lbl}>正在做</Text><Text style={S.body}>{clue}</Text></>);
  const restBlock = (left_) => (
    <>
      <Text {...clockProps} style={[S.timeBig, left_ && { textAlign: 'left' }]}>{mmss(left)}</Text>
      <View style={S.restRow}>
        {skin ? <Image source={IMG.restWater} style={S.restImg} resizeMode="contain" /> : null}
        <View style={{ flex: 1 }}><Text style={S.lbl}>休息</Text><Text style={S.body}>{REST_TEXT}</Text></View>
      </View>
    </>
  );

  // ---------- 主畫面 ----------
  const home = () => {
    if (dir === 'A') return (
      <View style={S.fill}>
        <View style={S.card}>
          {phase === 'idle' && first ? firstInput() : null}
          {phase === 'idle' && !first ? clueBlock() : null}
          {phase === 'focus' ? focusBlock() : null}
          {phase === 'rest' ? restBlock() : null}
        </View>
        {phase === 'idle' ? typeChip({ alignSelf: 'center', marginTop: 12 }) : null}
        {phase === 'idle' ? <Text {...clockProps} style={S.timeMid}>{type.len}:00</Text> : null}
        {phase === 'focus' ? pair() : null}
        <Jar beans={beans} style={{ flex: 1, marginTop: 12 }} />
        {phase === 'idle' && first ? <Big label="開始這顆" onPress={startFirst} /> : null}
        {phase === 'idle' && !first ? <Big label="開始" onPress={start} /> : null}
        {phase === 'focus' ? <TextBtn label="結束" onPress={() => setSheet('end')} center /> : null}
        {phase === 'rest' ? <Big label="回來了，開始下一顆" onPress={() => setPhase('idle')} /> : null}
      </View>
    );
    if (dir === 'B') {
      const tapCard = phase === 'idle' && !first ? start : phase === 'focus' ? () => setSheet('end') : phase === 'rest' ? () => setPhase('idle') : null;
      const hint = phase === 'idle' && !first ? `點一下開始・${type.len} 分` : phase === 'focus' ? '點一下：結束這顆（開半頁）' : phase === 'rest' ? '點一下開始下一顆' : '';
      return (
        <View style={S.fill}>
          <Chip label={`${type.name}・${type.len} 分 ›`} onPress={phase === 'idle' ? () => setSheet('type') : null} dim={phase !== 'idle'} style={{ alignSelf: 'center' }} />
          <View style={{ flex: 1, justifyContent: 'center' }}>
            <Pressable onPress={tapCard} disabled={!tapCard} style={[S.card, S.cardB, tapCard && wire && S.wire]}>
              {phase === 'idle' && first ? firstInput() : null}
              {phase === 'idle' && !first ? clueBlock() : null}
              {phase === 'focus' ? focusBlock(true) : null}
              {phase === 'rest' ? restBlock(true) : null}
              {hint ? <Text style={S.hint}>{hint}</Text> : null}
            </Pressable>
            {phase === 'idle' && first ? <Big label="開始這顆" onPress={startFirst} style={{ marginTop: 16 }} /> : null}
          </View>
          {phase === 'focus' ? pair() : null}
          <Jar beans={beans} style={{ height: 230 }} />
        </View>
      );
    }
    // C
    const tapCircle = phase === 'idle' && !first ? start : phase === 'idle' && first ? startFirst : phase === 'focus' ? () => setSheet('end') : () => setPhase('idle');
    const primary = phase === 'idle' || phase === 'rest';
    return (
      <View style={S.fill}>
        <View style={{ minHeight: 150 }}>
          {phase === 'idle' && first ? firstInput() : null}
          {phase === 'idle' && !first ? clueBlock(false) : null}
          {phase === 'focus' ? (<><Text style={S.lbl}>正在做</Text><Text style={S.sent}>{clue}</Text></>) : null}
          {phase === 'rest' ? (<><Text style={S.lbl}>休息</Text><Text style={S.sent}>{REST_TEXT}</Text></>) : null}
        </View>
        {phase === 'idle' ? typeChip({ alignSelf: 'center', marginVertical: 12 }) : <View style={{ height: 24 }} />}
        <Circle d={220} onPress={tapCircle} on={primary} style={{ alignSelf: 'center' }}>
          {phase === 'idle' && first ? <Text style={S.circleTitle}>開始這顆</Text> : null}
          {phase === 'idle' && !first ? (<><Text {...clockProps} style={[S.circleTime, S.onAccent]}>{type.len}:00</Text><Text style={[S.circleSub, S.onAccent]}>開始</Text></>) : null}
          {phase === 'focus' ? (<><Text {...clockProps} style={S.circleTime}>{mmss(left)}</Text><Text style={S.hint}>點一下：結束這顆</Text></>) : null}
          {phase === 'rest' ? (<><Text {...clockProps} style={[S.circleTime, S.onAccent]}>{mmss(left)}</Text><Text style={[S.circleSub, S.onAccent]}>開始下一顆</Text></>) : null}
        </Circle>
        {phase === 'focus' ? pair() : null}
        <Jar beans={beans} style={{ flex: 1, marginTop: 12 }} />
      </View>
    );
  };

  // ---------- 鈴響・寫一句 ----------
  const bell = () => {
    const input = (
      <TextInput style={[S.input, S.inputBig, wire && S.wire]} multiline value={draft} onChangeText={setDraft} autoFocus
        placeholder="寫一行給下一顆的自己" placeholderTextColor={placeholderColor}
        returnKeyType={dir === 'C' ? 'done' : 'default'} blurOnSubmit={dir === 'C'}
        onSubmitEditing={dir === 'C' ? () => keep(draft.trim()) : undefined} />
    );
    const skip = !draft.trim() ? <TextBtn label="這顆不留話" onPress={() => keep('')} center={dir === 'C'} /> : <View style={{ height: 44 }} />;
    const list = (
      <View style={{ marginTop: 12 }}>
        {notes.map((n, i) => (<View key={i} style={S.row}><Text style={S.rowK}>{n.k}</Text><Text style={S.rowV}>{n.v}</Text></View>))}
      </View>
    );
    const head = (
      <View style={S.bellHead}>
        {skin ? <Image source={IMG.faceThink} style={S.face} resizeMode="contain" /> : null}
        <View style={{ flex: 1 }}><Text style={S.h1}>響了。</Text><Text style={S.lbl}>寫一行給下一顆的自己。</Text></View>
        {!flowed ? <TextBtn label="再做 15 分・30 分" onPress={() => setSheet('flow')} /> : null}
      </View>
    );
    if (dir === 'A') return (
      <View style={S.fill}>
        {head}{input}{skip}{list}
        <View style={{ flex: 1 }} />
        <Big label="收下這顆" onPress={() => keep(draft.trim())} />
      </View>
    );
    if (dir === 'B') return (
      <View style={S.fill}>
        {head}
        <View style={{ height: 40 }} />
        {!draft.trim() ? <TextBtn label="這顆不留話" onPress={() => keep('')} style={{ alignSelf: 'flex-start' }} /> : <View style={{ height: 44 }} />}
        {input}
        <Big label="收下這顆" onPress={() => keep(draft.trim())} style={{ marginTop: 16 }} />
        {list}
      </View>
    );
    return (
      <View style={S.fill}>
        {head}{input}
        <Circle d={120} onPress={() => keep(draft.trim())} on style={{ alignSelf: 'center', marginTop: 20 }}>
          <Text style={S.circleTitleSm}>收下{'\n'}這顆</Text>
        </Circle>
        {skip}{list}
      </View>
    );
  };

  // ---------- 半頁與全頁 ----------
  const sheets = {
    end: () => (
      <Sheet title="結束這顆？" onClose={close}>
        <Row label="提早做完了" sub="剩下的時間小修，鈴響再停" onPress={close} />
        <Row label="作廢這顆" sub="只記一筆，不扣任何東西" onPress={() => { setPhase('idle'); close(); }} />
        <Big label="繼續做" onPress={close} second style={{ marginTop: 12 }} />
      </Sheet>
    ),
    note: () => (
      <Sheet title={noteKind === '念頭' ? '冒出什麼念頭？' : '誰找你、什麼事？'} onClose={close}>
        <Text style={S.lbl}>寫一行就好，休息時再處理。</Text>
        <TextInput style={[S.input, wire && S.wire]} value={noteText} onChangeText={setNoteText} autoFocus returnKeyType="done" onSubmitEditing={addNote} placeholderTextColor={placeholderColor} />
        <Big label="記下" onPress={addNote} style={{ marginTop: 12 }} />
      </Sheet>
    ),
    type: () => (
      <Sheet title="這顆要多長？" onClose={close}>
        {TYPES.map((t) => <Row key={t.id} label={`${t.name}　${t.len} 分`} bold={t.id === typeId} onPress={() => { setTypeId(t.id); close(); }} />)}
        <Row label="這件事估幾顆" sub="選填，對帳用" onPress={close} />
      </Sheet>
    ),
    flow: () => (
      <Sheet title="在狀態裡，再做一下" onClose={close}>
        <Text style={S.lbl}>先定一個上限，到點會再響一次，那時再寫下一步。</Text>
        <View style={S.pair}><Big label="再 15 分" onPress={() => flow(15)} second style={{ flex: 1 }} /><Big label="再 30 分" onPress={() => flow(30)} second style={{ flex: 1 }} /></View>
      </Sheet>
    ),
    rack: () => (
      <Full title="豆棚" onClose={close}>
        {skin ? <View style={[S.card, { marginTop: 0, padding: 12 }]}><Image source={IMG.trellis} style={S.trellis} resizeMode="contain" /></View> : null}
        <Text style={[S.lbl, { marginTop: 12 }]}>這週</Text>
        <View style={S.listRow}><Text style={S.rowV}>11月1日　星期六</Text><Pod n={Math.min(beans, 12)} /></View>
        <View style={S.listRow}><Text style={S.rowV}>10月31日　星期五</Text><Pod n={4} /></View>
        <Row label="翻到背面：這週的收據" onPress={() => {}} />
        <Text style={[S.lbl, { marginTop: 20 }]}>10月20日 那週</Text>
        <Row label="…" onPress={() => {}} />
      </Full>
    ),
    settings: () => (
      <Full title="設定" onClose={close}>
        <Text style={S.lbl}>版面（比對用，選定後正式版拿掉）</Text>
        <SegRow label="待機畫面" sub="待機、計時中、休息" value={dirIdle} onChange={setDirIdle} />
        <SegRow label="鈴響畫面" sub="寫一句、收下" value={dirBell} onChange={setDirBell} />
        <Text style={[S.lbl, { marginTop: 20 }]}>任務類型</Text>
        {TYPES.map((t) => <Row key={t.id} label={t.name} sub={`${t.len} 分`} onPress={() => {}} />)}
        <Row label="加一種" onPress={() => {}} />
        <Text style={[S.lbl, { marginTop: 20 }]}>節奏</Text>
        <Row label="休息" sub="到點提醒我" onPress={() => {}} /><Row label="收工時間" sub="19:00" onPress={() => {}} />
        <Text style={[S.lbl, { marginTop: 20 }]}>提醒</Text>
        <Row label="到點通知" sub="只會這一種" onPress={() => {}} /><Row label="聲音" onPress={() => {}} />
        <Text style={[S.lbl, { marginTop: 20 }]}>手感</Text>
        <Row label="傾斜手機，豆子跟著滾" onPress={() => {}} />
        <Text style={[S.lbl, { marginTop: 20 }]}>備份</Text>
        <Row label="匯出備份" onPress={() => {}} /><Row label="從備份匯入" onPress={() => {}} />
        <View style={{ height: 40 }} />
        <Row label="清空所有資料" bold danger onPress={() => {}} />
      </Full>
    ),
  };

  return (
    <Ctx.Provider value={ctx}>
      <SafeAreaView style={S.safe}>
        <StatusBar style="auto" />
        <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          {phase !== 'bell' ? nav() : <View style={{ height: 8 }} />}
          <View style={S.content}>{phase === 'bell' ? bell() : home()}</View>
        </KeyboardAvoidingView>
        {sheet ? sheets[sheet]() : null}
        {jar ? <Modal visible animationType="slide" onRequestClose={() => setJar(false)}><JarProto beans={beans} onClose={() => setJar(false)} /></Modal> : null}
        {debug ? (
          <Sheet title="除錯（測試者看不到這頁）" onClose={() => setDebug(false)}>
            <SegRow label="待機畫面" value={dirIdle} onChange={setDirIdle} />
            <SegRow label="鈴響畫面" value={dirBell} onChange={setDirBell} />
            <View style={S.listRow}><Text style={S.rowV}>上色（關＝灰盒子，給新人測方向用）</Text><Switch value={skin} onValueChange={setSkin} /></View>
            <View style={S.listRow}><Text style={S.rowV}>虛線＝點擊範圍</Text><Switch value={wire} onValueChange={setWire} /></View>
            <View style={S.listRow}><Text style={S.rowV}>試玩速度（1 分＝1 秒）</Text><Switch value={demo} onValueChange={setDemo} /></View>
            <View style={S.pair}>
              <Big label="＋1 豆" second onPress={() => setBeans((b) => b + 1)} style={{ flex: 1 }} />
              <Big label="40 豆" second onPress={() => setBeans(40)} style={{ flex: 1 }} />
              <Big label="重設為第一次" second onPress={() => { setClue(''); setBeans(0); setPhase('idle'); setDebug(false); }} style={{ flex: 1 }} />
            </View>
            <Big label="塞 120 字那句" second onPress={() => { setClue(SENT_LONG); setDebug(false); }} style={{ marginTop: 8 }} />
            <Big label="豆罐手感原型" onPress={() => { setDebug(false); setJar(true); }} style={{ marginTop: 8 }} />
            <Text style={[S.lbl, { marginTop: 12 }]}>
              螢幕 {Math.round(dims.width)}×{Math.round(dims.height)} pt　字級倍率 {PixelRatio.getFontScale().toFixed(2)}　{dark ? '深色' : '淺色'}　{Platform.OS} {Platform.Version}
            </Text>
            <Text style={S.lbl}>最大字級測法：iPhone 設定 → 輔助使用 → 顯示與文字大小 → 更大的文字，拉到最右，回來看每一頁。</Text>
          </Sheet>
        ) : null}
      </SafeAreaView>
    </Ctx.Provider>
  );
}
