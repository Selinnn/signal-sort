# Signal Sort — Geliştirme ve Yayın Planı (v2)

Kaynak: `Signal_Sort_Analiz_Dokumani_TR.docx` (v1.0, 17 Ekim 2026).
v2 değişikliği: TestFlight / prototip karar kapıları kaldırıldı. Hedef, uygulamayı **tek seferde eksiksiz geliştirip
App Store'a göndermek**. Doğrulama dış test kullanıcıları yerine otomatik kalite güvencesi ile yapılır (§7).

Ortam: Xcode 26.1, Swift 6.2.1. Proje klasörü `~/signal-sort/` (eski adı `signal-port`); kendi git reposu yok → ilk adım `git init`.

---

## 1. Oyun mantığındaki hatalar ve çözümleri

### 1.1 Temel hata: farklı renkler aynı oku asla paylaşamaz → oyun sığ kalır
Dokümandaki kurallarla (ok = sinyali sabit yöne çevirir, tahta çalışırken değişmez) şu ispatlanabilir:
iki sinyal aynı hücreden **aynı yönde** çıkarsa, bundan sonraki yolları birebir aynıdır ve aynı çıkışa varırlar.
Bir oktan geçen her sinyal o okun yönünde çıktığı için:

- **Farklı renkte iki sinyal hiçbir zaman aynı oktan geçemez** (biri mutlaka yanlış çıkışa gider).
- Farklı renkler yalnızca **boş hücrede, farklı yönlerde** kesişebilir.

Sonuç: dokümandaki mekanikte renkler arası tek etkileşim "kesişme noktasında aynı tick'te çarpışmama"dır.
Oyuncu çoğu seviyede her oku çıkışa doğru çevirir; bulmaca labirent takibine indirgenir. Dokümanın "sıradan
sort oyunundan farklılaşma" iddiası bu kurallarla tutmaz. (v1 planımda önerdiğim "paylaşılan ok" metriği de
bu yüzden yanlıştı — düzeltildi.)

**Çözüm — mekanik katmanları** (her biri bir bölümde öğretilir, hepsi deterministik ve tek bakışta okunur):

| # | Öğe | Kural | Kazandırdığı derinlik |
|---|---|---|---|
| 1 | **Ok (Router)** | Giren sinyalin yönünü okun yönü yapar. Dokununca saat yönünde 90° döner | Rota kurma |
| 2 | **Sabit ok** | Ok gibi, dönmez | Rotayı kısıtlar |
| 3 | **Engel** | Girilemez | Rotayı kısıtlar |
| 4 | **Kesişme + zamanlama** | Aynı tick aynı hücre = çarpışma | Oyuncu bir sinyali **dolambaçlı yoldan** geciktirerek çarpışmayı önler |
| 5 | **Renkli ok** | Yalnızca kendi rengindeki sinyali çevirir; diğer renkler düz geçer | Farklı renkler aynı hücreyi **gerçekten paylaşır** |
| 6 | **Makas (Toggle) ok** | Giren sinyale mevcut yönünü verir, o tick'in sonunda kendiliğinden 90° saat yönünde döner; oyuncu başlangıç yönünü seçer, her Run başlangıç yönünden başlar | Sıra ve zamanlama planlaması |
| 7 | **Köprü** | Dikey ve yatay geçiş çarpışmaz (alt/üst geçit) | Yoğun tahtalarda kesişmeyi serbest bırakır |

Kampanya: her bölüm tek yeni öğe getirir, son bölüm hepsini karıştırır. Yeni öğe dışında kural eklenmez.

### 1.2 Kesin simülasyon kuralları (dokümanda tanımsız olanlar)

**Hareket:** Her tick'te tüm sinyaller eşzamanlı olarak bir hücre ilerler. Kaynak hücresi geçilemez; sinyal
ilk tick'te kaynağın baktığı komşu hücreye çıkar. Boş hücrede yön korunur. Ok hücresine **girdiği tick'te**
yön okunur ve bir sonraki tick o yönde çıkar.

