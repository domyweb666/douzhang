// 豆帳 非樣式數字。來源：.uiux/04-手感/參數表-暫定.md D 節（與之後的 A、B、C 節）。畫面與 core 只准從這裡拿數字。
export const params = {
  tickMs: 250, // 畫面時鐘刷新
  devLongPressMs: 1000, // 開發期長按「開始」觸發測試顆；正式 build 沒有這個手勢
  firstLineMaxChars: 120, // 安全標準 I7
  flowMinutes: [15, 30], // 鈴響後「再做一下」的兩個選項（PRD S11）
  noteMaxChars: 60, // 記一筆一行（原型 maxlength）
  voidTextMaxChars: 40, // 作廢原因選填那一行（原型 maxlength）
  typeLengths: [15, 20, 25, 30, 45, 50, 60], // 類型長度只有這些刻度（原型 select）
  typeNameMaxChars: 20, // 安全標準 I7
  taskNameMaxChars: 30, // 原型 maxlength
  estimateMax: 7, // 估幾顆的上限（原型 1–7）
  stopNoRecordMinutes: 5, // 開始不到這麼久就停，不留紀錄（06 結束這顆半頁）
  // 豆罐（參數表 B）：雙豆連結。其餘物理數字在 Tokens.motion.jarPhysics
  jar: {
    link: 32,
    linkMix: 0.3,
    sensorIntervalMs: 16, // 加速度計更新間隔（灰盒子同值）
    lowFpsThreshold: 40, // 連續幾秒低於這個 fps 就退成靜止版（PRD S19 低電量退路）
    lowFpsSeconds: 3,
  },
};

/** 豆罐物理吃的一包數字：從 Tokens（motion.jarPhysics、beanTap、shape.beanRadius）與上面的 jar 合成。 */
export const jarParams = (T) => ({
  ...T.motion.jarPhysics,
  radius: T.shape.beanRadius,
  link: params.jar.link,
  linkMix: params.jar.linkMix,
  tapRadius: T.motion.beanTap.radius,
  tapUp: T.motion.beanTap.up,
  tapSide: T.motion.beanTap.side,
});
export const MS_PER_MINUTE = 60 * 1000;
