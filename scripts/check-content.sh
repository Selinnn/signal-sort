#!/bin/sh
# Gömülü içeriği release modunda tam doğrular: her seviye solver ile (par, çözüm sayısı, çözüm listesi)
# ve kampanya kaynaklardan birebir yeniden üretilebilir mi.
set -eu
cd "$(dirname "$0")/.."
swift build -c release --package-path Packages/GameCore >/dev/null
CLI=Packages/GameCore/.build/release/signalsort-cli
$CLI check-campaign SignalSort/Resources/Levels/campaign.json --deep
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
$CLI build-campaign --spec content/campaign-spec.json --handmade content/handmade --out "$TMP/campaign.json" >/dev/null
cmp -s "$TMP/campaign.json" SignalSort/Resources/Levels/campaign.json && echo "kampanya yeniden üretilebilir ✓" || { echo "kampanya kaynaklardan farklı ✗"; exit 1; }