**Tick çözüm sırası** (deterministik, her tick):
1. Her aktif sinyalin hedef hücresini hesapla.
2. Tahta dışı → `outOfBounds`. Engel veya kaynak hücresi → `blocked`.
3. Yer değiştirme: A→B ve B→A aynı tick'te → `swapCollision` (dokümanda yok; olmazsa sinyaller birbirinin içinden geçer).
4. Hareketi uygula. Çıkış hücresi: doğru renk → teslim (sinyal tahtadan kalkar), yanlış renk → `wrongReceiver`.
   Çıkış hücrelerinde çarpışma yoktur (aynı tick'te iki doğru sinyal teslim edilebilir).
5. Aynı hücrede ≥2 sinyal (köprü hariç; köprüde yalnızca aynı eksende iki sinyal çarpışır) → `collision`. Renk fark etmez.
6. Makas okları: bu tick'te girilen her makas ok, giren sinyal başına 90° saat yönünde döner (trace her tick'te makas yönlerini taşır; UI dönüşü sinyal çıkarken canlandırır).
7. Döngü: bir sinyal daha önce bulunduğu (hücre, yön) durumuna dönerse → `loop` (koordinat: tekrar edilen hücre).
   Makassız tahtalarda oklar Run boyunca sabit olduğundan bu kesin ve erken bir tespittir; global durum aramak
   gereksiz (sinyal periyotlarının EKOK'u kadar uzayabilir). Makaslı tahtada sinyal başına tekrar yeterli değil
   (makas değişmiş olabilir, sinyal sonra çıkabilir) → **tüm tahta durumu** (aktif sinyaller + makas yönleri)
   tekrar ederse tüm aktif sinyaller `loop`. Üst sınır `W×H×4×4^(makas sayısı)` tick (en fazla 1.000.000), aşılırsa `loop`.
   Hata koordinatları: `outOfBounds` → kenardaki son hücre, `blocked`/`wrongReceiver`/`collision` → girilen hücre,
   `swapCollision` → sinyalin kendi hücresi.

**Bitiş:** İlk başarısızlık tick'inde simülasyon durur; aynı tick'teki tüm hatalar raporlanır, UI sinyal ID
sırasına göre ilkini vurgular. Tüm sinyaller teslim edildiyse başarı.

**Çıkış kuralları:** Çıkış her yönden kabul eder ve kendi rengindeki sınırsız sayıda sinyali alır. Aynı renkten
birden çok kaynak olabilir. Validator: kaynağı olmayan çıkış ve çıkışı olmayan kaynak reddedilir.

### 1.3 Hamle ve puan hatası
Dokümanda "her dönüş bir hamle" deniyor ama Undo ücretsiz ve sınırsız; ok 4 kez döndürülünce başlangıca döner.
Bu, hamle sayısını keyfi ve sömürülebilir yapar (sayaç tıklama geçmişine bağlı, tahtaya değil).

**Çözüm:** Hamle = tahta durumundan hesaplanan değer:
`moves = Σ (mevcutYön − başlangıçYönü) mod 4` (yalnızca dönebilen oklar).
Tıklama geçmişinden bağımsızdır; Undo/Reset doğal çalışır, yanlışlıkla fazla döndürmek cezalandırılmaz.
- **Par** = solver'ın bulduğu tüm çözümler içinde minimum `moves`.
- **Yıldız:** 3★ `moves ≤ par`, 2★ `moves ≤ par+2`, 1★ çözüldü. İpucu kullanılırsa en fazla 2★.
- Run sayısı puanı etkilemez; "ilk denemede" rozeti ayrı tutulur.

### 1.4 Çözüm sayma hatası
Çözümde hiçbir sinyalin uğramadığı oklar herhangi bir yönde olabilir. Bunlar sayılırsa her ek tuzak ok çözüm
sayısını 4 katına çıkarır ve "tek çözüm" ölçütü anlamsızlaşır.

**Çözüm — olay güdümlü solver:** Sinyaller eşzamanlı simüle edilir; bir sinyal **henüz yönü atanmamış** bir
oka girdiğinde 4 yöne dallanılır, atanmış oka girerse atanan yön kullanılır. Uğranmayan oklar başlangıç yönünde
kalır (maliyet 0). Böylece:
- Çözüm sayısı yalnızca anlamlı kararları sayar.
- Arama ağacı boyutu (ziyaret edilen düğüm) doğrudan **zorluk ölçütü** olur.
- Uygulama: engine'e "karar bekleyen taş" kancası eklendi; solver her düğümde simülasyonu baştan koşar
  (motorla birebir aynı kurallar, ayrı kural kopyası yok). Brute-force ile 200 rastgele tahtada par eşleşmesi test edilir.
- Ölçüm (release, M serisi Mac, rastgele 7×7, 3 sinyal, 18 dönebilir taş): ortalama ~23 ms, en kötü ~1,2 sn
  (33 bin düğüm, düğüm başına ~36 µs). Bu yüzden **cihazda solver çalışmaz**: CLI her seviyenin çözümlerini
  JSON'a yazar (`solutions` alanı, adım 5), ipucu bu listeyle anında hesaplanır. Üretici, arama düğümü bandı
  dışındaki adayları zaten reddeder.

### 1.5 Planla → çalıştır döngüsündeki tasarım boşlukları
| Boşluk | Karar |
|---|---|
| Yol önizlemesi var mı? | **Yok.** Canlı önizleme bulmacayı labirent takibine çevirir. Başarısız Run'dan sonra iz, bir sonraki dokunuşa kadar soluk olarak tahtada kalır |
| Run sırasında dokunma | Kilitli. Sonuçtan sonra "Düzenle" planlama durumuna döner, oklar korunur |
| Animasyon hızı | 1×/2× ve "atla" (sonucu hemen göster). Reduce Motion açıksa varsayılan atla |
| Rastgele deneme | Run sınırsız (casual), ama 3★ par'a bağlı olduğundan düşünmek ödüllenir |
| İpucu ne yapar? | Solver, mevcut tahtaya **en yakın** çözümü bulur; yanlış yöndeki bir oku doğru yöne çevirip vurgular |
| Ters yönde döndürme | Yok (tek dokunuş = saat yönü). Hamle tahtadan hesaplandığı için 3 dokunuş cezalandırılmaz |

### 1.6 JSON örneği kendi kurallarıyla çelişiyor (doküman §11)
Örnekte kaynak (0,2)→doğu, `t_1_2` güney, `t_2_2` doğu, `parMoves: 2`. Çözüm için `t_1_2` doğuya dönmeli:
yalnız saat yönünde güney→batı→kuzey→doğu = **3 hamle**. Par 2 yanlış; ayrıca bu seviyede tek karar var (önemsiz).
Diğer şema hataları ve kararlar:
- Koordinat sistemi tanımsız → **(0,0) sol üst, y aşağı doğru artar.**
- `tiles` içinde `kind` yok → sabit ok, engel, renkli ok, makas, köprü ifade edilemiyor. `kind` zorunlu alan.
- Tile ID koordinattan türetilmiş (`t_1_2`) → düzenlemede tutarsızlaşır. ID'ler opak (`r1`, `b1`…).
- `rotationCost` ve "gate metadata" hiçbir kuralda tanımlı değil → çıkarıldı (renkli ok `color` alanını kullanır).
- `par` elle yazılmaz; CLI solver'dan yazar, CI yeniden doğrular, uyuşmazsa build kırılır.

```json
{ "id": "c007", "schemaVersion": 1, "width": 5, "height": 5,
  "sources":   [{"id": "s1", "color": "orange", "x": 0, "y": 2, "dir": "east"}],
  "receivers": [{"id": "d1", "color": "orange", "x": 4, "y": 2}],
  "tiles": [
    {"id": "r1", "kind": "router",  "x": 1, "y": 2, "dir": "south", "rotatable": true},
    {"id": "r2", "kind": "router",  "x": 2, "y": 2, "dir": "east",  "rotatable": false},
    {"id": "c1", "kind": "colorRouter", "color": "blue", "x": 3, "y": 3, "dir": "north", "rotatable": true},
    {"id": "b1", "kind": "blocker", "x": 3, "y": 1}
  ],
  "par": 3, "solutionCount": 1, "seed": null }
```

### 1.7 Üretim algoritmasındaki hatalar (doküman §7 kod bloğu)
1. `simulate(solvedBoard)` kontrol ediliyor ama **karıştırılmış adayın zaten çözülü olmadığı** kontrol edilmiyor
   (yol dışındaki ok karıştırıldıysa veya 4 tur döndüyse başlangıç = çözüm). → `simulate(candidate)` başarısız olmak zorunda.
2. Karıştırma yeni ve daha kısa çözümler açabilir; `knownSolutionMetadata` par için yanlış olur → par her zaman solver'dan.
3. "Yolların çarpışmamasını sağla" (adım 2) tam olarak §1.1'deki sığ seviyeleri üretir → kesişme/renkli ok bilinçli eklenir (§6).
4. Yalnız yol üstüne ok koyuyor → tuzak ok yok → tuzak yerleştirme adımı eklendi (§6).

### 1.8 Dokümanın iç tutarsızlıkları
- Seviye sayısı: §6 "30–50", §14 "20–30", P0 "20", gruplar "51+" → v1.0: 150 seviye (§3.2).
- "Hamle hedefi" (ileri seviyeler) ile "çözüm hamleden bağımsız" çelişiyor → hamle hedefi yalnız yıldız içindir, asla kilit değil.
- "Haftalık challenge … skor tablosu" ama backend/leaderboard yok → v1.0'dan çıkarıldı.
- Level ekranında Hint var ama ipucu sistemi yok → §1.5 + §3.3.
- "Minimal event logger": backend olmadan veri cihazdan çıkmaz, karar verdirmez → v1.0'da App Store Connect
  Analytics + MetricKit/Xcode Organizer yeterli; özel logger yok.
- "Reklamı test et" adımları TestFlight'a bağlıydı → test kapıları kalktığı için reklam v1.0'dan çıkarıldı (§3.3).

### 1.9 Günlük bulmaca determinizmi
Dokümanın "tarih + generatorVersion ile cihazda üret" önerisi riskli: üretici kodundaki her değişiklik o günün
haritasını değiştirir, eski ve yeni sürümdeki oyuncular farklı bulmaca görür, paylaşım kartları uyuşmaz.

**Çözüm:** Günlük bulmacalar **build sırasında CLI ile üretilir**, solver ile doğrulanır ve uygulamaya gömülür
(730 gün ≈ 300 KB JSON). Her biri yayından önce kalite filtresinden geçer. Gömülü liste biterse cihazda, sürüm
numarası sabitlenmiş üretici yedek olarak devreye girer. Gün anahtarı: cihazın yerel günü, Gregorian takvim, `yyyy-MM-dd`.
PRNG: kendi SplitMix64 implementasyonumuz (Swift'in `SystemRandomNumberGenerator`'ı seed almaz, `hashValue`
süreçten sürece değişir). Üretimde kayan nokta kullanılmaz.

---

## 2. Analizdeki diğer eksikler

1. **App Store Review 4.3 (Spam) riski:** Sort-puzzle kategorisi Apple'ın "çok sayıda benzer uygulama"
   reddine en açık kategorilerden. §1.1'deki özgün mekanik katmanları, özgün görsel dil ve inceleme notunda
   mekaniğin açıklanması bu riski azaltır. Dokümanda hiç geçmiyor.
2. **Reklamın uyum maliyeti dokümanda yok:** Reklam SDK'sı = AB/İngiltere için GDPR onay ekranı (Google UMP),
   ATT izni, `SKAdNetworkItems`, `app-ads.txt`, App Privacy'de "Data Used to Track You" etiketleri. Hibrit model
   seçildiği için bunların hepsi plana eklendi (§3.3, §8 adım 11, §9).
3. **Yayın gereksinimleri eksik:** `PrivacyInfo.xcprivacy` (UserDefaults required-reason API beyanı, `CA92.1`;
   yoksa yükleme uyarı/ret alır), gizlilik politikası URL'i, destek URL'i, yaş derecelendirmesi, şifreleme beyanı
   (`ITSAppUsesNonExemptEncryption = NO`), 6.9" ekran görüntüleri, IAP ürünlerinin ilk sürümle birlikte incelemeye gönderilmesi.
4. **İçerik hacmi:** Test kapısı olmadan tek seferde yayında 30–50 seviye az. Hedef: **150 kampanya seviyesi + günlük**.
5. **İpucu ekonomisi tanımsız:** Kaç ipucu, nasıl kazanılır? (§3.3)
6. **Seviye kilidi tanımsız:** Doğrusal mı, bölüm bazlı mı? (§3.2)
7. **Renk körlüğü için yalnızca "şekil veya harf" deniyor;** renk paleti + şekil eşlemesi tanımlı değil (§4).
8. **Küçük ekran:** 7×7 tahta iPhone SE'de (375 pt) hücre başına ~46 pt → 44 pt dokunma hedefini zar zor karşılar.
   Maksimum tahta 7×7 ile sınırlanır, 8×8 yok.
9. **Yerelleştirme:** Metin az ama tutorial ipuçları, hata nedenleri, mağaza metinleri çevrilmeli. Lansman: **EN + TR + ES** (kaynak dil EN; String Catalog).
10. **Reklam sıklığı test kapısı olmadan ayarlanamaz** (doküman bunu TestFlight'ta ölçmeyi planlıyordu) → muhafazakâr
    sabit kurallar + AdMob panelinden sunucu tarafı sıklık sınırı (güncelleme gerektirmeden ayarlanır) (§3.3).
11. **Ödülün çift verilmesi / reklam yüklenmemesi** dokümanda test maddesi olarak geçiyor ama davranış tanımlı değil (§3.3).

---

## 3. Ürün kapsamı (v1.0)

### 3.1 Ekranlar
Home (Continue, Günlük, Bölümler, Ayarlar, Mağaza) · Bölüm haritası · Level (grid, hamle/par, Run, Undo, Reset,
İpucu, hız) · Sonuç (yıldız, hamle, Sonraki) · Günlük (seri sayısı, paylaşım kartı) · Ayarlar (ses, haptik,
renk körü modu, animasyon hızı, gizlilik, **gizlilik seçenekleri (reklam onayı)**, destek, satın alımları geri yükle) ·
Mağaza (Reklamları Kaldır, Tam Oyun, ipucu paketi) · ATT ön açıklama ekranı.

### 3.2 İçerik ve ilerleme
| Bölüm | Seviye | Tahta | Yeni öğe |
|---|---|---|---|
| 1 Rota | 1–20 | 5×5 | Ok, kaynak, çıkış (1–5 tutorial) |
| 2 Engel | 21–45 | 5×5–6×6 | Engel, sabit ok |
| 3 Kesişme | 46–70 | 6×6 | 2–3 sinyal, çarpışma, zamanlama |
| 4 Renk | 71–95 | 6×6 | Renkli ok |
| 5 Makas | 96–120 | 6×6–7×7 | Makas ok |
| 6 Usta | 121–150 | 7×7 | Köprü + karışık |
| Günlük | sınırsız | 5×5–7×7 | Haftanın gününe göre zorluk (Pzt kolay → Paz zor) |

Bölüm içinde doğrusal kilit. Bir sonraki bölüm, önceki bölümün son seviyesi bitince açılır. Ceza, enerji,
zorunlu seri yok; günlük seri gösterilir ama kaçırılınca kayıp mesajı verilmez.

### 3.3 Monetizasyon (v1.0 — hibrit model)
**Ağ:** Google AdMob (Google Mobile Ads SDK, SPM) + Google UMP (onay). v1.0'da mediation yok, banner yok.

**İçerik ve satın almalar (StoreKit 2):**
| Ürün | Tür | Fiyat (öneri) | İçerik |
|---|---|---|---|
| Reklamları Kaldır | non-consumable | $2.99 | Geçiş reklamları tamamen kalkar. Ödüllü reklam isteğe bağlı olarak kalır |
| Tam Oyun | non-consumable | $4.99 | Bölüm 4–6 (seviye 71–150) + reklamsız + 20 ipucu + kozmetik temalar |
| İpucu paketi | consumable | $0.99 | 10 ipucu |

- Ücretsiz: **Bölüm 1–3 (70 seviye) + günlük bulmaca her zaman** (reklam envanteri için ücretsiz kısım geniş tutuldu).
- "Reklamları Kaldır"ı alan oyuncuya Mağaza'da Tam Oyun yine tam fiyatla gösterilir (StoreKit'te yükseltme fiyatı yok);
  Mağaza metni bunu açıkça söyler: "Tam Oyun reklamsızlığı da içerir".
- Satın alma durumu her açılışta `Transaction.currentEntitlements` ile doğrulanır; "Satın alımları geri yükle" Ayarlar'da.

**Ödüllü reklam (rewarded):**
- Yalnız oyuncu isterse: İpucu düğmesi, ipucu bitince "Reklam izle → +1 ipucu" seçeneği sunar. Günlük sınır 10.
- Ödül yalnız SDK'nın ödül callback'inde verilir; her reklam gösteriminin tek kullanımlık ID'si vardır → ödül iki kez verilemez.
- Reklam yüklenemezse (internet yok / dolum yok) seçenek gizlenir, yerine ipucu paketi gösterilir; oyun asla beklemez.

**Geçiş reklamı (interstitial) — kurallar (`AdPolicy`, saf ve unit-testli):**
- Yalnız Sonuç ekranından "Sonraki"ye basınca, yeni seviye yüklenmeden önce.
- Asla: ilk oturumda, seviye 10 tamamlanmadan, tutorial'da, Run animasyonu sırasında, başarısız Run sonrası,
  günlük bulmacadan sonra, satın alma ekranı açıkken.
- En az 3 tamamlanan seviyede bir **ve** son geçiş reklamından en az 3 dakika sonra.
- Ek emniyet: AdMob panelinde ad unit için sıklık sınırı (ör. saatte 4) — uygulama güncellemesi gerekmeden değiştirilir.
- Reklamlı oyuncu ipucu ekonomisi: başlangıçta 3 ipucu, her günlük bulmaca +1, ödüllü reklam +1.

**Onay ve takip izni sırası:** İlk açılışta hiçbir izin istenmez. Seviye 5 (tutorial sonu) bitince: önce UMP onay formu
(yalnız gerekli bölgelerde), ardından ATT izni (kısa ön açıklama ekranıyla). Reddedilirse kişiselleştirilmemiş reklam
gösterilir, oyun aynı çalışır. Ayarlar'da "Gizlilik seçenekleri" ile onay yeniden açılabilir (UMP zorunlu tutar).

**İçerik güvenliği:** AdMob maksimum reklam içerik derecesi **G**; kumar/flört kategorileri engellenir. Uygulama
"Made for Kids" değildir (Kids kategorisi reklam kısıtları nedeniyle).

### 3.4 Kapsam dışı (v1.0)
Backend, hesap, abonelik, banner reklam, reklam mediation, AdMob dışı üçüncü taraf SDK/analytics, multiplayer, leaderboard, seviye editörü,
runtime LLM, Android.

---

## 4. Görsel dil ve erişilebilirlik
- Koyu lacivert tema (varsayılan) + açık tema; tüm görseller SwiftUI `Shape`/`Canvas` (bitmap asset yok, ikon hariç).
- Renk ↔ şekil eşlemesi (Okabe–Ito paleti, renk körü güvenli):
  turuncu=daire, mavi=kare, yeşil=üçgen, sarı=elmas, pembe=yıldız. Bir seviyede en fazla 4 renk.
- Renkli oklar, ok gövdesinde rengin şeklini taşır. Makas ok: kavisli ok ikonu. Köprü: çapraz şerit.
- VoiceOver: her hücre "Ok, doğuyu gösteriyor, döndürmek için çift dokun"; Run sonucu sesli okunur.
- Dynamic Type (menüler), Reduce Motion, haptik (dönüş, teslim, hata), ses (sentezlenmiş kısa tonlar, lisans riski yok).

---

## 5. Mimari

```
signal-sort/
  Packages/GameCore/              # Saf Swift paketi (UI yok) — `swift test` macOS'ta saniyeler içinde
    Sources/GameCore/             # Models, SimulationEngine, Solver, LevelValidator, LevelGenerator,
                                  # QualityFilter, SplitMix64, Scoring, HintProvider
    Sources/signalsort-cli/       # render | validate | solve | generate | build-campaign | build-dailies
    Tests/GameCoreTests/
  SignalSort/                     # iOS app (SwiftUI, iOS 17+)
    App/ DesignSystem/ Features/{Home,Chapters,Board,Result,Daily,Settings,Store}
    Infrastructure/{Persistence,StoreKit,Ads,Consent,Haptics,Audio}
                                  # Ads: AdService protokolü, AdMobAdService, MockAdService (UI test/preview), AdPolicy
                                  # Consent: UMP + ATT akışı
    Resources/Levels/{campaign.json,dailies.json}  Resources/Localizable.xcstrings
  SignalSortTests/  SignalSortUITests/
  fastlane/                       # snapshot (ekran görüntüleri) + deliver (metadata)
  docs/privacy.html docs/support.html   # GitHub Pages
```

Kurallar: View kural hesaplamaz; `SimulationResult.tickTrace` animasyonun tek kaynağıdır. `GameSession`
(`@Observable`) yalnızca kullanıcı girdisini motora iletir. `LevelDefinition` değişmez, `LevelState` geçici.
Persistence: `Codable` + `UserDefaults`, şema versiyonlu. Crash/performans: MetricKit + App Store Connect.
Reklam metrikleri (gösterim, eCPM, ARPDAU) AdMob panelinden; ayrı analytics SDK'sı yok. Oyun kodu AdMob'u yalnız
`AdService` protokolü üzerinden görür; Debug build'de Google test ad unit ID'leri, Release'de gerçek ID'ler.

```swift
public struct SimulationEngine { func simulate(_ level: LevelDefinition, _ state: LevelState) -> SimulationResult }
public struct Solver { func solve(_ level: LevelDefinition, maxSolutions: Int) -> SolveReport } // par, solutionCount, searchNodes, solutions
public struct LevelValidator { func validate(_ level: LevelDefinition) -> [ValidationIssue] }
public struct LevelGenerator { func generate(seed: UInt64, profile: DifficultyProfile) throws -> LevelDefinition }
public struct HintProvider { func hint(_ level: LevelDefinition, _ state: LevelState) -> Hint? }
```

---

## 6. Seviye üretim hattı

1. **Tutorial (1–5) ve her bölümün ilk 2 seviyesi elle** JSON olarak yazılır (yeni öğeyi tek başına öğretir).
2. Diğerleri: `signalsort-cli build-campaign` → profil başına binlerce aday üretir:
   kaynaktan çıkışa yollar kur (renkli ok/makas/köprü profiline göre bilinçli kesişmeler ekle) → dönüş noktalarına ok,
   etrafına tuzak oklar koy → okları karıştır → solver.
3. **Kalite filtresi:** çözüm sayısı 1–3 · par ve arama düğümü bölüm bandında · en az bir tuzak ok
   ilk bakışta çekici (çıkışa doğru bakıyor ama yanlış) · çok sinyalli seviyelerde ≥1 kesişme ·
   başlangıç durumu çözülmüş değil · önceki seviyelerle benzerlik (normalize edilmiş tahta, döndürme/yansıma dahil) eşiğin altında.
4. Adaylar arama düğümü sayısına göre sıralanıp bölüm içinde artan zorlukla dizilir; her 5 seviyede bir "nefes" (kolay) seviye.
5. Sonuç `campaign.json` olarak commit'lenir (deterministik, tekrar üretilebilir; CLI seed'i kaydeder).
6. `build-dailies --from <tarih> --days 730` aynı hattan `dailies.json` üretir.
7. CI testi: her gömülü seviye validator'dan geçer, solver ≥1 çözüm bulur, kayıtlı par = solver par.

