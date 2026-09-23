# Play Console metinleri — Paraİz 3.6.0 (versionCode 4)

Taslak: Gemini (API köprüsü). İnceleme ve düzeltme: Claude. Karakter sayıları ölçüldü.

## 1. Sürüm notları — tr-TR (395 / 500 karakter)

```
• Banka ekstresi ve bordro okuma motoru yenilendi; harcama ve kategoriler otomatik tespit ediliyor.
• Cihaz içi Türkçe sesli harcama girişi eklendi.
• Fatura, abonelik ve kart son ödeme günü bildirim hatırlatıcıları eklendi.
• Parmak izi/yüz tanıma ve PIN güvenliği artırıldı.
• Google Play abonelik geçişleri ve plan yönetimi iyileştirildi.
• Hızlı giriş ve transfer analiz hataları düzeltildi.
```

## 2. Release notes — en-US (413 / 500 karakter)

```
• Rebuilt bank statement parser with automatic transaction and category detection.
• Added offline on-device voice expense entry (Turkish).
• Added notification reminders for bills, subscriptions, and card due dates.
• Enhanced fingerprint/face unlock and PIN security.
• Improved Google Play subscription management and transitions.
• Fixed quick entry saving issues and duplicate transfer counting in analytics.
```

## 3. Veri güvenliği (Data safety) formu

Play tanımında yalnızca **cihazdan dışarı gönderilen** veri "toplanan veri" sayılır.

| Soru | Cevap | Dayanak |
|---|---|---|
| Uygulama zorunlu veri türlerinden herhangi birini topluyor veya paylaşıyor mu? | **Hayır** | Gizlilik politikası §1–2: sunucu yok, veriler yalnızca cihazda |
| Veriler aktarım sırasında şifreleniyor mu? | Soru sorulmaz (toplama yok) | — |
| Kullanıcı verilerinin silinmesini isteyebilir mi? | **Evet** — uygulama içi *Ayarlar > Verileri Sıfırla* veya uygulamayı kaldırma | §5, `DATA_DELETION.md` |

Veri türleri tek tek (hepsi **toplanmıyor / paylaşılmıyor**):

- **Finansal bilgi:** İşlem kayıtları yalnızca cihazdaki SQLite'ta. Abonelik ödemesini Google Play Billing işler; ödeme bilgisi uygulamaya ulaşmaz (§4).
- **Kişisel bilgi (e-posta dahil):** Bülten aboneliği yalnızca cihazdaki e-posta uygulamasını `mailto:` ile açar; e-posta adresi uygulama tarafından hiçbir yere gönderilmez (kodla doğrulandı: `newsletter_subscription_sheet.dart`).
- **Ses:** Yalnızca cihaz içi tanıma (`onDevice: true`), kayıt ve gönderim yok (§3).
- **Uygulama etkinliği / cihaz kimlikleri:** Analitik, reklam veya takip SDK'sı yok (§4).

> Not: Uygulama herkese açık kur/haber sunucularına istek atar; bu isteklerde kullanıcı verisi gönderilmez.

## 4. Hassas izin beyanı

**Gerekmez.** `RECORD_AUDIO` ve `POST_NOTIFICATIONS`, Play Console'un izin beyan formuna tabi değildir
(o form SMS/arama kaydı, tüm dosyalara erişim, arka plan konumu, tam zamanlı alarm gibi izinler içindir;
uygulama tam zamanlı alarm izni **istemiyor**, hatırlatıcılar `inexactAllowWhileIdle` ile zamanlanıyor).
İzin açıklaması kullanıcıya uygulama içinde izin istenirken gösterilir.
