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
)

for shot in "${shots[@]}"; do
  read -r name scenario page rack look <<<"$shot"
  python3 "$HERE/make_state.py" "$scenario" "$WORK/$name"
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