---

## 7. TestFlight olmadan kalite güvencesi
- **Motor:** her kural ve her hata tipi için unit test; property test (aynı girdi → aynı sonuç, her simülasyon sınırlı sürede biter);
  golden-seed testleri (PRNG ve üretici çıktısı sabit).
- **İçerik:** 150 + 730 seviyenin tamamı CI'da validator + solver'dan geçer.
- **Bot oyuncu:** her seviyeyi solver çözümünü UI'dan bağımsız `GameSession` üzerinden oynayıp yıldız/kilit akışını doğrular.
- **UI testleri:** ilk açılış → tutorial → seviye → döndür → Run → sonuç → sonraki; günlük; satın alma (StoreKit test);
  geri yükleme; ayarlar.
- **Reklam:** `AdPolicy` unit testleri (her "asla" kuralı, sayaç ve süre eşikleri, reklamsız entitlement); `MockAdService`
  ile UI testleri (ödül bir kez verilir, yüklenemeyen reklamda akış takılmaz, satın alma sonrası geçiş reklamı yok);
  gerçek cihazda Google test reklamlarıyla UMP (AB coğrafyası debug ayarı) + ATT akışı. Kendi gerçek reklamına asla tıklanmaz.
- **Cihaz matrisi (simülatör):** iPhone SE (3. nesil), iPhone 17, iPhone 17 Pro Max, iPad; açık/koyu tema;
  en büyük Dynamic Type; VoiceOver ile tutorial; Reduce Motion.
