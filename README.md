# Signal Sort

iOS routing puzzle oyunu. Plan ve kurallar: [PLAN.md](PLAN.md).

## Yapı
- `Packages/GameCore` — saf Swift oyun çekirdeği + `signalsort-cli` (UI bağımlılığı yok)
- `SignalSort/` — SwiftUI iOS uygulaması (iOS 17+, iPhone, dikey)
- `project.yml` — XcodeGen tanımı; `SignalSort.xcodeproj` bundan üretilir

## Komutlar
```bash
xcodegen generate                                   # project.yml değişince
(cd Packages/GameCore && swift test)                # çekirdek testleri (simülatörsüz)
(cd Packages/GameCore && swift run signalsort-cli)  # seviye araçları (yardım)
(cd Packages/GameCore && swift run -c release signalsort-cli generate --profile color --seed 1 --count 50 --out /tmp/levels)
(cd Packages/GameCore && swift run -c release signalsort-cli validate --deep /tmp/levels/*.json)
xcodebuild test -project SignalSort.xcodeproj -scheme SignalSort -destination 'platform=iOS Simulator,name=iPhone 17'
```
