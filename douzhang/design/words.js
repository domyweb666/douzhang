// 豆帳 介面用詞。翻自 .uiux/05-設計代號/詞彙表-暫定.md（v0.1 暫定）。
// 畫面上每一個字只准從這裡拿；要新詞先加進詞彙表再加這裡。按鈕名一律動詞帶對象。
export const words = {
  appName: '豆帳',

  // 核心
  bean: '一顆', // 一段 25 分鐘的專注
  nextStep: '下一步', // 做完一顆留下的那句話
  start: '開始',
  startFirst: '開始這顆',
  rang: '響了。', // 鈴響頁標題
  keepThis: '收下這顆',
  keepWithoutNote: '這顆不留話',
  flow15: '再做 15 分',
  flow30: '再做 30 分',
  flowTitle: '在狀態裡，再做一下', // 只當說明句
  rest: '休息',

  // 中途
  quickNote: '記一筆',
  noteThought: '冒出念頭', // 記一筆的兩種入口，多米待定要不要合成一個
  notePing: '有人找',
  voidThis: '作廢這顆',
  doneEarly: '提早做完了',
  keepGoing: '繼續做',

  // 豆子與回看
  todayBeans: '今天的豆子',
  pea: '豆子',
  doublePea: '雙豆',
  pod: '豆莢',
  rack: '豆棚',
  dayReceipt: '這天的收據',
  weekReceipt: '這週的收據',
  flipToBack: '翻到背面',
  estimate: '估幾顆',
  estimateVsActual: '估算對帳',
  hangLeaf: '掛一片葉子',
  closeDay: '收工',

  // 設定與狀態
  taskType: '任務類型',
  notificationOff: '到點通知沒開',
  wipeAll: '清空所有資料',

  // 平實語氣的系統訊息：第一句先回答有沒有損失
  saveFailed: '這台裝置沒辦法存，記得匯出備份',
  importUnreadable: '這個檔案讀不懂，原本的資料沒動',

  // 系統文案（詞彙表「系統文案」節）
  firstPrompt: '寫下接下來要做的第一件事，寫到具體的動作',
  firstPlaceholder: '例：打開讀書筆記，把三個重點各寫一句',
  clueLabel: '昨天的你留了一句',
  doing: '正在做',
  restBody: '離開螢幕。喝水、看遠處、伸展、閉眼都好。',
  backFromRest: '回來了，開始下一顆',
  bellSub: '寫一行給下一顆的自己。',
  bellPlaceholder: '寫一行給下一顆的自己',
  devTypeName: '測試',
  settings: '設定',

  // 通知（A4）：文案固定，不含那句（安全 P3）
  restDone: '休息完了',
  notificationOffLine: '到點通知沒開。鈴只在豆帳打開時響。',
  openNotifications: '打開通知',

  // 鈴響細節（A5）
  flowMenu: '再做 15 分・30 分', // 鈴響頁右上，一顆只出現一次
  flowSub: '先定一個上限，到點會再響一次，那時再寫下一步。',
  rangAgo: (minutes) => `響了 ${minutes} 分鐘前。收下後直接回待機。`,

  // 休息（A6）：收下後那 24 句，輪替、不連續重複（原型 LINES 原文）。可愛的話只准由這裡說。
  restLines: [
    '收下了，這顆是完整的。',
    '豆莢裡多一顆。',
    '響完了，起來喝口水。',
    '那句會在下一顆等你。',
    '寫下來了，腦袋可以先放掉它。',
    '好，停在這裡剛剛好。',
    '一顆，沒有半顆。',
    '先離開螢幕五分鐘。',
    '收據開好了。',
    '去窗邊看一下遠的地方。',
    '這一句留給五分鐘後的你。',
    '豆莢又長一點了。',
    '站起來伸個懶腰吧。',
    '手機先別拿，走兩步。',
    '剛那段辛苦了。',
    '下一步在這裡了，不用一直記著。',
    '這顆長得挺飽滿。',
    '記好了，休息去。',
    '一段沒被打斷的，收進來。',
    '好，喝水時間。',
    '豆子入莢。',
    '先閉眼坐一下也行。',
    '這顆算數。',
    '去倒杯水，鈴響再回來。',
  ],
};
/** 類型 chip 的字：「一般・25 分」 */
export const typeChipLabel = (name, len) => `${name}・${len} 分`;