- **Gerçek cihaz:** Selin'in kendi iPhone'unda Xcode ile doğrudan kurulum ve tam bölüm oynanışı (TestFlight gerekmez).
- **Performans:** ipucu (gömülü çözümlerle) < 5 ms, soğuk açılış < 1 sn, bellek < 100 MB. Solver yalnız CLI/CI'da.

---

## 8. Uygulama adımları (tek seferde, sıralı)

Her adım kendi commit'i; ✅ = bitiş kriteri.

| # | Adım | ✅ Bitiş kriteri |
|---|---|---|
| 1 | Repo, GameCore paketi, iOS proje iskeleti, `.gitignore` | `swift test` + `xcodebuild test` yeşil |
| 2 | Modeller + SimulationEngine (öğe 1–4) + tüm hata tipleri | §1.2'nin her kuralı için test |
| 3 | Renkli ok, makas ok, köprü | Her öğe için test; global döngü tespiti |
| 4 | Validator + olay güdümlü Solver + Scoring + HintProvider | Elle kurulan örneklerde par/çözüm sayısı doğru |
| 5 | SplitMix64 + Generator + QualityFilter + CLI | 1000 seed'de 0 çözümsüz, golden-seed sabit |
| 6 | Board ekranı: Canvas grid, döndürme, Run animasyonu, hata vurgusu, iz, hız, Undo/Reset/İpucu | Bir seviye uçtan uca oynanır |
| 7 | Tutorial + elle seviyeler + `build-campaign` → 150 seviye | CI içerik testi yeşil |
| 8 | Home, bölüm haritası, sonuç, persistence, kilit akışı | Bot oyuncu tüm kampanyayı bitirir |
| 9 | Günlük: `dailies.json`, seri, paylaşım kartı | Uçak modunda çalışır |
| 10 | StoreKit 2: Reklamları Kaldır, Tam Oyun, ipucu paketi, geri yükleme, ipucu ekonomisi | StoreKit test UI testleri yeşil |
| 11 | Reklam: AdMob SDK, `AdService`/`AdPolicy`, ödüllü ipucu, geçiş reklamı, UMP + ATT akışı, `SKAdNetworkItems`, `NSUserTrackingUsageDescription` | Test reklamlarıyla gerçek cihazda akış doğru; AdPolicy testleri yeşil |
| 12 | Tema, ses, haptik, erişilebilirlik, EN+TR+ES yerelleştirme (ATT ön ekranı ve izin metni dahil), uygulama ikonu | Cihaz matrisi kontrolü |
| 13 | fastlane snapshot (ekran görüntüleri), mağaza metinleri ve ekran görüntüleri EN+TR+ES, gizlilik/destek sayfaları (reklam ve veri kullanımı bölümüyle), `app-ads.txt` | Tüm metadata hazır |
| 14 | Release build, arşiv, App Store Connect'e yükleme, incelemeye gönderme | Selin onayıyla gönderilir |

