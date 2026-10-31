#!/usr/bin/env bash
# [pre-commit] VibeRails 口吻鎖（vibe-voice-lock 2026-11-01 裝）
# 不管 AI 記不記得憲法，每次 commit 都跑：
#   1. token-check：douzhang/ 畫面檔不准寫死色碼／字級／間距、不准禁用 import、不准 console.log
#   2. prettier --check 與 eslint（只在 douzhang/ 已裝好 node_modules 時跑；A1 之前靜默跳過）
# 只看這次 staged 的檔，不掃整個 repo。
set -u
root="$(git rev-parse --show-toplevel)"
cd "$root" || exit 1

mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACMR -- 'douzhang/*.js' 'douzhang/*.jsx' 'douzhang/**/*.js' 'douzhang/**/*.jsx' 2>/dev/null | sort -u)
if [ "${#staged[@]}" -eq 0 ]; then
  echo "[pre-commit] reason: 這次沒動 douzhang/ 的程式，跳過口吻檢查" >&2
  exit 0
fi

echo "[pre-commit] reason: 檢查 ${#staged[@]} 個 douzhang/ 檔案" >&2
node "$root/.vibe/hooks/token-check.js" "${staged[@]}" || exit 1

if [ -d "$root/douzhang/node_modules" ]; then
  if [ -f "$root/douzhang/.prettierrc" ]; then
    (cd "$root/douzhang" && npx --no-install prettier --check "${staged[@]/#douzhang\//}" ) || { echo "[pre-commit] reason: Prettier 格式不合，跑 npx prettier --write 後再 commit" >&2; exit 1; }
  fi
  if [ -f "$root/douzhang/eslint.config.js" ]; then
    (cd "$root/douzhang" && npx --no-install eslint "${staged[@]/#douzhang\//}" ) || { echo "[pre-commit] reason: ESLint 有錯，修完再 commit" >&2; exit 1; }
  fi
else
  echo "[pre-commit] reason: douzhang/node_modules 還沒裝，Prettier／ESLint 先跳過（A1 裝好後自動啟用）" >&2
fi
exit 0
