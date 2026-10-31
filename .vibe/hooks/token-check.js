#!/usr/bin/env node
// [token-check] 寫死數值與禁用 import 檢查（pre-commit 呼叫；也可手動 node .vibe/hooks/token-check.js <files...>）
// 規格：.uiux/05-設計代號/使用規則-暫定.md「寫死數值檢查」＋ .vibe/安全標準.md P4、P7。
// 範圍：douzhang/ 下的 .js／.jsx；排除 design/（代號與數字只准住那裡）、node_modules、.expo。
// 例外：該行尾端有 `// token-ok: 原因` 放行（要在 .uiux/lessons.md 記一筆）。
const fs = require('fs');
const path = require('path');

const files = process.argv.slice(2).filter((f) => /^douzhang[\\/].*\.jsx?$/.test(f));
const EXEMPT = /^douzhang[\\/](design[\\/]|node_modules[\\/]|\.expo[\\/])/;

const HARDCODE = [
  [/#[0-9a-fA-F]{3,8}\b/, '色碼'],
  [/\brgba?\(/, 'rgba()'],
  [/\bfontSize:\s*\d/, 'fontSize 數字'],
  [/\bpadding\w*:\s*\d/, 'padding 數字'],
  [/\bmargin\w*:\s*\d/, 'margin 數字'],
  [/\bborderRadius\w*:\s*\d/, 'borderRadius 數字'],
  [/\bduration\w*:\s*\d/, 'duration 數字'],
  [/\bwithSpring\(/, 'withSpring'],
  [/\bwithTiming\(/, 'withTiming'],
];
const FORBIDDEN_IMPORT = [
  [/from\s+['"]react-native-webview['"]|require\(['"]react-native-webview['"]\)/, 'react-native-webview（安全 P7）'],
  [/['"](@sentry\/|firebase|@react-native-firebase\/|mixpanel|@amplitude\/|@segment\/|posthog)/, '第三方分析／崩潰回報 SDK（安全 P4）'],
  [/['"]expo-router['"]/, 'expo-router（憲法 1）'],
];
const LOG = /\bconsole\.log\(/;

let bad = 0;
for (const f of files) {
  if (EXEMPT.test(f) || !fs.existsSync(f)) continue;
  const lines = fs.readFileSync(f, 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    const where = `${f}:${i + 1}`;
    for (const [re, why] of FORBIDDEN_IMPORT) if (re.test(line)) { console.error(`  ✗ ${where}  禁用 import：${why}`); bad++; }
    if (/\/\/\s*token-ok:/.test(line)) return;
    for (const [re, why] of HARDCODE) if (re.test(line)) { console.error(`  ✗ ${where}  寫死：${why}  →  改用 design/Tokens.js 或 design/params.js`); bad++; }
    if (LOG.test(line) && !/\/\/\s*log-ok:/.test(line)) { console.error(`  ✗ ${where}  console.log（安全 S8；真要留寫 // log-ok: 原因）`); bad++; }
  });
}
if (bad) {
  console.error(`[token-check] reason: ${bad} 處違反代號／安全規矩，提交被擋。`);
  process.exit(1);
}
console.error('[token-check] reason: 畫面檔沒有寫死數值與禁用 import，放行。');
