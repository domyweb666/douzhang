// 豆帳 設計代號。畫面程式只准用 useTokens() 拿到的 T.*，不准寫色碼、字級、間距、動畫數字。
// 2026-11-14 多米：照 Domy Design System（E:\domy-design，套件 @domy/design）重新設計全部 UI。
// 顏色、字級、間距、圓角、按鈕與列的尺寸全部從 @domy/design 推出來（產品色在 design/theme.js）；
// 這個檔只留豆帳自己才有的：番茄與葉子的角色色、大時間、時間軸與罐子的尺寸、動態、觸覺、音效。
// 鍵名沿用舊版，畫面不用跟著改名；新畫面優先直接用 @domy/design 的元件。
import { PixelRatio } from 'react-native';
import { T as D, typeStyle, useDomy } from '@domy/design';
import { douzhangTheme } from './theme';

// 角色色：另外放，不進介面語意層。只准畫番茄、番茄串、葉子；不當文字色、不當按鈕色。
// 2026-11-01 多米：番茄串的小圓點改番茄紅（取自番茄圖平均色 #CB4B34 附近，淺深各調到在卡片底上 ≥ 3:1）；葉子維持原本的綠。
export const CharacterColors = {
  pod: { light: '#E5553C', dark: '#D94C34' }, // 白卡 3.69:1、深卡 4.08:1
  podShade: { light: '#B83A26', dark: '#F07A62' }, // 作廢空心圈的框：白卡 5.72:1、深卡 6.21:1
  leaf: { light: '#BFE0A3', dark: '#7FA86A' }, // 原本的豆綠，留給葉子
  podSoft: { light: '#FBE3DE', dark: '#4A2620' }, // 番茄架時間軸上一顆番茄的底（U9）；上面的主要文字淺 14.25、深 11.59，次要文字 4.82／5.33
  // 番茄本身（2026-11-16 多米看比較頁選 B「描邊表情」，取代 11-02 的扁平番茄圖）：ui/Tomato.js 用 SVG 畫，
  // 大小跟分鐘走（V4），身體色跟類型（W1）。五個身體色是比較頁上那一組，淺深色同一組。
  tomato: {
    body: {
      red: '#E4472F',
      orange: '#F0892B',
      yellow: '#F2BC2F',
      purple: '#8C5BA9',
      pink: '#EE7E9D',
    },
    // 番茄架實心方塊上的字（2026-11-17 AG4，比較頁 3A）：紅、紫底用白字（4.0、5.3:1），橘、黃、粉底用墨色（6.2、9.0、5.9:1）
    onBody: {
      red: '#FFFFFF',
      orange: '#2B2329',
      yellow: '#2B2329',
      purple: '#FFFFFF',
      pink: '#2B2329',
    },
    unripe: '#9CC25A', // 計時中還沒熟的青番茄（2026-11-17 AG2）；2026-11-18 AH1 起直接變成標籤色，不經過黃
    vine: '#4E8B3A', // 掛著它的那段藤
    leaf: '#6FAE52',
    ink: '#2B2329', // 外框、蒂、眼睛、嘴
    shine: '#FFFFFF', // 左上那道亮面與兩頰，透明度是圖的一部分，在 ui/Tomato.js
  },
  // 番茄火柴人（2026-11-15 Y1）的頭套色已刪：2026-11-18 AH4 多米「火柴人整個拿掉」
};

/** 在元件裡用：const T = useTokens(); 然後 T.color.accent …（要在 DomyThemeProvider 裡面） */
export function useTokens() {
  const { c, scheme, reduceMotion } = useDomy();
  return makeTokens(c, scheme === 'dark', reduceMotion);
}

// 中文多行時 Domy 的大字行高偏緊：那句與輸入框各多一格間距的行高
const roomy = (variant, weight) => ({
  ...typeStyle(variant),
  fontWeight: weight,
  lineHeight: D.type[variant].size + D.space[3],
});

