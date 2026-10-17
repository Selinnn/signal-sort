# App Store Connect – App Privacy yanıtları (taslak)

Uygulamanın kendi kodu veri toplamaz ve sunucusu yoktur. Toplanan veriler yalnız **Google Mobile Ads SDK (AdMob)**
kaynaklıdır. Aşağıdaki tablo Google'ın "Apple App Store veri açıklaması" rehberine göre hazırlandı; göndermeden önce
Google'ın güncel rehberiyle karşılaştırılmalı: https://developers.google.com/admob/ios/privacy/data-disclosure

| Veri türü | Amaç | Kullanıcıya bağlı mı | İzleme için mi |
|---|---|---|---|
| Konum → Yaklaşık konum (IP'den) | Üçüncü taraf reklam, Analiz | Hayır | Evet |
| Tanımlayıcılar → Cihaz kimliği (IDFA yalnız ATT izni ile, IDFV) | Üçüncü taraf reklam, Analiz | Hayır | Evet |
| Kullanım verisi → Ürün etkileşimi | Üçüncü taraf reklam, Analiz | Hayır | Evet |
| Kullanım verisi → Reklam verisi | Üçüncü taraf reklam, Analiz | Hayır | Evet |
| Tanılama → Çökme verisi, Performans verisi, Diğer tanılama | Analiz | Hayır | Hayır |

- "Data Used to Track You": Cihaz kimliği, Yaklaşık konum, Ürün etkileşimi, Reklam verisi (ATT izni verildiğinde).
- Satın alımlar Apple tarafından işlenir; uygulama ödeme veya kişi bilgisi toplamaz.
- Yaş derecelendirmesi: 4+ (reklam içerik derecesi AdMob'da **G** olarak ayarlanmalı). "Made for Kids" seçilmez.
- Şifreleme beyanı: `ITSAppUsesNonExemptEncryption = NO` (Info.plist'te).
