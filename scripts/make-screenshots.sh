#!/bin/sh
# App Store ekran görüntüleri: iPhone 17 Pro Max (6.9", 1320×2868) üzerinde EN/TR/ES çeker,
# temiz durum çubuğu ayarlar ve başlıklı son görselleri fastlane/screenshots/<dil>/ altına yazar.
# Ham görüntüler fastlane/raw/ altında kalır (git dışı); yalnız başlıkları değiştirmek için:
#   swift scripts/compose-screenshots.swift en fastlane/raw/en-US fastlane/screenshots/en-US
set -eu
cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-iPhone 17 Pro Max}"
UDID=$(xcrun simctl list devices available | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

for LANG in en tr es; do
  case $LANG in en) DIR=en-US ;; tr) DIR=tr ;; es) DIR=es-ES ;; esac
  TEST_RUNNER_SCREENSHOT_LANG=$LANG xcodebuild test -project SignalSort.xcodeproj -scheme SignalSort \
    -destination "id=$UDID" -derivedDataPath "$WORK/dd" -resultBundlePath "$WORK/$LANG.xcresult" \
    -only-testing:SignalSortUITests/StoreScreenshotTests >"$WORK/$LANG.log" 2>&1 || { tail -30 "$WORK/$LANG.log"; exit 1; }
  xcrun xcresulttool export attachments --path "$WORK/$LANG.xcresult" --output-path "$WORK/$LANG" >/dev/null
  mkdir -p "fastlane/screenshots/$DIR"
  python3 - "$WORK/$LANG" "$WORK/raw-$LANG" <<'PY'
import json, os, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
for test in json.load(open(os.path.join(src, "manifest.json"))):
    for a in test["attachments"]:
        name = a.get("suggestedHumanReadableName", "").split("_")[0]
        if name[:2].isdigit():
            shutil.copy(os.path.join(src, a["exportedFileName"]), os.path.join(dst, name + ".png"))
PY
  mkdir -p "fastlane/raw/$DIR"
  cp "$WORK/raw-$LANG"/*.png "fastlane/raw/$DIR/"
  swift scripts/compose-screenshots.swift "$LANG" "fastlane/raw/$DIR" "fastlane/screenshots/$DIR"
done
xcrun simctl status_bar "$UDID" clear
echo "ekran görüntüleri: fastlane/screenshots/"
