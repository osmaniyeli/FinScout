# 💎 Paraİz (MoneyTrace) — Monetizasyon & Reklam Stratejisi

Bu strateji belgesi; **Paraİz**'in yüksek kullanıcı güvenini (%100 Cihaz İçi / Sıfır-Bilgi) korurken, sürdürülebilir ve ölçeklenebilir bir gelir modeli (ARR / MRR) yaratması için tasarlanan **Hibrit Monetizasyon Mimarisi**'ni (Freemium + IAP Abonelik + Gizlilik Dostu Ödüllü Reklam) detaylandırır.

---

## 1. Monetizasyon Matrisi: Free vs. Premium

Paraİz, kullanıcıya değerini kanıtlayan ancak derin analitik ve sınırsız otomasyon için Premium'a geçişi teşvik eden adil bir **Freemium** modeline sahiptir.

| Özellik / Modül | Ücretsiz (Free Tier) | Bireysel Premium (`₺89,99/ay` veya `₺699/yıl`) | Aile Paketi (`₺1.199/yıl` - 4 Kişi) |
| :--- | :---: | :---: | :---: |
| **Manuel Gelir/Gider Girişi** | Sınırsız | Sınırsız | Sınırsız |
| **PDF/Excel Ekstre Ayrıştırma** | Ayda 2 Ekstre *(+1 Ödüllü Reklamla)* | **Sınırsız** | **Sınırsız (Her Üye İçin)** |
| **Banka Destekleri** | Temel Bankalar | **Tüm Bankalar + Maaş Bordroları** | **Tüm Bankalar + Maaş Bordroları** |
| **Nakit Akışı Projeksiyonu** | 7 Günlük Görünüm | **12 Aylık Dinamik Simülasyon** | **12 Aylık Dinamik Simülasyon** |
| **Elektrikli Araç Tasarruf Zekası** | Önizleme (Temel) | **Tam Karşılaştırma & Senaryolar** | **Tam Karşılaştırma & Senaryolar** |
| **KDV & Vergi Ayrıştırma** | Kapalı | **Açık (Otomatik Matrah Hesabı)** | **Açık (Otomatik Matrah Hesabı)** |
| **Dışa Aktarma (Excel / CSV)** | Yalnızca 1 Aylık | **Sınırsız UTF-8 BOM CSV / JSON** | **Sınırsız UTF-8 BOM CSV / JSON** |
| **Reklam Deneyimi** | Ödüllü & Doğal Kartlar | **%100 REKLAMSIZ** | **%100 REKLAMSIZ** |
| **Kullanıcı Sayısı** | 1 Cihaz | 1 Kullanıcı (Tüm Cihazları) | **4 Bağımsız Aile Üyesi** |

---

## 2. Gizlilik Uyumlu Reklam Mimarisi (Privacy-First Ad Model)

> [!IMPORTANT]
> Paraİz bir kişisel finans uygulamasıdır. Finans uygulamalarında beklenmedik anlarda çıkan tam ekran pop-up reklamlar (Interstitial) kullanıcıda güvensizlik yaratır ve silme (churn) oranını fırlatır. Bu nedenle yalnızca aşağıdaki **2 zarif reklam modeli** uygulanmalıdır:

### 🎬 2.1. Ödüllü Video Reklamlar (Rewarded Ads) — "Değer Karşılığı Erişim"
* **Kullanım Senaryosu:** Ücretsiz kullanıcının aylık 2 adet olan ekstre kotası bittiğinde:
  - *"Bu ayki ücretsiz ekstre kotanız doldu. Sınırsız ayrıştırma için Premium'a geçebilir veya 1 ekstre daha ayrıştırmak için kısa bir sponsorlu video izleyebilirsiniz."*
* **Avantajı:** 
  - Kullanıcı reklamı kendi isteğiyle başlatır.
  - Finans sektöründe ödüllü video eCPM değerleri çok yüksektir (Türkiye'de $2.50 – $6.00, Avrupa/ABD'de $18.00 – $35.00).
  - Kullanıcı deneyimini baltalamaz, rıza temellidir.

