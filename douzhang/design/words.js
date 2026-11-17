// 番茄帳（原豆帳）介面用詞。翻自 .uiux/05-設計代號/詞彙表-暫定.md（v0.1 暫定）。
// 畫面上每一個字只准從這裡拿；要新詞先加進詞彙表再加這裡。按鈕名一律動詞帶對象。
export const words = {
  appName: '番茄帳', // 2026-11-01 多米：豌豆全面換番茄（原「豆帳」）

  // 核心
  bean: '一顆', // 一段 25 分鐘的專注
  nextStep: '下一步', // 做完一顆留下的那句話（詞彙表的名詞；待機卡片小標 V2 改用 thisToDo）
  thisToDo: '這顆要做', // 待機卡片小標（2026-11-02 V2，多米看不懂「下一步」）
  start: '開始',
  startFirst: '開始這顆',
  rang: '響了。', // 鈴響頁標題
  keepThis: '收下這顆',
  keepWithoutNote: '這顆不留話',
  flowMore: (minutes) => `再做 ${minutes} 分`, // 分鐘數從 params.flowMinutes 來
  rest: '休息',
  nextBean: '下一顆', // 休息時那張卡的小標（U8）

  // 中途
  quickNote: '記一筆',
  noteThought: '冒出念頭', // 記一筆半頁裡的兩種（2026-11-02 U6 合成一顆「記一筆」）
  notePing: '有人找',
  countLabel: (name, n) => (n ? `${name} ${n}` : name), // 記過幾筆就在名字後面帶數字（計時中 chip）
  voidThis: '作廢這顆',
  doneEarly: '提早做完了',
  keepGoing: '繼續做',

  // 番茄與回看（2026-11-01 多米：豆子→番茄、雙豆→雙番茄、豆莢→番茄串、豆棚→番茄架）
  todayBeans: '今天的番茄',
  pea: '番茄',
  doublePea: '雙番茄',
  pod: '番茄串',
  rack: '番茄架',
  dayReceipt: '這天的收據',
  weekReceipt: '這週的收據',
  flipToBack: '翻到背面',
  estimate: '估幾顆',
  estimateVsActual: '估算對帳',
  hangLeaf: '掛一片葉子',
  closeDay: '收工', // 收工半頁標題與按鈕同字、番茄架頂端列

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
  bellSub: '寫一行給下一顆的自己。', // R1 後只當到點通知內文
  bellPlaceholder: '寫一行給下一顆的自己',
  bellPrevCap: '這顆在做', // 鈴響頁上一句小卡（2026-11-01 重新設計 R1）
  bellAsk: '下一顆接著做什麼？',
  devTypeName: '測試',
  devSection: '開發', // 設定最下面，只有開發版有
  testModeRow: '測試模式',
  testModeSub: '開了之後，主畫面的開始鈕直接開一顆 5 秒的測試番茄，休息也 5 秒。會記進今天的紀錄。',
  startTest: (len) => `開始測試・${words.typeLen(len)}`,
  settings: '設定',
  home: '主畫面', // 頁碼圓點的讀屏名（左右滑三頁）

  // 通知（A4）：文案固定，不含那句（安全 P3）
  restDone: '休息完了',
  notificationOffLine: '到點通知沒開。鈴只在番茄帳打開時響。',
  openNotifications: '打開通知',

  // 鈴響細節（A5）
  rangAgo: (minutes) => `響了 ${minutes} 分鐘前。收下後直接回待機。`,

  // 中途保護（B1、B2）：06 狀態表「記一筆」「結束這顆」「作廢原因」三個半頁
  endThis: '結束這顆', // 計時中底部的文字鈕（U6）
  endTitle: '結束這顆？',
  endSubEarly: '開始不到五分鐘，停下來不會留下紀錄。',
  endSub: '作廢只記一筆，不扣任何東西。',
  doneEarlySub: '剩下的時間小修，鈴響再停',
  doneEarlyLine: '剩下的時間，唸一遍、檢查、小修。鈴響再停。', // 標記提早做完後卡片多的一行
  stopNow: '停下來', // 不到五分鐘的作廢叫法
  noteTitleThought: '冒出什麼念頭？',
  noteTitlePing: '誰找你、什麼事？',
  noteSub: '寫一行就好，休息時再處理。',
  jotDown: '記下',
  voidSub: '原因寫事實就好。',
  voidReasons: ['念頭', '訊息', '卡住', '其他'],
  voidTextPlaceholder: '例：去看留言（分鐘數會自動記）',

  // 聚焦模式（2026-11-17）：計時中橫放的整頁時鐘
  zenEnter: '聚焦模式', // 計時中「記一筆」旁邊那顆
  zenLeave: '回主畫面', // 聚焦模式點一下畫面出現的三顆之一（另外兩顆是記一筆、結束這顆）
  zenScreenA11y: (time) => `聚焦模式，剩 ${time}。點兩下顯示按鈕`,

  // 類型與估幾顆（C1、C2；2026-11-02 U5 併成一張「這顆」半頁）
  thisBean: '這顆', // 半頁標題
  typeLen: (len) => (len < 1 ? `${Math.round(len * 60)} 秒` : `${len} 分`), // 不到一分鐘的只有開發期測試顆
  typeOption: (name, len) => `${name}・${len} 分`, // 「這顆」半頁的類型分段
  taskCap: '在做哪件事（選填，收工對帳用）',
  newTask: '＋ 新的一件事',
  estNamePlaceholder: '這件事叫什麼（例：腳本第 12 集）',
  estSave: '記下來',
  estShort: (n) => `估 ${n}`,
  minus: '−',
  plus: '＋',
  estLess: '少一顆',
  estMore: '多一顆',
  estValueA11y: (n) => `估 ${n} 顆`,
  noTask: '不掛任何事',
  check: '✓', // 半頁列選中的記號
  addType: '加一種',
  deleteThisType: '刪除這一類', // 類型半頁最下面（U10）
  tomatoColorRow: '番茄顏色', // 類型半頁（W1）
  tomatoColorName: {
    red: '紅番茄',
    orange: '橘番茄',
    yellow: '黃番茄',
    purple: '紫番茄',
    pink: '粉番茄',
  },
  typeNameA11y: '類型名字',
  newTypeName: '新類型',
  unnamedType: '未命名',
  back: '回去',

  // 設定的節奏、提醒、手感（G1；原型 renderSettings、06 設定狀態表）
  rhythm: '節奏',
  restRow: '休息',
  restModeAuto: '到點提醒我',
  restModeSelf: '我自己決定',
  // 短休息、長休息（2026-11-17 設定 A）
  typeSub: '每種類型一個長度，番茄大小跟著長度走',
  restShortRow: '短休息',
  restShortAuto: '跟著長度',
  restShortAutoSub: '跟著長度：番茄長度 ÷ 5，最少 3 分。',
  restLongRow: '長休息', // 設定那一列，也是休息畫面輪到長休息那次的小標
  restLongOff: '關',
  restLongEvery: (every) => `每 ${every} 顆`,
  restLongValue: (every, minutes) => `每 ${every} 顆・${minutes} 分`,
  restLongSub: (every, minutes) => `今天每收下 ${every} 顆，那次休息 ${minutes} 分。`,
  restSelfSub: '休息不倒數，按「回來了，開始下一顆」才結束。',
  minutes: (m) => `${m} 分`,
  closeTimeRow: '收工時間',
  closeTimeSub: '過了這個時間，主畫面才會出現「收工」',
  reminders: '提醒',
  notifRow: '到點通知',
  notifOn: '開著',
  notifOff: '沒開',
  notifOpen: '打開',
  soundRow: '聲音',
  feel: '手感',
  tiltRow: '傾斜手機，番茄跟著滾',
  // 計時中擋住其他 app（AF1）
  shieldSection: '專注',
  shieldRow: '計時中擋住其他 app',
  shieldAppsRow: '要擋的 app',
  shieldAppsNone: '還沒選',
  shieldAppsCount: (count) => `${count} 項`,
  shieldSub: '按開始那一刻擋上；收下、結束，或響了之後回到番茄帳就解開。',
  shieldDenied: '螢幕使用時間沒有允許，所以開不了。',
  shieldPickDone: '完成', // 系統選擇畫面右上角

  // 備份與清空（G2–G4；06 設定狀態表、安全標準 S3–S5）。系統訊息第一句先講有沒有損失
  backup: '備份',
  exportBackup: '匯出備份',
  importBackup: '從備份匯入',
  backupNote: '番茄帳的資料只在這支 iPhone 上。每週匯出一次備份。',
  lastAutoBackup: (when) => `上次自動備份：${when}`,
  importTooBig: '這個檔案太大，不像番茄帳的備份，原本的資料沒動',
  autoBackupFailed: '沒辦法先把現在的資料備份起來，這次不匯入，原本的資料沒動',
  exportFailed: '這次沒匯出成功，原本的資料沒動',
  backupsLeft: '資料清掉了，但自動備份檔沒刪乾淨，再按一次清空試試',
  importConfirm: '用備份覆蓋現在的資料？',
  importConfirmOk: '覆蓋現在的資料',
  cancel: '取消',
  wipeTitle: '清空所有番茄、番茄串和設定後就找不回來了',
  wipeBody: '要留的話先匯出備份。',
  wipedLine: '全部清掉了。清掉的拿不回來，有匯出過的備份可以在設定匯入。',
  wipedAction: '去設定匯入',

  // 收工與葉子（F1、F2）：06 收工半頁、番茄架頂端列；待機那一行照原型 renderHome
  closeSub: '今天的番茄串掛上架，最後那句種進土裡，明天打開就在。',
  closeTomorrowCap: '明天的第一句',
  notYet: '還沒',
  leafLine: '今天沒有番茄？整天在回訊息、開會，掛一片葉子，不算缺。', // 鈕用上面的 hangLeaf
  closeDueHint: '到收工時間了・收工 ›',
  closedHint: '今天收工了，要再做一顆也行',
  leafHint: '今天掛了一片葉子',
  rackCloseSub: '把今天的番茄串掛上架，留明天的第一句',
  rackLeafTitle: '今天不適合番茄？',
  rackLeafSub: '整天在回訊息、開會，掛一片葉子',

  // 番茄架時間軸（U9）
  prevWeek: '‹',
  nextWeek: '›',
  prevWeekA11y: '上一週',
  nextWeekA11y: '下一週',
  weekReceiptLink: '這週的收據 ›',
  daySumLine: (beans, minutes) => `${beans} 顆・${Math.round(minutes)} 分`,
  blockTitle: (typeName, len, flow) =>
    `${typeName}・${words.typeLen(len)}${flow ? `＋${flow}` : ''}`,
  hourLabel: (h) =>
    h === 0
      ? '半夜 12'
      : h < 12
        ? `上午 ${h}`
        : h === 12
          ? '中午 12'
          : h < 18
            ? `下午 ${h - 12}`
            : `晚上 ${h - 12}`,
  dayA11y: (key, has) => `${words.monthDay(key)} ${words.weekday(key)}${has ? '，有紀錄' : ''}`,

  // 番茄架與收據（E1、E2）：原型 renderRack／openReceipt／openWeek 的字
  ok: '好', // 06 狀態表：收據半頁的關閉鈕叫「好」（詞彙表「不用好」是對動作鈕說的，這裡沒有動作）
  thisWeek: '這週',
  weekOf: (key) => `${words.monthDay(key)} 那週`,
  monthDay: (key) => {
    const d = new Date(`${key}T00:00`);
    return `${d.getMonth() + 1}月${d.getDate()}日`;
  },
  weekday: (key) =>
    `星期${['日', '一', '二', '三', '四', '五', '六'][new Date(`${key}T00:00`).getDay()]}`,
  rackEmpty: '第一顆響完，這裡就會掛上今天的番茄串。',
  rackEmptyAction: '回去開始一顆',
  chevron: '›', // 列尾「還有下一層」的記號
  voidA11y: '作廢', // 番茄串上空心圈的讀屏名
  leafA11y: '一片葉子', // 葉子的讀屏名
  dayReceiptTitle: (key) => `${words.monthDay(key)}的收據`,
  leafDay: '這天掛的是一片葉子。',
  noNoteMark: '沒留話',
  flowMark: (minutes) => `延長 ${minutes} 分`,
  jotMark: (notes, pings) => `${'′'.repeat(notes)}${'–'.repeat(pings)}`, // 原型：念頭一撇、有人找一橫
  voidLine: ({ minute, reason, text }) =>
    `作廢，第 ${minute} 分鐘${reason ? `・${reason}` : ''}${text ? `：${text}` : ''}`,
  restOverLine: (minutes) => `休息多了 ${minutes} 分鐘。`,
  novelMark: '第一次做',
  estActual: (est, actual) => `估 ${est}・實 ${actual}`,
  weekSub: (key) => `${words.monthDay(key)}起的一週。只看方向，不看分數。`,
  unitsLabel: (units) => `${units} 格`,
  weekEmpty: '這週還沒有番茄。',
  underLabel: '估少了',
  overLabel: '估多了',
  evenLabel: '剛好',
  timesLabel: (n) => `${n} 次`,
  verdictFewData: '對帳的資料還不多，先繼續估。',
  verdictUnder: '這週大多估少了。下次估同類的事，直接多加一些。',
  verdictOver: '這週大多估多了。',
  verdictEven: '估少和估多差不多，代表沒有一直往同一邊偏。',
  voidDist: '作廢分佈',
  voidHint: '作廢多半跟番茄長度、或任務沒切小有關，不是意志力。',
  flowHint: '這週一半以上的番茄都延長了，這類事可以試試把番茄拉長。',

  // 休息（A6）：收下後那 24 句，輪替、不連續重複（原型 LINES 原文）。可愛的話只准由這裡說。
  restLines: [
    '收下了，這顆是完整的。',
    '番茄串上多一顆。',
    '響完了，起來喝口水。',
    '那句會在下一顆等你。',
    '寫下來了，腦袋可以先放掉它。',
    '好，停在這裡剛剛好。',
    '一顆，沒有半顆。',
    '先離開螢幕五分鐘。',
    '收據開好了。',
    '去窗邊看一下遠的地方。',
    '這一句留給五分鐘後的你。',
    '番茄串又長一點了。',
    '站起來伸個懶腰吧。',
    '手機先別拿，走兩步。',
    '剛那段辛苦了。',
    '下一步在這裡了，不用一直記著。',
    '這顆長得挺飽滿。',
    '記好了，休息去。',
    '一段沒被打斷的，收進來。',
    '好，喝水時間。',
    '番茄上串了。',
    '先閉眼坐一下也行。',
    '這顆算數。',
    '去倒杯水，鈴響再回來。',
  ],
};
/** 待機開始鈕上方那一行：類型名字「一般 ›」。分鐘在開始鈕上；事名 V2 起搬進卡片 */
export const thisRowLabel = (typeName) => `${typeName} ${words.chevron}`;
/** 卡片裡的事名那行：「寫腳本第 12 集・估 3 顆」 */
export const taskLine = (task) => `${task.name}・估 ${task.est} 顆`;
/** 待機開始鈕的字：「開始・25 分」「開始這顆・25 分」 */
export const startLabel = (label, len) => `${label}・${len} 分`;