export function makeTokens(c, dark = false, reduceMotion = false) {
  return {
    color: {
      background: c.canvas,
      card: c.surface,
      textPrimary: c.textPrimary,
      textSecondary: c.textSecondary, // 小標、副標、收據時間、placeholder
      textTertiary: c.textTertiary, // 箭頭
      separator: c.separator,
      fieldBorder: c.fieldBorder,
      fillButton: c.surfaceMuted, // 第二顆按鈕、chip
      accent: c.accent, // 主要按鈕底：每個畫面只出現一次
      onAccent: c.onAccent,
      accentText: c.strong, // 可點的強調文字、選中的字
      soft: c.soft, // 選中的分頁、選項膠囊、選中的那天
      tint: c.tint, // 淡底小卡
      danger: c.destructive, // 清空所有資料、錯誤字
      dangerSoft: c.destructiveSoft,
      disabledText: c.textDisabled,
      shadow: c.shadow, // 半頁後面的遮罩
      // 聚焦模式（2026-11-17）：橫放的整頁時鐘，淺色深色都是同一組黑底。
      // 牌上的數字對牌 15.2:1、那句對黑底 6.4:1、鈕上的字對鈕 12.5:1
      zen: {
        background: '#000000',
        card: '#1C1C1E', // 翻牌的牌
        digit: '#F2F2F4', // 牌上的數字、鈕上的字
        dim: '#8E8E93', // 冒號兩點、下面那句
        pill: '#2C2C2E', // 點一下才出現的三顆鈕
      },
    },
    // 文字：全部是 Domy 的字級（iOS 系統文字樣式）。RN Text 預設跟系統字級縮放；不准 allowFontScaling={false}
    font: {
      largeTitle: typeStyle('largeTitle'), // 番茄架、設定的頁標
      title: typeStyle('title1'), // 鈴響「響了。」
      hero: roomy('title1', '600'), // 待機卡片裡那句：全頁最大的字
      sentence: roomy('title3', '400'), // 鈴響與收工的輸入框
      section: typeStyle('title2'), // 半頁標題
      title3: typeStyle('title3'), // 區塊標題（同 DomySection）
      body: typeStyle('body'),
      bodyStrong: typeStyle('headline'), // 文字鈕、鈴響問句
      callout: typeStyle('callout'),
      sub: typeStyle('subheadline'),
      chip: { ...typeStyle('subheadline'), fontWeight: '600' },
      caption: typeStyle('footnote'),
      tab: typeStyle('caption'),
      // 大時間是豆帳自己的（Domy 沒有）。數字等寬，字級上限 1.6 倍
      clock: {
        fontSize: 92,
        fontWeight: '700',
        fontVariant: ['tabular-nums'],
        maxFontSizeMultiplier: 1.6,
      },
      clockFocus: {
        fontSize: 72,
        fontWeight: '700',
        fontVariant: ['tabular-nums'],
        maxFontSizeMultiplier: 1.6,
      },
      // 進度環下面的時間（2026-11-18 AH2）：環已經是主角，時間比待機的大時間小一階
      clockRing: {
        fontSize: 56,
        fontWeight: '700',
        fontVariant: ['tabular-nums'],
        maxFontSizeMultiplier: 1.4,
      },
      // 聚焦模式牌上的數字：大小跟著畫面寬（params.zen.digitSize），不跟系統字級放大，不然會撐出牌子
      zenDigit: { fontWeight: '800', fontVariant: ['tabular-nums'], maxFontSizeMultiplier: 1 },
      button: typeStyle('headline'), // 主要按鈕（同 DomyButton regular）
      button2: typeStyle('headline'),
    },
    // 間距：Domy 的刻度，舊鍵名對上 4／8／12／20／32
    space: {
      xs: D.space[1],
      s: D.space[2],
      m: D.space[3],
      card: D.space[4], // 卡片、列的左右內距（同 DomySection）
      l: D.space[5],
      section: D.space[6], // 區塊之間（同 DomyScreen 的 gap）
      xl: D.space[8],
      screen: D.size.screenMargin,
    },
    /** 靠近文字的間距乘這個，最大字級時才不會擠（ScaledMetric 的對應） */
    fontScale: () => PixelRatio.getFontScale(),
    // 停用改用顏色（同 DomyButton），按下照 Domy：縮一點，減少動態時變淡
    opacity: { disabled: D.motion.pressedOpacity, pressed: D.motion.pressedOpacity, scrim: 0.32 },
    press: { scale: D.motion.pressScale, durationMs: D.motion.pressDuration },
    reduceMotion,
    shape: {
      radiusCard: D.radius.xl, // 卡片、分組（同 DomySection）
      radiusButton: D.radius.md, // 輸入框、時間軸方塊、小卡
      radiusPill: D.radius.pill, // 按鈕、膠囊
      radiusSheet: D.radius['2xl'],
      tapMin: D.size.touch,
      tapPrimary: D.size.button, // 主要按鈕高
      buttonCompact: D.size.buttonCompact,
      row: D.size.row, // 列高
      field: D.size.field,
      pickerHeight: D.size.pickerHeight,
      hairline: D.size.hairline,
      grabber: { width: D.space[8] + D.space[1], height: D.space[1] + 1 }, // 半頁上緣的小把手（iOS 36×5）
      beanRadius: 28, // 25 分那顆的半徑（參數表 B 原 18；2026-11-02 W2 多米嫌小，直徑 56）
      podDot: 12, // 豆棚上的小豆（原型 .p 13px，取 space 刻度附近的整數；2026-11-01 E1 加）
      rackDayCol: 90, // 豆棚每列左邊「N月D日／星期X」那欄寬（原來寫成 tapPrimary×1.5，D+E 審查員）
      sheetScrollMax: 420, // 收據半頁可捲區最高（原來寫成 tapPrimary×7）
      leafTilt: '-30deg', // 葉子斜放的角度（原型 .leaf）
      pileRoom: 140, // 主畫面開始鈕下面留給番茄堆的高度（W3 全版面：番茄堆在最下面，鈕在它上方）
      // 番茄架時間軸（2026-11-02 U9，示意圖量的）
      timelineHour: 64, // 一小時多高
      timelineGutter: 52, // 左邊時刻那欄寬
      timelineBlockMin: 28, // 一顆再短也至少這麼高，字才放得下
      timelineEdge: 4, // 每顆左邊那條番茄色的邊（AG4 改實心色塊後只剩收據用）
      // 番茄架改版（2026-11-17 AG4，比較頁 3A）：天／3 天／週共用時間軸，月是一格一天
      timelineBlockMinWeek: 8, // 週檢視沒有字，一顆最矮畫這麼高
      timelineTextMin: 18, // 方塊不到這麼高就不寫字
      timelineNoteMin: 44, // 方塊至少這麼高才多寫一行那句
      timelineLaneGap: 2, // 並排與上下相鄰的方塊之間留的縫
      nowLine: 2, // 今天那欄標出現在時間的橫線
      monthDot: 10, // 月檢視一顆番茄的小圓點
      monthWeek: 60, // 有番茄的週一列多高
      monthWeekFlat: 30, // 沒番茄的週壓扁成這麼高
      // 分析（AG5）
      statsBars: 112, // 長條圖最高那根多高
      statsShare: 6, // 各標籤占比那條橫槓多粗
      statsName: 64, // 各標籤那列名字欄多寬
      weekDayWidth: 40, // 上面那排一天的寬
      dayDot: 6, // 有紀錄那天下面的小點
      blockIcon: 16, // 時間軸裡的小番茄圖
      colorSwatch: 36, // 設定選番茄色的那五顆（W1）
      selectRing: 2, // 選中那顆外面的圈
      zenSeam: 2, // 聚焦模式每張牌中間那道橫縫
      // 計時中長大的番茄（AG2）與慶祝畫面（AG3）
      growSize: 132, // 全熟那一刻畫多大
      growVine: 28, // 上面那段藤多長
      growVineWidth: 4,
      growMin: 96, // 中間那塊空位不到這麼高就不畫（小手機、最大字級）
      celebrateTomato: 132, // 慶祝畫面那顆
      celebrateDot: 26, // 「今天收了幾顆」那排的小番茄
      celebrateDotNew: 34, // 那排最後、剛收的這顆
      // 計時中與休息「番茄就是時鐘」（2026-11-18 AH2，比較頁 C）：一圈進度環圍著那顆番茄
      ringSize: 264, // 進度環最大直徑
      ringStroke: 10, // 環多粗
      ringTomato: 0.62, // 全熟那顆佔環直徑幾成
      ringRoom: 0.72, // 環最多佔中間那塊高度幾成（下面還要放時間），小手機與最大字級時環跟著縮
    },
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
        // 轉動（2026-11-16 番茄換成會滾的那顆）：只影響畫出來的角度，不回頭動位置與速度。
        // smooth、still 是電腦上量的（手機大小、40 顆、靜置 10 秒，位置沒動卻轉超過 1° 的：不濾 133/3200 顆，這組 10/3200）；順不順要真機看
        spin: {
          grip: 0.25, // 貼著罐底或別顆時，每一步往「滾動不打滑」靠多少（牆不帶轉）
          air: 0.995, // 半空中每一步留下多少轉速
          touch: 0.5, // 離罐底或別顆這麼近就算貼著（pt）
          smooth: 0.1, // 實際移動先平滑（每一步往新量到的靠多少），濾掉擠在堆裡原地來回抖的
          still: 8, // 平滑後不到這個速度（pt/秒）當作沒動，躺好的才不會自己慢慢轉
          sleep: 0.02, // 轉速小於這個（弧度/秒）就歸零
          lean: 0.6, // 開機安置與剛掉進來的那顆，一開始最多歪這麼多（弧度，約 34°）
        },
      },
      jarPhysicsReduced: { tilt: false }, // 豆子靜止排在底部
      // 聚焦模式翻牌：牌先往後倒（halfMs）、換數字、再立回來（halfMs）。perspective 是牌高的幾倍。減少動態時不翻，數字直接換
      zenFlip: { halfMs: 150, fold: '-88deg', perspective: 2.5 },
      zenControls: { fadeMs: 200 }, // 三顆鈕淡入淡出
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
    _dark: dark,
  };
}

// 無 hook 情境（罐子物理、測試）用：只拿動態、觸覺、音效、尺寸，顏色是淺色那份
export const Token = makeTokens(douzhangTheme.colors.light, false);
