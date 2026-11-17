// 豆帳 非樣式數字。來源：.uiux/04-手感/參數表-暫定.md D 節（與之後的 A、B、C 節）。畫面與 core 只准從這裡拿數字。
export const params = {
  tickMs: 250, // 畫面時鐘刷新
  devLongPressMs: 1000, // 開發期長按「開始」觸發測試顆；正式 build 沒有這個手勢
  firstLineMaxChars: 120, // 安全標準 I7
  flowMinutes: [15, 30], // 鈴響後「再做一下」的兩個選項（PRD S11）
  noteMaxChars: 60, // 記一筆一行（原型 maxlength）
  voidTextMaxChars: 40, // 作廢原因選填那一行（原型 maxlength）
  typeLengths: Array.from({ length: 18 }, (_, i) => (i + 1) * 5), // 5–90 分每 5 分一格（2026-11-02 V1 多米要到 90；滾輪選）
  tomatoColors: ['red', 'orange', 'yellow', 'purple', 'pink'], // 每種類型一個番茄色（2026-11-02 W1）；色碼在 Tokens 的 CharacterColors.tomato.body，圖在 ui/Tomato.js
  newTypeMinutes: 15, // 「加一種」新類型的長度（V1 刻度從 5 起算後明寫，維持原本 15）
  devTestSeconds: 5, // 開發期長按「開始」的測試顆與它的休息都是這麼久（V3：看番茄掉進罐子用）
  typeNameMaxChars: 20, // 安全標準 I7
  taskNameMaxChars: 30, // 原型 maxlength
  estimateMax: 7, // 估幾顆的上限（原型 1–7）
  importMaxBytes: 5 * 1024 * 1024, // 匯入檔大小上限 5 MB（安全標準 I3）
  closeTimes: ['17:00', '18:00', '19:00', '20:00', '21:00', '22:00'], // 收工時間的刻度（G1：不裝時間選擇器套件，整點六格）
  stopNoRecordMinutes: 5, // 開始不到這麼久就停，不留紀錄（06 結束這顆半頁）
  // 短休息、長休息的刻度（2026-11-17 多米看比較頁選設定 A）
  restShortOptions: ['auto', 3, 5, 10, 15], // 'auto'＝跟著番茄長度（÷5 最少 3），其餘是固定幾分
  restLongEveryOptions: [0, 3, 4, 5], // 今天每收下幾顆來一次長休息；0＝關
  restLongMinuteOptions: [15, 20, 30],
  // 豆罐（參數表 B）：雙豆連結。其餘物理數字在 Tokens.motion.jarPhysics
  jar: {
    // V4：番茄大小跟分鐘走，面積成正比（半徑∝√分鐘）；sizeRefMinutes 那麼長的是基準半徑，太小太大各夾住
    // 2026-11-17 多米看比較頁選 A「放寬兩端」：原本 0.7–1.75 倍，5 分跟 10 分一樣大、80 分以上也一樣大；
    // 放寬後 5 分直徑 28、10 分 35、90 分 106，每一格長度都分得出來
    sizeRefMinutes: 25,
    sizeMin: 0.5,
    sizeMax: 1.9,
    sensorIntervalMs: 16, // 加速度計更新間隔（灰盒子同值）
    lowFpsThreshold: 40, // 連續幾秒低於這個 fps 就退成靜止版（PRD S19 低電量退路）
    lowFpsSeconds: 3,
    redrawEpsilonPx: 0.5, // 每顆移動都小於這個就不重畫（靜止時省下重畫，D+E 審查員）
    redrawEpsilonRad: 0.01, // 轉動也一樣：小於這個弧度不重畫（最大那顆的邊緣大約動 0.5 pt）
  },
  // 收據（PWA openWeek 的三個門檻）
  receipt: {
    minTasksForVerdict: 3, // 對帳不到 3 次先不下結論
    voidsForHint: 3, // 作廢達 3 次才多那一行
    flowHintMinBeans: 4, // 至少 4 顆且一半以上延長才提示
  },
};

/** 豆罐物理吃的一包數字：從 Tokens（motion.jarPhysics、beanTap、shape.beanRadius）與上面的 jar 合成。 */
export const jarParams = (T) => ({
  ...T.motion.jarPhysics,
  radius: T.shape.beanRadius,
  sizeRefMinutes: params.jar.sizeRefMinutes,
  sizeMin: params.jar.sizeMin,
  sizeMax: params.jar.sizeMax,
  tapRadius: T.motion.beanTap.radius,
  tapUp: T.motion.beanTap.up,
  tapSide: T.motion.beanTap.side,
});
export const MS_PER_SECOND = 1000;
export const SECONDS_PER_MINUTE = 60;
export const MS_PER_MINUTE = SECONDS_PER_MINUTE * MS_PER_SECOND;
