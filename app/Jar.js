// 豆罐手感原型（候選 1：JS 迴圈＋View）。規格：.uiux/04-手感/原型規格-暫定.md
// 所有數字從 PARAMS 讀（對照 .uiux/04-手感/參數表-暫定.md），畫面裡不寫死。
import React, { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, Modal, Platform, Pressable, SafeAreaView, ScrollView, StyleSheet, Switch, Text, View } from 'react-native';
import Slider from '@react-native-community/slider';
import * as Haptics from 'expo-haptics';
import { DeviceMotion } from 'expo-sensors';
import { createAudioPlayer, setAudioModeAsync } from 'expo-audio';

// ---------- 參數（參數表 A、B 類） ----------
export const PARAMS_DEFAULT = {
  dropDelay: 180,      // ms   按收下到豆開始掉
  dropVy: -160,        // pt/s 掉落初速（負＝先往上拋）
  dropVxSpread: 40,    // pt/s 水平散佈 ±
  gravity: 1100,       // pt/s² 靜置重力
  tiltScale: 115,      // 每 1 m/s² 換多少 pt/s²
  tiltSmooth: 0.15,    // 每幀追上目標的比例（這是延遲）
  tiltFlipY: false,    // 豆子往上飛就打開（平台座標符號）
  radius: 18,          // pt
  link: 32,            // pt 雙豆間距
  airDamp: 0.996,
  wallRest: 0.3,       // 牆面恢復係數
  wallFric: 0.97,
  beanRest: 1.25,      // 豆豆碰撞衝量
  tapRadius: 110,      // pt
  tapUp: 650,          // pt/s
  tapSide: 5,
  hitThreshold: 380,   // pt/s
  hitGapMs: 90,
  hitVolDiv: 5000,
  hitVolMax: 0.1,
  hapticPop: true,
  hapticHit: true,
  substeps: 2,
  iterations: 4,
  dtMax: 0.033,
  maxBeans: 40,
  settleSteps: 360,
};
// 2 號參數組（盲測第一輪：牆面恢復係數）
const SET2 = { wallRest: 0.45 };

const SLIDERS = [
  ['dropDelay', '掉豆延遲 ms', 0, 600, 10],
  ['gravity', '重力', 300, 2500, 50],
  ['tiltScale', '傾斜換算', 0, 300, 5],
  ['tiltSmooth', '傾斜平滑（延遲）', 0.02, 1, 0.01],
  ['wallRest', '牆面恢復係數', 0, 1, 0.05],
  ['wallFric', '牆面摩擦', 0.8, 1, 0.005],
  ['beanRest', '豆豆碰撞衝量', 0.5, 2, 0.05],
  ['airDamp', '空氣阻尼', 0.98, 1, 0.001],
  ['tapRadius', '點彈影響半徑', 40, 220, 5],
  ['tapUp', '點彈向上衝量', 0, 1500, 25],
  ['hitThreshold', '碰撞聲門檻', 100, 800, 10],
  ['hitGapMs', '碰撞聲間隔 ms', 30, 300, 10],
];

// ---------- 音效（參數表 A 入罐音、B 碰撞音） ----------
const SFX = {
  pop: require('./assets/sfx/pop.wav'),
  hits: [require('./assets/sfx/hit260.wav'), require('./assets/sfx/hit290.wav'), require('./assets/sfx/hit320.wav'), require('./assets/sfx/hit350.wav')],
};

function makeAudio() {
  try {
    setAudioModeAsync({ playsInSilentMode: false }).catch(() => {});
    const pop = createAudioPlayer(SFX.pop);
    const hits = SFX.hits.map((s) => createAudioPlayer(s));
    return {
      pop() { try { pop.seekTo(0); pop.play(); } catch (e) {} },
      hit(vol) { try { const p = hits[Math.floor(Math.random() * hits.length)]; p.volume = vol; p.seekTo(0); p.play(); } catch (e) {} },
      release() { try { pop.remove(); hits.forEach((p) => p.remove()); } catch (e) {} },
    };
  } catch (e) {
    return { pop() {}, hit() {}, release() {} };
  }
}