### 📰 2.2. Doğal Finans Sponsorlukları (Native In-Feed Ads)
* **Kullanım Senaryosu:** Piyasalar veya Kampanyalar sekmesinde, bankaların mevduat faizi, avantajlı kredi veya kart aidatsız ürün önerileri doğal kart tasarımında sunulur.
* **Görsel Standart:** Shakuro tasarım diline uygun, kenarları yuvarlatılmış (14dp), siluet ikonlu ve üzerinde açıkça *"Sponsorlu Finans Bülteni"* etiketi taşıyan şık kartlar.

---

## 3. In-App Purchase (IAP) Paketleme & Fiyatlandırma Psikolojisi

Uygulamanın `SubscriptionService` mimarisinde Google Play Store ve App Store SKU'ları:

```dart
// Aktif Paket Tanımları
static const String individualMonthlySku = 'paraiz_individual_monthly'; // ₺89,99 / Ay
static const String individualAnnualSku  = 'paraiz_individual_annual';  // ₺699,99 / Yıl (%35 İndirimli)
static const String familyAnnualSku      = 'paraiz_family_annual_4p';   // ₺1.199,99 / Yıl (Kişi Başı ₺25/Ay)
```

### 🧠 Satış Psikolojisi ve Paywall İkna Tetikleyicileri (Micro-Copy)

1. **Yıllık Paket İkna Mesajı (Fiyat Sabitleme & İndirim):**
   - *"Günde sadece ₺1,90'a (bir çay parasına) tüm ekstrelerinizi otomatik analiz edin, kart aidatlarını tek tıkla geri isteyin!"*
2. **Kişi Başına Bölme (Aile Paketi):**
   - *"4 kişilik aile bütçenizi yönetin. Kişi başı ayda sadece ₺25!"*
3. **Kaybetme Korkusu (FOMO & Loss Aversion):**
   - Ekstre ayrıştırıldığında kart aidatı tespit edilmişse:
   - *"Bu ekstrede ₺750 kart aidatı tespit edildi. Paraİz Pro'ya geçerek hazır dilekçe ile aidatınızı geri alın, aboneliğiniz ilk günden kendini amorti etsin!"*

---

## 4. Paywall (Ödeme Duvarı) Tetikleme Noktaları (Triggers)

Kullanıcının Pro sürüme yükseltmesini sağlayan en verimli 4 temas noktası:

```
[İşlem Akışı] ────► [Tetikleyici Anı] ────► [Paywall Sunumu]
      │
      ├─► 3. Ekstre Yükleme Denemesi ───► "Sınırsız OCR & Ekstre Çözücü"
      ├─► 12 Aylık Projeksiyon Tıklaması ─► "Gelecek 1 Yılın Bakiye Haritası"
      ├─► Araç Tasarruf Karşılaştırması ─► "Yıllık ₺40.000 Akaryakıt Tasarrufu"
      └─► Excel (CSV) İhracı ────────────► "Tüm Verileriniz Masaüstünüzde"
```

---

## 5. Teknik Mimari: `SubscriptionService` & Reklam Entegrasyon Kuralı

AdMob / Reklam SDK'sı eklenirken uygulanması zorunlu tek satırlık kural:

```dart
// Reklam gösterme karar motoru
bool shouldShowAd() {
  // Eğer kullanıcı Premium abonesiyse ASLA reklam gösterilmez
  if (SubscriptionService.instance.isPremium) {
    return false;
  }
  // Remote Config üzerinden reklamlar global olarak kapatılmışsa gösterilmez
  if (!RemoteConfigService.instance.isAdEnabled) {
    return false;
  }
  return true;
}
```

Bu kural; kullanıcı aboneliği başlattığı milisaniyede uygulamanın tüm reklam birimlerini bellekten düşürür ve sıfır gecikmeli kusursuz bir Pro deneyimi sağlar.
