// 豆帳 設計代號（v0.1 暫定）。畫面程式只准用 Token.*，不准寫色碼、字級、間距、動畫數字。
// 兩層：palette＝原始值，只在這裡；Token＝語意層，依用途命名。
// 來源：.uiux/03-線框（版面尺寸）、.uiux/04-手感/參數表-暫定.md（動態與觸覺）、index.html 原型（色票）。
// 對比：見 對比檢查表-暫定.md；改任何顏色後整表重跑。
import {
  AccessibilityInfo,
  PixelRatio,
  Platform,
  PlatformColor,
  useColorScheme,
} from 'react-native';
import { useEffect, useState } from 'react';

// ---------- 原始值層（只在此處）。每色四組：淺／深／增加對比淺／增加對比深 ----------
const palette = {
  // 自訂的只有四個用途；其餘走系統色
  // 2026-11-01 重新設計 R5：主要按鈕與強調文字從豌豆時代的綠改成墨色，畫面上只有番茄有顏色（綠只剩葉子）
  ink: { light: '#1C1C1E', dark: '#F2F2F7', hcLight: '#000000', hcDark: '#FFFFFF' }, // 主要按鈕底、強調文字
  red: { light: '#C8102E', dark: '#FF453A', hcLight: '#A3000F', hcDark: '#FF6961' }, // 危險文字，淺色模式比原型 #FF3B30 深
  grey2: { light: '#66666B', dark: '#98989F', hcLight: '#5C5C62', hcDark: '#BABAC0' }, // 次要文字（系統 secondaryLabel 淺色不過 4.5）
  onInk: { light: '#FFFFFF', dark: '#000000', hcLight: '#FFFFFF', hcDark: '#000000' }, // 墨色按鈕上的字
  // 固定值（對比表用，畫面不直接拿）
  bgLight: '#F2F2F7',
  bgDark: '#000000',
  cardLight: '#FFFFFF',
  cardDark: '#1C1C1E',
};

// 角色色：另外放，不進介面語意層。只准畫番茄、番茄串、葉子；不當文字色、不當按鈕色。
// 2026-11-01 多米：番茄串的小圓點改番茄紅（取自番茄圖平均色 #CB4B34 附近，淺深各調到在卡片底上 ≥ 3:1）；葉子維持原本的綠。
export const CharacterColors = {
  pod: { light: '#E5553C', dark: '#D94C34' }, // 白卡 3.69:1、深卡 4.08:1
  podShade: { light: '#B83A26', dark: '#F07A62' }, // 作廢空心圈的框：白卡 5.72:1、深卡 6.21:1
  leaf: { light: '#BFE0A3', dark: '#7FA86A' }, // 原本的豆綠，留給葉子
  // 番茄本身用插圖 img/tomato.webp、tomato2.webp（2026-11-01 多米給，原本是豌豆 pea.webp），不是純色
};

// ---------- 系統語意色（iOS 由 UIKit 處理深色與增加對比） ----------
const sys = (ios, fallback) => (Platform.OS === 'ios' ? PlatformColor(ios) : fallback);

// ---------- 模式解析 ----------
const pick = (c, dark, hc) => (hc ? (dark ? c.hcDark : c.hcLight) : dark ? c.dark : c.light);

/** 在元件裡用：const T = useTokens(); 然後 T.color.accent …  */
export function useTokens() {
  const dark = useColorScheme() === 'dark';
  const [hc, setHc] = useState(false);
  useEffect(() => {
    let on = true;
    // RN 0.88 有 isDarkerSystemColorsEnabled（iOS「增加對比」）；查證 2026-10-31 於安裝的 react-native 型別檔
    AccessibilityInfo.isDarkerSystemColorsEnabled?.()
      .then((v) => on && setHc(!!v))
      .catch(() => {});
    const sub = AccessibilityInfo.addEventListener?.('darkerSystemColorsChanged', (v) =>
      setHc(!!v),
    );
    return () => {
      on = false;
      sub?.remove?.();
    };
  }, []);
  return makeTokens(dark, hc);
}