// ---------- 物理（從 index.html 原型移植） ----------
function makeWorld(P) {
  return { P, bodies: [], links: [], w: 0, h: 0, gx: 0, gy: P.gravity, tgx: 0, tgy: P.gravity, impact: 0, lastHit: 0, landed: [], reduce: false };
}
function addBody(W, two, x, y, vx = 0, vy = 0, fresh = false) {
  const L = W.P.link;
  if (!two) W.bodies.push({ x, y, vx, vy, single: true, fresh, id: Math.random() });
  else {
    const a = { x: x - L / 2, y, vx, vy, fresh, id: Math.random() }, b = { x: x + L / 2, y, vx, vy, id: Math.random() };
    a.mate = b; b.mate = a; W.bodies.push(a, b); W.links.push({ a, b, id: Math.random() });
  }
}
const count = (W) => W.bodies.filter((b) => b.single).length + W.links.length; // 顆數：單豆＋雙豆各算一顆
function step(W, dt) {
  const { P, w, h } = W, R = P.radius, B = W.bodies, gx = W.gx, gy = W.gy;
  for (const b of B) { b.vx += gx * dt; b.vy += gy * dt; b.vx *= P.airDamp; b.vy *= P.airDamp; b.x += b.vx * dt; b.y += b.vy * dt; }
  for (let it = 0; it < P.iterations; it++) {
    for (const L of W.links) {
      const dx = L.b.x - L.a.x, dy = L.b.y - L.a.y, d = Math.hypot(dx, dy) || 1, k = (d - P.link) / d / 2;
      L.a.x += dx * k; L.a.y += dy * k; L.b.x -= dx * k; L.b.y -= dy * k;
      const mvx = (L.a.vx + L.b.vx) / 2, mvy = (L.a.vy + L.b.vy) / 2;
      L.a.vx += (mvx - L.a.vx) * 0.3; L.b.vx += (mvx - L.b.vx) * 0.3; L.a.vy += (mvy - L.a.vy) * 0.3; L.b.vy += (mvy - L.b.vy) * 0.3;
    }
    for (let i = 0; i < B.length; i++) for (let j = i + 1; j < B.length; j++) {
      const a = B[i], b = B[j]; if (a.mate === b) continue;
      const dx = b.x - a.x, dy = b.y - a.y, d2 = dx * dx + dy * dy, m = 2 * R;
      if (d2 < m * m && d2 > 1e-4) {
        const d = Math.sqrt(d2), nx = dx / d, ny = dy / d, o = (m - d) / 2;
        a.x -= nx * o; a.y -= ny * o; b.x += nx * o; b.y += ny * o;
        const rv = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (rv < 0) { const jj = -P.beanRest * rv / 2; a.vx -= jj * nx; a.vy -= jj * ny; b.vx += jj * nx; b.vy += jj * ny; if (-rv > W.impact) W.impact = -rv; }
      }
    }
    for (const b of B) {
      if (b.x < R) { b.x = R; if (b.vx < 0) { if (-b.vx > W.impact) W.impact = -b.vx; b.vx = -b.vx * P.wallRest; } b.vy *= P.wallFric; }
      if (b.x > w - R) { b.x = w - R; if (b.vx > 0) { if (b.vx > W.impact) W.impact = b.vx; b.vx = -b.vx * P.wallRest; } b.vy *= P.wallFric; }
      if (b.y > h - R) { b.y = h - R; if (b.vy > 0) { if (b.vy > W.impact) W.impact = b.vy; if (b.fresh) { b.fresh = false; W.landed.push(b); } b.vy = -b.vy * P.wallRest; } b.vx *= P.wallFric; }
      if (b.y < R && !b.fresh) { b.y = R; if (b.vy < 0) b.vy = -b.vy * P.wallRest; }
    }
  }
}

