// 豆帳 灰盒子（3-3 線框，不是成品）：灰色方塊＋系統字，停在這裡，不調漂亮。
// 右上角的「A／B／C」字母是除錯入口：切方向、試玩速度、看字級倍率與螢幕尺寸。
import React, { useEffect, useState } from 'react';
import {
  KeyboardAvoidingView, Modal, PixelRatio, Platform, Pressable, SafeAreaView, ScrollView,
  StyleSheet, Switch, Text, TextInput, useWindowDimensions, View,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';

const SENT = '打開讀書筆記，把三個重點各寫一句';
const SENT_LONG = '先把《原子習慣》第三章的筆記打開，找出昨天標了星號的三段，各寫一句話說明它跟我自己的早晨流程有什麼關係，寫完貼到課程大綱第二節的開頭，再順手把第二節的標題改成問句，最後檢查字數有沒有超過一百二十個字';
const TYPES = [
  { id: 't1', name: '一般', len: 25 },
  { id: 't2', name: '寫作', len: 50 },
  { id: 't3', name: '短的', len: 15 },
];
const REST_TEXT = '離開螢幕。喝水、看遠處、伸展、閉眼都好。';

const mmss = (ms) => {
  const s = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
};

// ---------- 模組層級的零件（不放在 App 裡，避免每次 re-render 重掛） ----------
const wireOf = (wire) => (wire ? styles.wire : null);

function Chip({ label, onPress, dim, style, wire }) {
  return (
    <Pressable onPress={onPress} disabled={!onPress} style={[styles.chip, onPress && wireOf(wire), dim && { opacity: 0.5 }, style]}>
      <Text style={styles.chipTxt}>{label}</Text>
    </Pressable>
  );
}
function Big({ label, onPress, style, wire }) {
  return (
    <Pressable onPress={onPress} style={[styles.big, wireOf(wire), style]} accessibilityRole="button"><Text style={styles.bigTxt}>{label}</Text></Pressable>
  );
}
function TextBtn({ label, onPress, style, center, wire }) {
  return (
    <Pressable onPress={onPress} style={[styles.txtBtn, wireOf(wire), style, center && { alignSelf: 'center' }]}><Text style={styles.txtBtnTxt}>{label}</Text></Pressable>
  );
}
function Jar({ style, beans, wire }) {
  return (
    <Pressable style={[styles.jar, wireOf(wire), style]} onPress={() => {}}>
      <Text style={styles.lbl}>今天的豆子（傾斜會滾、點一下會彈：feel 做）</Text>
      {Array.from({ length: Math.min(beans, 40) }).map((_, i) => {
        const two = i % 4 === 3;
        const x = ((i * 73) % 300) + 8, y = ((i * 41) % 90) + 8;
        return <View key={i} style={[styles.pea, two && styles.pea2, { left: x, bottom: y }]} />;
      })}
    </Pressable>
  );
}
function Circle({ d, onPress, children, style, wire }) {
  return (
    <Pressable onPress={onPress} disabled={!onPress} style={[styles.circle, onPress && wireOf(wire), { width: d, height: d, borderRadius: d / 2 }, style]}>{children}</Pressable>
  );
}
function Row({ label, sub, onPress, bold, wire }) {
  return (
    <Pressable onPress={onPress} style={[styles.listRow, wireOf(wire)]}>
      <Text style={[styles.rowV, bold && { fontWeight: '700' }]}>{label}{sub ? <Text style={styles.lbl}>　{sub}</Text> : null}</Text>
    </Pressable>
  );
}
function Sheet({ children, title, onClose }) {
  return (
    <Modal visible transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={styles.veil} onPress={onClose} />
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <View style={styles.sheet}><View style={styles.grabber} />{title ? <Text style={styles.h2}>{title}</Text> : null}{children}</View>
      </KeyboardAvoidingView>
    </Modal>
  );
}
function Full({ children, title, onClose, wire }) {
  return (
    <Modal visible animationType="slide" onRequestClose={onClose}>
      <SafeAreaView style={styles.safe}>
        <View style={styles.nav}>
          <Pressable style={[styles.navBtn, wireOf(wire)]} onPress={onClose}><Text style={styles.navTxt}>‹ 返回</Text></Pressable>
          <Text style={styles.navTitle}>{title}</Text><View style={styles.navBtn} />
        </View>
        <ScrollView contentContainerStyle={{ padding: 20 }}>{children}</ScrollView>
      </SafeAreaView>
    </Modal>
  );
}

export default function App() {
  const [dir, setDir] = useState('A');
  const [wire, setWire] = useState(true);       // 虛線＝點擊範圍
  const [demo, setDemo] = useState(true);       // 1 分鐘＝1 秒
  const [debug, setDebug] = useState(false);

  const [typeId, setTypeId] = useState('t1');
  const [clue, setClue] = useState(SENT);       // 空字串＝第一次
  const [phase, setPhase] = useState('idle');   // idle | focus | rest | bell
  const [endAt, setEndAt] = useState(0);
  const [now, setNow] = useState(Date.now());
  const [notes, setNotes] = useState([]);
  const [flowed, setFlowed] = useState(false);
  const [draft, setDraft] = useState('');
  const [beans, setBeans] = useState(5);
  const [sheet, setSheet] = useState(null);     // end | note | type | flow | rack | settings | null
  const [noteKind, setNoteKind] = useState('念頭');
  const [noteText, setNoteText] = useState('');
  const [firstIn, setFirstIn] = useState('');

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
  const addNote = () => { setNotes([...notes, { k: noteKind, v: noteText || '（沒寫）' }]); setNoteText(''); setSheet(null); };
  const left = endAt - now;
  const first = !clue;
  const close = () => setSheet(null);
  const w = { wire };

  // ---------- 片段（純函式，不是元件） ----------
  const nav = () => (
    <View style={styles.nav}>
      <Pressable style={[styles.navBtn, wireOf(wire)]} onPress={() => setSheet('rack')} accessibilityRole="button"><Text style={styles.navTxt}>豆棚</Text></Pressable>
      <Pressable style={styles.debugBtn} onPress={() => setDebug(true)} accessibilityLabel="除錯"><Text style={styles.debugTxt}>{dir}</Text></Pressable>
      <Pressable style={[styles.navBtn, wireOf(wire)]} onPress={() => setSheet('settings')} accessibilityRole="button"><Text style={styles.navTxt}>設定</Text></Pressable>
    </View>
  );
  const pair = () => (
    <View style={styles.pair}>
      <Chip {...w} label="冒出念頭" onPress={() => { setNoteKind('念頭'); setSheet('note'); }} style={{ flex: 1 }} />
      <Chip {...w} label="有人找" onPress={() => { setNoteKind('有人找'); setSheet('note'); }} style={{ flex: 1 }} />
    </View>
  );
  const firstInput = () => (
    <View>
      <Text style={styles.lbl}>寫下接下來要做的第一件事，寫到具體的動作</Text>
      <TextInput style={[styles.input, wireOf(wire)]} multiline value={firstIn} onChangeText={setFirstIn}
        placeholder="例：打開讀書筆記，把三個重點各寫一句" placeholderTextColor="#999" />
    </View>
  );
  const typeChip = (style) => <Chip {...w} label={`${type.name}・${type.len} 分 ›`} onPress={() => setSheet('type')} style={style} />;
  const clueBlock = () => (<><Text style={styles.lbl}>昨天的你留了一句</Text><Text style={styles.sent}>{clue}</Text></>);
  const focusBlock = (left_) => (<><Text style={[styles.timeBig, left_ && { textAlign: 'left' }]}>{mmss(left)}</Text><Text style={styles.lbl}>正在做</Text><Text style={styles.body}>{clue}</Text></>);
  const restBlock = (left_) => (<><Text style={[styles.timeBig, left_ && { textAlign: 'left' }]}>{mmss(left)}</Text><Text style={styles.lbl}>休息</Text><Text style={styles.body}>{REST_TEXT}</Text></>);

  // ---------- 主畫面 ----------
  const home = () => {
    if (dir === 'A') return (
      <View style={styles.fill}>
        <View style={styles.card}>
          {phase === 'idle' && first ? firstInput() : null}
          {phase === 'idle' && !first ? clueBlock() : null}
          {phase === 'focus' ? focusBlock() : null}
          {phase === 'rest' ? restBlock() : null}
        </View>
        {phase === 'idle' ? typeChip({ alignSelf: 'center', marginTop: 12 }) : null}
        {phase === 'idle' ? <Text style={styles.timeMid}>{type.len}:00</Text> : null}
        {phase === 'focus' ? pair() : null}
        <Jar {...w} beans={beans} style={{ flex: 1, marginTop: 12 }} />
        {phase === 'idle' && first ? <Big {...w} label="記下來" onPress={saveFirst} /> : null}
        {phase === 'idle' && !first ? <Big {...w} label="開始" onPress={start} /> : null}
        {phase === 'focus' ? <TextBtn {...w} label="結束" onPress={() => setSheet('end')} center /> : null}
        {phase === 'rest' ? <Big {...w} label="回來了，開始下一顆" onPress={() => setPhase('idle')} /> : null}
      </View>
    );
    if (dir === 'B') {
      const tapCard = phase === 'idle' && !first ? start : phase === 'focus' ? () => setSheet('end') : phase === 'rest' ? () => setPhase('idle') : null;
      const hint = phase === 'idle' && !first ? `點一下開始・${type.len} 分` : phase === 'focus' ? '點一下：結束這顆（開半頁）' : phase === 'rest' ? '點一下開始下一顆' : '';
      return (
        <View style={styles.fill}>
          <Chip {...w} label={`${type.name}・${type.len} 分 ›`} onPress={phase === 'idle' ? () => setSheet('type') : null} dim={phase !== 'idle'} style={{ alignSelf: 'center' }} />
          <View style={{ flex: 1, justifyContent: 'center' }}>
            <Pressable onPress={tapCard} disabled={!tapCard} style={[styles.card, styles.cardB, tapCard && wireOf(wire)]}>
              {phase === 'idle' && first ? firstInput() : null}
              {phase === 'idle' && !first ? clueBlock() : null}
              {phase === 'focus' ? focusBlock(true) : null}
              {phase === 'rest' ? restBlock(true) : null}
              {hint ? <Text style={styles.hint}>{hint}</Text> : null}
            </Pressable>
            {phase === 'idle' && first ? <Big {...w} label="記下來" onPress={saveFirst} style={{ marginTop: 16 }} /> : null}
          </View>
          {phase === 'focus' ? pair() : null}
          <Jar {...w} beans={beans} style={{ height: 230 }} />
        </View>
      );
    }
    // C
    const tapCircle = phase === 'idle' && !first ? start : phase === 'idle' && first ? saveFirst : phase === 'focus' ? () => setSheet('end') : () => setPhase('idle');
    return (
      <View style={styles.fill}>
        <View style={{ minHeight: 150 }}>
          {phase === 'idle' && first ? firstInput() : null}
          {phase === 'idle' && !first ? clueBlock() : null}
          {phase === 'focus' ? (<><Text style={styles.lbl}>正在做</Text><Text style={styles.sent}>{clue}</Text></>) : null}
          {phase === 'rest' ? (<><Text style={styles.lbl}>休息</Text><Text style={styles.sent}>{REST_TEXT}</Text></>) : null}
        </View>
        {phase === 'idle' ? typeChip({ alignSelf: 'center', marginVertical: 12 }) : <View style={{ height: 24 }} />}
        <Circle {...w} d={220} onPress={tapCircle} style={{ alignSelf: 'center' }}>
          {phase === 'idle' && first ? <Text style={styles.circleTitle}>記下來</Text> : null}
          {phase === 'idle' && !first ? (<><Text style={styles.circleTime}>{type.len}:00</Text><Text style={styles.circleSub}>開始</Text></>) : null}
          {phase === 'focus' ? (<><Text style={styles.circleTime}>{mmss(left)}</Text><Text style={styles.hint}>點一下：結束這顆</Text></>) : null}
          {phase === 'rest' ? (<><Text style={styles.circleTime}>{mmss(left)}</Text><Text style={styles.circleSub}>開始下一顆</Text></>) : null}
        </Circle>
        {phase === 'focus' ? pair() : null}
        <Jar {...w} beans={beans} style={{ flex: 1, marginTop: 12 }} />
      </View>
    );
  };

  // ---------- 鈴響・寫一句 ----------
  const bell = () => {
    const input = (
      <TextInput style={[styles.input, wireOf(wire), { minHeight: 110 }]} multiline value={draft} onChangeText={setDraft} autoFocus
        placeholder="寫一行給下一顆的自己" placeholderTextColor="#999"
        returnKeyType={dir === 'C' ? 'done' : 'default'} blurOnSubmit={dir === 'C'}
        onSubmitEditing={dir === 'C' ? () => keep(draft.trim()) : undefined} />
    );
    const skip = !draft.trim() ? <TextBtn {...w} label="這顆不留話" onPress={() => keep('')} center={dir === 'C'} /> : <View style={{ height: 44 }} />;
    const list = (
      <View style={{ marginTop: 12 }}>
        {notes.map((n, i) => (<View key={i} style={styles.row}><Text style={styles.rowK}>{n.k}</Text><Text style={styles.rowV}>{n.v}</Text></View>))}
      </View>
    );
    const head = (
      <View style={styles.bellHead}>
        <View style={{ flex: 1 }}><Text style={styles.h1}>響了。</Text><Text style={styles.lbl}>寫一行給下一顆的自己。</Text></View>
        {!flowed ? <TextBtn {...w} label="再做 15 分・30 分" onPress={() => setSheet('flow')} /> : null}
      </View>
    );
    if (dir === 'A') return (
      <View style={styles.fill}>
        {head}{input}{skip}{list}
        <View style={{ flex: 1 }} />
        <Big {...w} label="收下這顆" onPress={() => keep(draft.trim())} />
      </View>
    );
    if (dir === 'B') return (
      <View style={styles.fill}>
        {head}
        <View style={{ height: 40 }} />
        {!draft.trim() ? <TextBtn {...w} label="這顆不留話" onPress={() => keep('')} style={{ alignSelf: 'flex-start' }} /> : <View style={{ height: 44 }} />}
        {input}
        <Big {...w} label="收下這顆" onPress={() => keep(draft.trim())} style={{ marginTop: 16 }} />
        {list}
      </View>
    );
    return (
      <View style={styles.fill}>
        {head}{input}
        <Circle {...w} d={120} onPress={() => keep(draft.trim())} style={{ alignSelf: 'center', marginTop: 20 }}>
          <Text style={styles.circleTitleSm}>收下{'\n'}這顆</Text>
        </Circle>
        {skip}{list}
      </View>
    );
  };

  // ---------- 半頁與全頁 ----------
  const sheets = {
    end: () => (
      <Sheet title="結束這顆？" onClose={close}>
        <Row {...w} label="提早做完了" sub="剩下的時間小修，鈴響再停" onPress={close} />
        <Row {...w} label="作廢這顆" sub="只記一筆，不扣任何東西" onPress={() => { setPhase('idle'); close(); }} />
        <Big {...w} label="繼續做" onPress={close} style={{ marginTop: 12, backgroundColor: '#ddd' }} />
      </Sheet>
    ),
    note: () => (
      <Sheet title={noteKind === '念頭' ? '冒出什麼念頭？' : '誰找你、什麼事？'} onClose={close}>
        <Text style={styles.lbl}>寫一行就好，休息時再處理。</Text>
        <TextInput style={[styles.input, wireOf(wire)]} value={noteText} onChangeText={setNoteText} autoFocus returnKeyType="done" onSubmitEditing={addNote} />
        <Big {...w} label="記下" onPress={addNote} style={{ marginTop: 12 }} />
      </Sheet>
    ),
    type: () => (
      <Sheet title="這顆要多長？" onClose={close}>
        {TYPES.map((t) => <Row {...w} key={t.id} label={`${t.name}　${t.len} 分`} bold={t.id === typeId} onPress={() => { setTypeId(t.id); close(); }} />)}
        <Row {...w} label="這件事估幾顆" sub="選填，對帳用" onPress={close} />
      </Sheet>
    ),
    flow: () => (
      <Sheet title="在狀態裡，再做一下" onClose={close}>
        <Text style={styles.lbl}>先定一個上限，到點會再響一次，那時再寫下一步。</Text>
        <View style={styles.pair}><Big {...w} label="再 15 分" onPress={() => flow(15)} style={{ flex: 1, backgroundColor: '#ddd' }} /><Big {...w} label="再 30 分" onPress={() => flow(30)} style={{ flex: 1, backgroundColor: '#ddd' }} /></View>
      </Sheet>
    ),
    rack: () => (
      <Full title="豆棚" onClose={close} wire={wire}>
        <Text style={styles.lbl}>這週</Text>
        <Row {...w} label="10月31日　星期五" sub={`${beans} 顆`} onPress={() => {}} />
        <Row {...w} label="10月30日　星期四" sub="4 顆" onPress={() => {}} />
        <Row {...w} label="翻到背面：這週的收據" onPress={() => {}} />
        <Text style={[styles.lbl, { marginTop: 20 }]}>10月20日 那週</Text>
        <Row {...w} label="…" onPress={() => {}} />
      </Full>
    ),
    settings: () => (
      <Full title="設定" onClose={close} wire={wire}>
        <Text style={styles.lbl}>任務類型</Text>
        {TYPES.map((t) => <Row {...w} key={t.id} label={t.name} sub={`${t.len} 分`} onPress={() => {}} />)}
        <Row {...w} label="加一種" onPress={() => {}} />
        <Text style={[styles.lbl, { marginTop: 20 }]}>節奏</Text>
        <Row {...w} label="休息" sub="到點提醒我" onPress={() => {}} /><Row {...w} label="收工時間" sub="19:00" onPress={() => {}} />
        <Text style={[styles.lbl, { marginTop: 20 }]}>提醒</Text>
        <Row {...w} label="到點通知" sub="只會這一種" onPress={() => {}} /><Row {...w} label="聲音" onPress={() => {}} />
        <Text style={[styles.lbl, { marginTop: 20 }]}>手感</Text>
        <Row {...w} label="傾斜手機，豆子跟著滾" onPress={() => {}} />
        <Text style={[styles.lbl, { marginTop: 20 }]}>備份</Text>
        <Row {...w} label="匯出備份" onPress={() => {}} /><Row {...w} label="從備份匯入" onPress={() => {}} />
        <View style={{ height: 40 }} />
        <Row {...w} label="清空所有資料" bold onPress={() => {}} />
      </Full>
    ),
  };

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar style="dark" />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        {phase !== 'bell' ? nav() : <View style={{ height: 8 }} />}
        <View style={styles.content}>{phase === 'bell' ? bell() : home()}</View>
      </KeyboardAvoidingView>
      {sheet ? sheets[sheet]() : null}
      {debug ? (
        <Sheet title="除錯（測試者看不到這頁）" onClose={() => setDebug(false)}>
          <View style={styles.pair}>{['A', 'B', 'C'].map((d) => <Big key={d} label={`方向 ${d}`} onPress={() => { setDir(d); setDebug(false); }} style={{ flex: 1, backgroundColor: d === dir ? '#333' : '#bbb' }} />)}</View>
          <View style={styles.listRow}><Text style={styles.rowV}>虛線＝點擊範圍</Text><Switch value={wire} onValueChange={setWire} /></View>
          <View style={styles.listRow}><Text style={styles.rowV}>試玩速度（1 分＝1 秒）</Text><Switch value={demo} onValueChange={setDemo} /></View>
          <View style={styles.pair}>
            <Big label="＋1 豆" onPress={() => setBeans((b) => b + 1)} style={{ flex: 1, backgroundColor: '#bbb' }} />
            <Big label="40 豆" onPress={() => setBeans(40)} style={{ flex: 1, backgroundColor: '#bbb' }} />
            <Big label="重設為第一次" onPress={() => { setClue(''); setBeans(0); setPhase('idle'); setDebug(false); }} style={{ flex: 1, backgroundColor: '#bbb' }} />
          </View>
          <Big label="塞 120 字那句" onPress={() => { setClue(SENT_LONG); setDebug(false); }} style={{ backgroundColor: '#bbb', marginTop: 8 }} />
          <Text style={[styles.lbl, { marginTop: 12 }]}>
            螢幕 {Math.round(dims.width)}×{Math.round(dims.height)} pt　字級倍率 {PixelRatio.getFontScale().toFixed(2)}　{Platform.OS} {Platform.Version}
          </Text>
          <Text style={styles.lbl}>最大字級測法：iPhone 設定 → 輔助使用 → 顯示與文字大小 → 更大的文字，拉到最右，回來看每一頁。</Text>
        </Sheet>
      ) : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#fff' },
  content: { flex: 1, paddingHorizontal: 20, paddingBottom: 16 },
  fill: { flex: 1 },
  wire: { borderWidth: 1, borderColor: '#444', borderStyle: 'dashed' },
  nav: { height: 44, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 8, marginTop: 8 },
  navBtn: { minWidth: 60, height: 44, justifyContent: 'center', alignItems: 'center', paddingHorizontal: 10 },
  navTxt: { fontSize: 17, color: '#333' },
  navTitle: { fontSize: 17, fontWeight: '600' },
  debugBtn: { width: 44, height: 44, justifyContent: 'center', alignItems: 'center' },
  debugTxt: { fontSize: 11, color: '#bbb' },
  card: { backgroundColor: '#f4f4f4', borderRadius: 16, padding: 16, marginTop: 20 },
  cardB: { minHeight: 270, marginTop: 0 },
  lbl: { fontSize: 13, color: '#777', lineHeight: 18 },
  sent: { fontSize: 26, fontWeight: '700', lineHeight: 34, color: '#111', marginTop: 8 },
  body: { fontSize: 18, color: '#111', marginTop: 4, lineHeight: 25 },
  h1: { fontSize: 32, fontWeight: '800', color: '#111' },
  h2: { fontSize: 20, fontWeight: '700', marginBottom: 8 },
  hint: { fontSize: 13, color: '#888', marginTop: 'auto', textAlign: 'right', paddingTop: 8 },
  chip: { height: 44, paddingHorizontal: 16, borderRadius: 22, backgroundColor: '#e6e6e6', justifyContent: 'center', alignItems: 'center' },
  chipTxt: { fontSize: 16, color: '#222' },
  pair: { flexDirection: 'row', gap: 12, marginTop: 12 },
  timeMid: { fontSize: 40, fontWeight: '800', textAlign: 'center', marginTop: 8, color: '#111' },
  timeBig: { fontSize: 72, fontWeight: '800', textAlign: 'center', color: '#111', letterSpacing: -1 },
  big: { height: 60, borderRadius: 14, backgroundColor: '#333', justifyContent: 'center', alignItems: 'center' },
  bigTxt: { fontSize: 18, fontWeight: '700', color: '#fff' },
  txtBtn: { height: 44, justifyContent: 'center', paddingHorizontal: 8, alignSelf: 'flex-start' },
  txtBtnTxt: { fontSize: 16, color: '#888' },
  jar: { borderRadius: 12, backgroundColor: '#fafafa', padding: 10, overflow: 'hidden', minHeight: 120 },
  pea: { position: 'absolute', width: 30, height: 30, borderRadius: 15, backgroundColor: '#bbb' },
  pea2: { width: 62 },
  circle: { backgroundColor: '#e9e9e9', justifyContent: 'center', alignItems: 'center' },
  circleTime: { fontSize: 40, fontWeight: '800', color: '#111' },
  circleSub: { fontSize: 17, fontWeight: '700', color: '#111', marginTop: 4 },
  circleTitle: { fontSize: 28, fontWeight: '800', color: '#111' },
  circleTitleSm: { fontSize: 17, fontWeight: '700', color: '#111', textAlign: 'center' },
  input: { backgroundColor: '#f4f4f4', borderRadius: 14, padding: 14, fontSize: 19, lineHeight: 26, color: '#111', marginTop: 10, minHeight: 60 },
  bellHead: { flexDirection: 'row', alignItems: 'flex-start', marginTop: 8 },
  row: { flexDirection: 'row', paddingVertical: 6, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: '#ddd' },
  rowK: { fontSize: 16, color: '#888', marginRight: 10 },
  rowV: { fontSize: 16, color: '#222', flex: 1 },
  listRow: { minHeight: 48, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 6, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: '#ddd' },
  veil: { flex: 1, backgroundColor: 'rgba(0,0,0,0.25)' },
  sheet: { backgroundColor: '#fff', borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 20, paddingBottom: 36 },
  grabber: { width: 36, height: 5, borderRadius: 3, backgroundColor: '#ccc', alignSelf: 'center', marginBottom: 12 },
});