## 9. Yayın kontrol listesi (Selin'in yapması gerekenler)
- Apple Developer üyeliği aktif mi; App Store Connect'te uygulama kaydı, **isim müsaitliği** ("Signal Sort" alınmış olabilir — yedek isim hazır olmalı).
- Bundle ID: `com.selinkaplan.signalsort` (onaylandı), imzalama ekibi.
- IAP ürünlerini App Store Connect'te oluşturmak (ID'leri kod ile aynı), Paid Apps sözleşmesi + vergi/banka bilgileri
  (ödeme bilgileri için bunu senin girmen gerekiyor).
- **AdMob hesabı** (Google hesabınla), uygulamayı AdMob'a ekleme, 2 ad unit (rewarded, interstitial), ödeme/vergi bilgileri
  (ödeme bilgilerini senin girmen gerekiyor), "Privacy & messaging" bölümünde GDPR onay mesajı ve IDFA açıklama mesajı.
- `app-ads.txt`: App Store'daki geliştirici web sitesinin kök alanında yayınlanmalı (ör. `selinkaplan.github.io/app-ads.txt`);
  AdMob uygulamayı bunu doğrulamadan tam gelir vermez.
- App Privacy: Google'ın beyan rehberine göre — Device ID, Product Interaction, Advertising Data, Crash/Performance;
  "Used to Track You" = Device ID (ATT izni verilirse). Yaş derecelendirmesi: 4+ (reklam içerik derecesi G ile).
