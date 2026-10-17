# Signal Sort 1.0 — Yayın kontrol listesi

Kod tarafı hazır: Release derlemesi temiz (`1.0.0 (1)`, iOS 17+, iPhone, ~9 MB), testler ve içerik kontrolü yeşil.
Aşağıdaki adımlar **senin hesaplarınla** yapılmalı (ödeme, vergi, sözleşme, kimlikler). Sıra önemli.

## 1. Apple Developer ve sözleşmeler
- [ ] Apple Developer Program üyeliği aktif (ekip: *Selin Kaplan*, Team ID `67ANTJMF7U`).
- [ ] App Store Connect → **İş (Business)**: *Paid Apps* sözleşmesi, vergi formları ve banka bilgileri.
      Uygulama içi satın alma için zorunlu; bilgileri senin girmen gerekiyor.

## 2. Uygulama kaydı (App Store Connect → Uygulamalar → +)
| Alan | Değer |
|---|---|
| Platform | iOS |
| Ad | Signal Sort (alınmışsa yedek: *Signal Sort: Route Puzzle*) |
| Birincil dil | English (U.S.) |
| Bundle ID | `com.selinkaplan.signalsort` (listede yoksa Developer → Identifiers'da oluştur) |
| SKU | `signalsort-ios` |
| Fiyat | Ücretsiz, tüm ülkeler |

## 3. Uygulama içi satın almalar (ID'ler kodla birebir aynı olmalı)
| Ürün ID | Tür | Fiyat | Görünen ad (EN / TR / ES) |
|---|---|---|---|
| `com.selinkaplan.signalsort.fullgame` | Non-Consumable | 4,99 $ | Full Game / Tam Oyun / Juego completo |
| `com.selinkaplan.signalsort.removeads` | Non-Consumable | 2,99 $ | Remove Ads / Reklamları Kaldır / Quitar anuncios |
| `com.selinkaplan.signalsort.hints10` | Consumable | 0,99 $ | 10 Hints / 10 İpucu / 10 pistas |

- Açıklamalar `StoreKit/SignalSort.storekit` içinde üç dilde hazır.
- İnceleme ekran görüntüsü: `appstore/iap-review-screenshot.png` (üçü için de kullanılabilir).
- Ürünler ilk sürümle **birlikte** incelemeye gönderilmeli (sürüm sayfasında "In-App Purchases" bölümünden eklenir).

## 4. AdMob (gerçek reklam kimlikleri olmadan arşiv bilerek hata verir)
- [ ] AdMob'da uygulamayı ekle (iOS, "henüz mağazada değil"), iki reklam birimi oluştur: **Ödüllü** ve **Geçiş (Interstitial)**.
- [ ] `project.yml` içindeki üç değeri değiştir, sonra `xcodegen generate`:
      `ADMOB_APP_ID` (`ca-app-pub-…~…`), `ADMOB_REWARDED_ID`, `ADMOB_INTERSTITIAL_ID` (`ca-app-pub-…/…`).
      Debug derlemeler test kimlikleriyle kalsın istersen bu değerleri yalnız Release yapılandırmasına taşıyabilirim.
- [ ] **Privacy & messaging**: GDPR onay mesajı ve IDFA (ATT) açıklama mesajı oluştur ve yayımla.
- [ ] Uygulama ayarları → maksimum reklam içerik derecesi **G**; kumar/flört kategorilerini engelle.
- [ ] Hesaptaki `pub-` kimliğiyle `app-ads.txt`: GitHub'da `Selinnn/selinnn.github.io` adlı repoyu oluştur, köküne
      `appstore/app-ads.txt` içeriğini koy (`pub-XXXX…` yerine kendi kimliğin). Adres: `https://selinnn.github.io/app-ads.txt`.
      İstersen bunu ben yaparım; kimliği vermen yeterli.
- [ ] `SignalSort/Resources/Info.plist` → `SKAdNetworkItems`: Google'ın güncel listesini ekle
      (https://developers.google.com/admob/ios/3p-skadnetworks). Şu an yalnız Google'ın kendi girdisi var.

## 5. App Store Connect formları
- [ ] **App Privacy**: `appstore/privacy-labels.md` taslağına göre (göndermeden önce Google'ın güncel rehberiyle karşılaştır).
      Gizlilik politikası URL'i: `https://selinnn.github.io/signal-sort/privacy.html`
- [ ] **Yaş derecelendirmesi**: şiddet, korku, kumar, yarışma, sınırsız web erişimi, kullanıcı içeriği yok →
      beklenen sonuç 4+. Reklam ve uygulama içi satın alma sorularına "evet" de.
- [ ] **Kategori**: Oyunlar → Bulmaca (birincil), Gündelik (ikincil). (`fastlane/metadata/*category*.txt`)
- [ ] **Şifreleme**: Info.plist'te `ITSAppUsesNonExemptEncryption = NO` olduğu için soru sorulmaz.

## 6. Metin ve ekran görüntüleri
- Elle: `fastlane/metadata/<dil>/` dosyalarını ilgili alanlara kopyala; görseller `fastlane/screenshots/<dil>/`
  (6.9" iPhone, 1320×2868; daha küçük ekranlar için App Store bunları ölçekler).
- Ya da otomatik: App Store Connect → Users and Access → Integrations → **App Store Connect API** anahtarı oluştur,
  `.p8` dosyasını repoya **koymadan** şu JSON'u hazırla ve çalıştır:
  ```json
  { "key_id": "XXXXXXXXXX", "issuer_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", "key_filepath": "/Users/selinkaplan/.appstoreconnect/AuthKey_XXXXXXXXXX.p8" }
  ```
  ```bash
  ASC_API_KEY_PATH=~/.appstoreconnect/signalsort.json fastlane metadata
  ```
- İnceleme notları: `fastlane/metadata/review_information/notes.txt`. İletişim için ad, telefon ve e-posta formda girilir.
  Demo hesap gerekmez (giriş yok).

## 7. Derleme ve yükleme
1. Her yüklemede derleme numarasını artır: `project.yml` → `CURRENT_PROJECT_VERSION` (1, 2, 3…), sonra `xcodegen generate`.
2. Ya Xcode: **Product → Archive → Distribute App → App Store Connect → Upload** (otomatik imzalama dağıtım
   sertifikasını kendisi oluşturur),
   ya da: `ASC_API_KEY_PATH=… fastlane release` (içerik kontrolü + arşiv + yükleme; **incelemeye göndermez**).
3. İşlenen derlemeyi kendi iPhone'unda TestFlight (yalnız dahili) ile 10 dakika dene: satın alma (sandbox),
   geri yükleme, ödüllü reklam, onay formu, ses/titreşim. Dış test gerekmez.

## 8. İncelemeye gönderme (senin onayınla)
- [ ] Sürüm sayfasında derlemeyi seç, üç uygulama içi satın almayı ekle, notları kontrol et.
- [ ] Yayın: **Manuel** ya da **Aşamalı yayın (7 gün)** önerilir.
- [ ] **Submit for Review**.

## 9. Onaydan sonra
- [ ] AdMob'da uygulamayı App Store kaydına bağla; `app-ads.txt` doğrulamasını bekle (24 saate kadar).
- [ ] Xcode Organizer'da çökme raporlarını ve App Store Connect Analytics'i izle.
- [ ] `dailies.json` 2028-10-30'da biter: ondan önce `build-dailies` ile uzatıp yeni sürüm yayımla.
