# 📊 Paraİz (MoneyTrace) — Büyüme Metrikleri & Remote Config Rehberi

Bu doküman; **Paraİz (MoneyTrace)** platformunun büyüme hızını, birim ekonomisini (Unit Economics), gelir kârlılığını (LTV/CAC) ölçümlemek ve **Web Yönetici Paneli** üzerinden uygulama marketlerine yeni sürüm göndermeden canlı parametreleri anında yönetmek için hazırlanan operasyonel büyüme kılavuzudur.

---

## 1. FinTech Büyüme & Birim Ekonomi KPI'ları (Unit Economics)

Paraİz'in karlı ve sürdürülebilir bir şekilde büyümesi için günlük/haftalık olarak takip edilmesi gereken temel metrikler ve hedefler:

```
                      ┌────────────────────────┐
                      │    LTV / CAC > 3.0x    │  ◄── Altın Büyüme Kuralı
                      └───────────┬────────────┘
                                  │
         ┌────────────────────────┴────────────────────────┐
         ▼                                                 ▼
┌──────────────────┐                              ┌──────────────────┐
│ CAC < ₺60 - ₺80  │                              │    LTV > ₺350    │
│ (Abone Edinme)   │                              │ (Yaşam Boyu Değeri)
└──────────────────┘                              └──────────────────┘
```

| Metrik | Açıklama | Formül / Hesaplama | Hedef Değer |
| :--- | :--- | :--- | :---: |
| **CPI (Cost Per Install)** | 1 tekil uygulama indirme maliyeti | `Toplam Reklam Harcaması / İndirme Sayısı` | **< ₺8 – ₺15** |
| **CAC (Cost to Acquire Customer)** | 1 ücretli Premium abone edinme maliyeti | `Pazarlama Harcaması / Yeni Premium Abone` | **< ₺60 – ₺85** |
| **LTV (Lifetime Value)** | Bir abonenin uygulamada kaldığı sürece kazandırdığı ciro | `(Aylık Ücret × Ortalama Kalma Süresi) + Reklam Geliri` | **> ₺350 – ₺500** |
| **LTV / CAC Oranı** | Büyüme kârlılık çarpanı | `LTV / CAC` | **≥ 3.0x (Sağlıklı)** |
| **ROAS (Return on Ad Spend)** | Reklam harcamasının ciroya geri dönüşü | `Toplam Elde Edilen Gelir / Reklam Harcaması` | **≥ 250% (2.5x)** |
| **D1 / D7 / D30 Retention** | 1, 7 ve 30 gün sonra uygulamaya dönme oranı | `Geri Dönen Kullanıcı / İndiren Kullanıcı` | **D1 > %42, D7 > %24, D30 > %15** |
| **Paywall CVR** | Ödeme ekranını görüp abone olanların oranı | `Satın Alma / Paywall Görüntüleme` | **%4.5 – %7.0** |

---

## 2. Web Yönetici Paneli & Canlı Uzaktan Kontrol (Remote Config)

Paraİz, `Web_Yonetici_Paneli/remote_config.json` dosyası üzerinden doğrudan mobil uygulamaların davranışını **Google Play veya App Store'a güncelleme göndermeden** gerçek zamanlı olarak yönetir.

### 🎛️ 2.1. Yönetilen Temel Parametreler ve Stratejik Rolü

```json
{
  "clean_data_mode": true,
  "theme": {
    "primary_hex": "#0052FF",
    "income_hex": "#00D084",
    "expense_hex": "#FF2D55",
    "palette_name": "Elektrik Mavisi (Standart)",
    "dark_mode": false
  },
  "modules": {
    "dashboard_summary": { "enabled": true, "disabled_countries": [], "title": "Özellik Bakımda" },
    "statement_upload": { "enabled": true, "disabled_countries": [] },
    "cashflow_projection": { "enabled": true, "disabled_countries": [] },
    "goals_module": { "enabled": true, "disabled_countries": [] },
    "assets_portfolio": { "enabled": true, "disabled_countries": [] }
  }
}
```

### ⚡ 2.2. Büyüme & Reklam Yöneticisinin Panel Operasyonları:
1. **Pazarlama Kampanyaları Renk & Tema Uyumu:** Özel dönemlerde (Yılbaşı, Kara Cuma vb.) tema renkleri (`primary_hex`) ve karşılama banner'ları tek tıkla güncellenir.
2. **Kriz ve Bakım Yönetimi:** Herhangi bir bankanın ekstre şablonunda değişiklik olduğunda, o bankanın parser modülü bakım moduna (`enabled: false`) alınarak kullanıcıya şık bir bildirim mesajı gösterilir; uygulama çökmesi önlenir.
3. **Ülke Bazlı Özellik Segmentasyonu:** `disabled_countries` listesi kullanılarak özellikler kademeli pazar lansmanına göre açılıp kapatılır.

---

## 3. Kullanıcı Tutundurma (Retention) & Churn Önleme Mekanizmaları

Kişisel finans uygulamalarında en büyük tehlike kullanıcının ilk 3 günden sonra harcama girmeyi unutmasıdır. Paraİz'in yerleşik 3 tutundurma kalkanı:

### 🏆 3.1. 30 Günlük Alışkanlık Serisi (Daily Streak & Confetti)
* Kullanıcı her gün uygulamayı açıp bütçesine göz attığında serisi artar (`Streak: 7 Gün`).
* Belirli eşiklerde (3, 7, 14, 30 gün) Shakuro yay fiziğiyle çalışan konfeti kutlaması patlar ve kullanıcıda finansal kontrol tatmini yaratır.

### 🏝️ 3.2. Yüzen Dynamic Island Kapsülü
* Ekranın üst kısmında maksimum %25 yer kaplayan kapsül bildirim:
  - *"Yaklaşan Fatura: Yarın Elektrik ₺420 ödenecek."*
  - *"Tebrikler! Bu hafta bütçenizi %12 daha az harcayarak kapattınız."*
* Kullanıcıyı agresif bildirimlerle boğmadan, arayüzün içinde organik bir değer sunar.

### 📅 3.3. Ay Başı ve Ay Sonu Finansal Kapanış Rutini
* Her ayın 1'inde: *"Yeni ayın bütçesi hazırlandı. 30 günlük nakit akışınızı inceleyin."*
* Her ayın son gününde: *"Aylık harcama karneniz hazır. Hangi kategoride tasarruf ettiniz?"*