- Son "Submit for Review" onayı.

## 10. Bilinçli kabul edilen riskler
Dış test olmadan yayınlamak; zorluk eğrisi, ipucu ekonomisi ve fiyatlandırmanın gerçek oyuncu verisi olmadan
tahmine dayanması demek. Azaltma: solver tabanlı zorluk sıralaması, ücretsiz 70 seviye, App Store yorumları ve
App Analytics ile v1.1'de ayar. Reklam sıklığı gerçek veriyle değil kuralla belirlendi: kurallar muhafazakâr,
AdMob sıklık sınırı sunucudan ayarlanabilir. Gelir beklentisi: dokümanın kendi modeline göre 10.000 MAU'da ayda
~$200–$860 brüt; reklam asıl gelirden çok, satın almayan oyuncudan da gelir almanın yoludur. İlk sürüm sonrası güncellemeler için App Store "aşamalı yayın" kullanılabilir.

## 11. Kararlar
- ✅ **Bundle ID:** `com.selinkaplan.signalsort` (17 Ekim 2026 onaylandı). İsim "Signal Sort", klasör `~/signal-sort`.
- ✅ **Diller:** İngilizce (kaynak) + Türkçe + İspanyolca — uygulama metinleri, mağaza metinleri, ekran görüntüleri, gizlilik/destek sayfaları.
- ✅ **Monetizasyon:** Hibrit — ödüllü reklam + kontrollü geçiş reklamı + Reklamları Kaldır / Tam Oyun / ipucu paketi (§3.3).