// ---------- 畫面 ----------
export default function Jar({ onClose, beans = 5 }) {
  const [P, setP] = useState({ ...PARAMS_DEFAULT });
  const [set2, setSet2] = useState(false);
  const [panel, setPanel] = useState(false);
  const [, setTick] = useState(0);
  const [info, setInfo] = useState({ fps: 0, tilt: '未啟動', n: 0 });
  const W = useRef(makeWorld(PARAMS_DEFAULT)).current;
  const audio = useRef(null);
  const box = useRef(null);
  const frames = useRef({ n: 0, t: 0 });

  const live = set2 ? { ...P, ...SET2 } : P;
  W.P = live;

  // 重設豆子（開機安置：預跑 settleSteps）
  const rebuild = (n) => {
    W.bodies = []; W.links = []; W.landed = [];
    if (!W.w) return;
    const R = live.radius;
    for (let i = 0; i < Math.min(n, live.maxBeans); i++) {
      const two = i % 4 === 3;
      addBody(W, two, R + live.link / 2 + Math.random() * (W.w - 2 * R - live.link), R + Math.random() * (W.h - 2 * R));
    }
    const g = [W.gx, W.gy]; W.gx = 0; W.gy = live.gravity;
    for (let i = 0; i < live.settleSteps; i++) step(W, 1 / 60);
    W.gx = g[0]; W.gy = g[1]; W.landed = [];
    setInfo((s) => ({ ...s, n: count(W) }));
  };

  // 掉一顆（A 類：視聽觸同一事件，在落地那一幀）
  const drop = (two) => {
    if (W.bodies.length >= live.maxBeans) return;
    const go = () => {
      if (W.reduce) { addBody(W, two, W.w / 2 + (Math.random() - 0.5) * 60, W.h - live.radius, 0, 0, false); audio.current?.pop(); if (live.hapticPop) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Rigid).catch(() => {}); }
      else addBody(W, two, W.w / 2 + (Math.random() - 0.5) * 60, -live.radius * 2, (Math.random() - 0.5) * 2 * live.dropVxSpread, live.dropVy, true);
      setInfo((s) => ({ ...s, n: count(W) }));
    };
    setTimeout(go, W.reduce ? 0 : live.dropDelay);
  };

  // 點一下彈
  const tap = (e) => {
    if (W.reduce) return;
    const { locationX: x, locationY: y } = e.nativeEvent;
    for (const b of W.bodies) { const d = Math.hypot(b.x - x, b.y - y); if (d < live.tapRadius) { const k = 1 - d / live.tapRadius; b.vy -= live.tapUp * k; b.vx += (b.x - x) * live.tapSide * k; } }
  };

  useEffect(() => {
    audio.current = makeAudio();
    AccessibilityInfo.isReduceMotionEnabled().then((r) => { W.reduce = !!r; }).catch(() => {});
    let sub = null;
    DeviceMotion.isAvailableAsync().then((ok) => {
      if (!ok) { setInfo((s) => ({ ...s, tilt: '此裝置無加速度計' })); return; }
      DeviceMotion.setUpdateInterval(16);
      sub = DeviceMotion.addListener(({ accelerationIncludingGravity: a }) => {
        if (!a || a.x == null || W.reduce) return;
        const s = W.P.tiltFlipY ? -1 : 1;
        W.tgx = a.x * s * W.P.tiltScale; W.tgy = -a.y * s * W.P.tiltScale;
      });
      setInfo((s) => ({ ...s, tilt: '傾斜中' }));
    }).catch(() => setInfo((s) => ({ ...s, tilt: '加速度計錯誤' })));

    let raf, last = 0, run = true;
    const loop = (t) => {
      if (!run) return;
      const dt = last ? Math.min(W.P.dtMax, (t - last) / 1000) : 0.016; last = t;
      W.gx += (W.tgx - W.gx) * W.P.tiltSmooth; W.gy += (W.tgy - W.gy) * W.P.tiltSmooth;
      W.impact = 0;
      for (let i = 0; i < W.P.substeps; i++) step(W, dt / W.P.substeps);
      // 落地：啵＋觸覺（同一事件）
      if (W.landed.length) { W.landed = []; audio.current?.pop(); if (W.P.hapticPop) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Rigid).catch(() => {}); }
      // 碰撞：聲＋觸覺（門檻、間隔）
      if (W.impact > W.P.hitThreshold && t - W.lastHit > W.P.hitGapMs) {
        W.lastHit = t; audio.current?.hit(Math.min(W.P.hitVolMax, W.impact / W.P.hitVolDiv));
        if (W.P.hapticHit) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
      }
      // fps 粗估（每秒更新一次）
      frames.current.n++; if (t - frames.current.t > 1000) { setInfo((s) => ({ ...s, fps: frames.current.n })); frames.current.n = 0; frames.current.t = t; }
      setTick((k) => k + 1);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => { run = false; cancelAnimationFrame(raf); sub && sub.remove(); audio.current?.release(); };
  }, []);

  const onLayout = (e) => { const { width, height } = e.nativeEvent.layout; const first = !W.w; W.w = width; W.h = height; if (first) rebuild(beans); };
  const R = live.radius;

  return (
    <SafeAreaView style={st.safe}>
      <View style={st.top}>
        <Pressable onPress={onClose} style={st.navBtn}><Text style={st.navTxt}>‹ 返回</Text></Pressable>
        <Pressable onLongPress={() => setPanel(true)} delayLongPress={1000} style={st.title}><Text style={st.titleTxt}>豆罐原型</Text></Pressable>
        <View style={st.navBtn} />
      </View>
      <Text style={st.lbl} accessibilityLabel={`今天 ${info.n} 顆豆`}>今天 {info.n} 顆豆　{info.fps} fps　{info.tilt}　{set2 ? '2 號' : '1 號'}{W.reduce ? '　減少動態' : ''}</Text>
      <Pressable style={st.jar} onLayout={onLayout} onPress={tap} accessibilityRole="button" accessibilityLabel="豆罐，點一下彈一下">
        {W.bodies.filter((b) => b.single).map((b) => <View key={b.id} style={[st.pea, { width: R * 2, height: R * 2, borderRadius: R, transform: [{ translateX: b.x - R }, { translateY: b.y - R }] }]} />)}
        {W.links.map((L) => { const cx = (L.a.x + L.b.x) / 2, cy = (L.a.y + L.b.y) / 2, ang = Math.atan2(L.b.y - L.a.y, L.b.x - L.a.x); const w = live.link + R * 2;
          return <View key={L.id} style={[st.pea, { width: w, height: R * 2, borderRadius: R, transform: [{ translateX: cx - w / 2 }, { translateY: cy - R }, { rotate: `${ang}rad` }] }]} />; })}
      </Pressable>
      <View style={st.row}>
        <Pressable style={st.big} onPress={() => drop(false)}><Text style={st.bigTxt}>收下這顆（掉一顆）</Text></Pressable>
        <Pressable style={[st.big, { flex: 0.6, backgroundColor: '#777' }]} onPress={() => drop(true)}><Text style={st.bigTxt}>雙豆</Text></Pressable>
      </View>
      <Text style={st.hint}>長按標題 1 秒開調整面板。傾斜手機豆子會滾，點罐子會彈。</Text>

      {panel ? (
        <Modal visible transparent animationType="slide" onRequestClose={() => setPanel(false)}>
          <Pressable style={st.veil} onPress={() => setPanel(false)} />
          <View style={st.sheet}>
            <ScrollView style={{ maxHeight: 520 }}>
              <Text style={st.h2}>調整面板（測試者看不到）</Text>
              <View style={st.row}>
                {[['清空', () => rebuild(0)], ['5 顆', () => rebuild(5)], ['40 顆', () => rebuild(40)]].map(([l, f]) => <Pressable key={l} style={st.small} onPress={f}><Text style={st.smallTxt}>{l}</Text></Pressable>)}
              </View>
              <View style={st.prow}><Text style={st.plbl}>2 號參數組（牆面恢復 {SET2.wallRest}）</Text><Switch value={set2} onValueChange={setSet2} /></View>
              <View style={st.prow}><Text style={st.plbl}>反轉傾斜方向</Text><Switch value={P.tiltFlipY} onValueChange={(v) => setP({ ...P, tiltFlipY: v })} /></View>
              <View style={st.prow}><Text style={st.plbl}>入罐觸覺 Rigid</Text><Switch value={P.hapticPop} onValueChange={(v) => setP({ ...P, hapticPop: v })} /></View>
              <View style={st.prow}><Text style={st.plbl}>碰撞觸覺 Light</Text><Switch value={P.hapticHit} onValueChange={(v) => setP({ ...P, hapticHit: v })} /></View>
              {SLIDERS.map(([k, label, min, max, stp]) => (
                <View key={k} style={{ marginTop: 8 }}>
                  <Text style={st.plbl}>{label}：{Number(P[k]).toFixed(stp < 1 ? 3 : 0)}</Text>
                  <Slider minimumValue={min} maximumValue={max} step={stp} value={P[k]} onValueChange={(v) => setP((p) => ({ ...p, [k]: v }))} minimumTrackTintColor="#333" maximumTrackTintColor="#ccc" />
                </View>
              ))}
              <Pressable style={[st.small, { marginTop: 12 }]} onPress={() => setP({ ...PARAMS_DEFAULT })}><Text style={st.smallTxt}>全部回到參數表初值</Text></Pressable>
              <Text style={[st.hint, { marginTop: 8 }]}>{Platform.OS} {Platform.Version}　罐 {Math.round(W.w)}×{Math.round(W.h)} pt</Text>
            </ScrollView>
          </View>
        </Modal>
      ) : null}
    </SafeAreaView>
  );
}

