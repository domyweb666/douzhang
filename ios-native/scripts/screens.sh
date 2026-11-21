#!/bin/bash
# 模擬器截圖走查：把開發版裝進模擬器，一個情境一個情境開起來截圖。沒有 Mac 時由雲端跑（ios-native-ci.yml）。
# 用法：scripts/screens.sh <Douzhang.app 的路徑> <截圖要放的資料夾>
# 每個情境：造一份狀態檔 → 用環境變數叫 app 讀那份、停在哪一頁（App/LaunchOptions.swift，只有開發版讀得到）→ 等畫面穩定 → 截圖。
set -euo pipefail

APP="$1"
OUT="$2"
BUNDLE="org.domyweb.douzhang"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
mkdir -p "$OUT"

UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    for device in devices[runtime]:
        if device["name"] == "iPhone 17":
            print(device["udid"])
            raise SystemExit
')"
echo "模擬器：$UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"

# 名字  狀態  哪一頁  番茄架看什麼  深色還是淺色
shots=(
  "01-home-empty      empty  home      day    light"
  "02-home-idle       idle   home      day    light"
  "03-home-focus      focus  home      day    light"
  "04-home-rest       rest   home      day    light"
  "05-bell            bell   home      day    light"
  "06-rack-empty      empty  rack      day    light"
  "07-rack-day        idle   rack      day    light"
  "08-rack-three      idle   rack      three  light"
  "09-rack-week       idle   rack      week   light"
  "10-rack-month      idle   rack      month  light"
  "11-rack-stats      idle   rack      stats  light"
  "12-settings        idle   settings  day    light"
  "13-home-idle-dark  idle   home      day    dark"
  "14-home-focus-dark focus  home      day    dark"
  "15-rack-day-dark   idle   rack      day    dark"
  # 分析頁驗證用的三份假使用者（make_users.py）：第 5 天、第 3 週、斷了一陣子回來。各拍鈴響頁與分析
  "16-day5-bell       user-day5-bell   home  day    light"
  "17-day5-stats      user-day5        rack  stats  light"
  "18-week3-bell      user-week3-bell  home  day    light"
  "19-week3-stats     user-week3       rack  stats  light"
  "20-back-bell       user-back-bell   home  day    light"
  "21-back-stats      user-back        rack  stats  light"
)

for shot in "${shots[@]}"; do
  read -r name scenario page rack look <<<"$shot"
  if [[ "$scenario" == user-* ]]; then
    # 假使用者：順便把這一份該出現的字（標準答案）跟截圖放在一起
    python3 "$HERE/make_users.py" "${scenario#user-}" "$WORK/$name" >/dev/null
    cp "$WORK/$name/expected.json" "$OUT/$name.expected.json"
  else
    python3 "$HERE/make_state.py" "$scenario" "$WORK/$name"
  fi
  xcrun simctl ui "$UDID" appearance "$look"
  SIMCTL_CHILD_DOUZHANG_DATA_DIR="$WORK/$name" \
    SIMCTL_CHILD_DOUZHANG_PAGE="$page" \
    SIMCTL_CHILD_DOUZHANG_RACK="$rack" \
    xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
  sleep 6
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  xcrun simctl terminate "$UDID" "$BUNDLE" || true
  echo "截好 $name"
done
xcrun simctl ui "$UDID" appearance light