export function makeTokens(dark = false, hc = false) {
  const p = (c) => pick(c, dark, hc);
  return {
    color: {
      // 系統色（iOS 原生語意色，Android／web 退回固定值）
      background: sys('systemGroupedBackground', dark ? palette.bgDark : palette.bgLight),
      card: sys('secondarySystemGroupedBackground', dark ? palette.cardDark : palette.cardLight),
      textPrimary: sys('label', dark ? '#FFFFFF' : '#000000'),
      separator: sys('separator', dark ? '#545458' : '#C6C6C8'),
      fillButton: sys('systemFill', dark ? '#2C2C2E' : '#E3E3E8'), // 第二顆按鈕、chip、分段
      // 自訂（有對比表）
      textSecondary: p(palette.grey2), // 小標、副標、收據時間、placeholder 也用這個（tertiary 不過對比）
      accent: p(palette.ink), // 主要按鈕底：每個畫面只出現一次
      onAccent: p(palette.onInk), // 主要按鈕上的字
      accentText: p(palette.ink), // 可點的強調文字（「加一種」「收工」「連結」）；沒有色相，靠 bodyStrong 的字重分出可點
      danger: p(palette.red), // 清空所有資料、錯誤字
    },
    // 文字：基準字級對應 iOS 系統文字樣式（largeTitle 34／title1 28／title2 22／body 17／callout 16／subheadline 15／footnote 13）
    // RN Text 預設跟系統字級縮放；不准 allowFontScaling={false}
    font: {
      largeTitle: { fontSize: 34, fontWeight: '700' }, // 頁面大標（原型 h1）
      title: { fontSize: 28, fontWeight: '800' }, // 鈴響「響了。」
      hero: { fontSize: 28, fontWeight: '600', lineHeight: 38 }, // 待機卡片裡那句：全頁最大的字（2026-11-01 重新設計 R2）
      sentence: { fontSize: 22, fontWeight: '500', lineHeight: 32 }, // 鈴響與收工的輸入框（原型 .card .txt 22）
      section: { fontSize: 22, fontWeight: '700' }, // 豆棚週標題、半頁標題
      body: { fontSize: 17 },
      bodyStrong: { fontSize: 17, fontWeight: '600' }, // 文字鈕（強調色沒有色相後靠字重）、鈴響問句
      callout: { fontSize: 16 },
      sub: { fontSize: 15 }, // 列副標、chip、hint 連結
      chip: { fontSize: 15, fontWeight: '600' }, // 類型 chip（原型 .chip 15/600）
      caption: { fontSize: 13 }, // 小標 cap、foot-note、卡片標籤
      clock: {
        fontSize: 92,
        fontWeight: '700',
        fontVariant: ['tabular-nums'],
        maxFontSizeMultiplier: 1.6,
      }, // 待機大時間；圓體要放字型檔，暫用系統字
      clockFocus: {
        fontSize: 72,
        fontWeight: '800',
        fontVariant: ['tabular-nums'],
        maxFontSizeMultiplier: 1.6,
      },
      button: { fontSize: 19, fontWeight: '700' }, // 主要按鈕（算大字，門檻 3:1）
      button2: { fontSize: 17, fontWeight: '600' },
    },
    // 間距：五個刻度，從線框與灰盒子量出的 4／8／10／12／14／16／18／20／22／26／34 合併
    space: { xs: 4, s: 8, m: 12, l: 20, xl: 32 },
    /** 靠近文字的間距乘這個，最大字級時才不會擠（ScaledMetric 的對應） */
    fontScale: () => PixelRatio.getFontScale(),
    // 按鈕狀態的不透明度：停用與按下。數字只在這裡
    opacity: { disabled: 0.4, pressed: 0.85 },
    shape: {
      radiusCard: 16,
      radiusButton: 14,
      radiusPill: 999,
      radiusSheet: 20,
      tapMin: 44,
      tapPrimary: 60,
      beanRadius: 18, // 參數表 B
      podDot: 12, // 豆棚上的小豆（原型 .p 13px，取 space 刻度附近的整數；2026-11-01 E1 加）
      hairline: 1, // 列與列的分隔線（系統慣例 1pt；第四處用到時收進來，B+C 審查員）
      rackDayCol: 90, // 豆棚每列左邊「N月D日／星期X」那欄寬（原來寫成 tapPrimary×1.5，D+E 審查員）
      sheetScrollMax: 420, // 收據半頁可捲區最高（原來寫成 tapPrimary×7）
      leafTilt: '-30deg', // 葉子斜放的角度（原型 .leaf）
      pageDot: 8, // 頁碼小圓點（PWA .dots 8px；2026-11-01 左右滑三頁）
      pageDotActive: 22, // 目前那頁的長膠囊（PWA .dots .on 22px）
    },
    // 動態：事件命名，數字只從參數表抄。每個都有減少動態版（替換，不是關掉）
    motion: {
      beanDrop: { delayMs: 180, vy: -160, vxSpread: 40 }, // 收下這顆 → 豆子掉進來
      beanDropReduced: { delayMs: 0, fadeMs: 200 }, // 淡入在罐底
      beanTap: { radius: 110, up: 650, side: 5 }, // 點一下彈
      beanTapReduced: { flashMs: 150 }, // 被點的豆亮一下
      jarPhysics: {
        gravity: 1100,
        tiltScale: 115,
        tiltSmooth: 0.15,
        airDamp: 0.996,
        wallRest: 0.3,
        wallFric: 0.97,
        beanRest: 1.25,
        substeps: 2,
        iterations: 4,
        dtMax: 0.033,
        maxBeans: 40,
        settleSteps: 360,
      },
      jarPhysicsReduced: { tilt: false }, // 豆子靜止排在底部
      sheetIn: { durationMs: 280, fromY: 60 }, // 半頁滑入（原型 .sheet）
      sheetInReduced: { durationMs: 150, fromY: 0 }, // 只淡入
      cardPress: { scale: 0.985, durationMs: 150 }, // 按下卡片
      cardPressReduced: { scale: 1, durationMs: 0 },
      pageSwitch: { durationMs: 380 }, // 原型左右滑的時長；導覽改按鈕後若用推進，交系統動畫
    },
    // 觸覺：事件命名，一事件一觸覺。expo-haptics API 查證 2026-10-31
    haptic: {
      beanLand: 'impact.rigid', // 豆子落地那一幀
      beanHit: 'impact.light', // 碰撞超過門檻，最短間隔 90 ms
      wipeDone: 'notification.success', // 清空、匯入完成（系統事件用系統觸覺）
      importFail: 'notification.error',
      select: 'selection', // 換類型、分段切換
    },
    sound: {
      pop: 'assets/sfx/pop.wav', // 入罐
      hit: [
        'assets/sfx/hit260.wav',
        'assets/sfx/hit290.wav',
        'assets/sfx/hit320.wav',
        'assets/sfx/hit350.wav',
      ],
      hitThreshold: 380,
      hitGapMs: 90,
      hitVolDiv: 5000,
      hitVolMax: 0.1,
      chime: { hz: [784, 1175], sec: 1.6 }, // 鈴聲，原生版改本地通知音檔
    },
    _palette: palette, // 只給對比腳本與測試讀，畫面不准用
    _dark: dark,
    _hc: hc, // 目前解析到的模式，除錯頁顯示用
  };
}

export const Token = makeTokens(false, false); // 無 hook 情境（例如純函式）用；元件裡請用 useTokens()