const st = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#fff' },
  top: { height: 44, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 8, marginTop: 8 },
  navBtn: { minWidth: 60, height: 44, justifyContent: 'center', paddingHorizontal: 10 },
  navTxt: { fontSize: 17, color: '#333' },
  title: { height: 44, justifyContent: 'center', paddingHorizontal: 16 },
  titleTxt: { fontSize: 17, fontWeight: '600' },
  lbl: { fontSize: 13, color: '#777', textAlign: 'center', marginTop: 4 },
  jar: { flex: 1, marginHorizontal: 16, marginTop: 12, marginBottom: 12, borderRadius: 12, backgroundColor: '#fafafa', borderWidth: 1, borderColor: '#ddd', overflow: 'hidden' },
  pea: { position: 'absolute', left: 0, top: 0, backgroundColor: '#bbb' },
  row: { flexDirection: 'row', gap: 12, marginHorizontal: 20 },
  big: { flex: 1, height: 60, borderRadius: 14, backgroundColor: '#333', justifyContent: 'center', alignItems: 'center' },
  bigTxt: { fontSize: 17, fontWeight: '700', color: '#fff' },
  hint: { fontSize: 12, color: '#999', textAlign: 'center', marginVertical: 10, paddingHorizontal: 20 },
  veil: { flex: 1, backgroundColor: 'rgba(0,0,0,0.25)' },
  sheet: { backgroundColor: '#fff', borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 20, paddingBottom: 36 },
  h2: { fontSize: 18, fontWeight: '700', marginBottom: 8 },
  prow: { minHeight: 44, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  plbl: { fontSize: 15, color: '#222' },
  small: { flex: 1, height: 44, borderRadius: 10, backgroundColor: '#bbb', justifyContent: 'center', alignItems: 'center' },
  smallTxt: { fontSize: 15, fontWeight: '600', color: '#111' },
});
