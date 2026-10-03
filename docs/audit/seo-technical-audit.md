# Teknik SEO Denetimi

**Tarih:** 2026-10-03. Yöntem: gerçek `website/` dosyaları doğrudan okunarak/grep'lenerek kontrol edildi (Gemini'nin ürettiği genel kontrol listesi, gerçek dosyalarla karşılaştırılıp düzeltildi — Gemini bazı maddeleri "yapılacak" diye önerdi ama bunlar ZATEN YAPILMIŞ, aşağıda ayrıştırıldı).

**Site:** `D:\FinScout\website` (statik HTML, GitHub Pages). Gerçek yayın adresi: **`https://osmaniyeli.github.io/FinScout/`** (TR ana sayfa) + `/en/` (İngilizce). *Not: Gemini'nin ilk taslağı `finscout.moneytrace.app` gibi var olmayan bir alan adı önerdi/kullandı — bu YANLIŞTI, düzeltildi. Gerçek alan adı planı K35 kararında: `finscout.app` almayı denemek, henüz alınmadı.*

## Durum: zaten yapılmış (DOĞRULANDI, kanıtla)

| Madde | Durum | Kanıt |
|---|---|---|
| `robots.txt` | ✅ DOĞRULANDI | `website/robots.txt`: `Allow: /` + sitemap referansı var |
| XML Sitemap | ✅ DOĞRULANDI | `website/sitemap.xml` mevcut, TR+EN+alt sayfalar (gizlilik, hesap-silme, kullanım-şartları, destek) listeli, `changefreq`/`priority` dolu |
| Canonical etiketi | ✅ DOĞRULANDI | `index.html`: `<link rel="canonical" href="https://osmaniyeli.github.io/FinScout/">` |
| Hreflang (TR/EN + x-default) | ✅ DOĞRULANDI | `index.html`'de `hreflang="tr"`, `hreflang="en"`, `hreflang="x-default"` üçü de mevcut; `sitemap.xml`'de de her URL için karşılıklı `xhtml:link rel="alternate" hreflang` satırları var |
| HTTPS | ✅ DOĞRULANDI | GitHub Pages varsayılan olarak HTTPS zorunlu kılar |
| Mobil kullanılabilirlik | DOĞRULANMADI (araç yok) | `artifact-design` kurallarına göre responsive yazıldığı biliniyor (bu oturumun web sitesi işi sırasında doğrulanmıştı) ama bu denetimde Lighthouse/PageSpeed gibi bir araçla YENİDEN ÖLÇÜLMEDİ |

## Gerçek eksik (GİDERİLMEMİŞ — bu denetim kod yazmıyor, yalnız tespit)

**Bulgu SEO-01 (P2):** **Yapılandırılmış veri (schema.org) hiç yok.** `grep -c "schema.org" website/index.html` → **0**. Öneri: `SoftwareApplication` türü (`applicationCategory: "FinanceApplication"`, `operatingSystem: "ANDROID"`, fiyatlandırma için `Offer`) eklenmesi, Google'ın mağaza/uygulama zengin sonuçlarında görünürlüğü artırabilir. Küçük, geri dönüşü kolay bir HTML değişikliği — ayrı bir iş olarak yapılabilir, bu denetimin kapsamında UYGULANMADI.

**Bulgu SEO-02 (P3):** Core Web Vitals (LCP/CLS/INP) hiç ÖLÇÜLMEDİ — bu ortamda Lighthouse/PageSpeed Insights çalıştıracak bir araç yok (önceki oturumlarda da headless tarayıcı doğrulaması güvenilir çalışmadığı not edilmiş, bkz. proje hafızası). **DOĞRULANMADI** olarak işaretleniyor, "iyi" ya da "kötü" diye uydurulmuyor. Öneri: PageSpeed Insights'a siteyi manuel yapıştırıp kullanıcının kendisinin bir kez bakması (ücretsiz, hesap gerektirmez).

**Bulgu SEO-03 (P3):** E-E-A-T/güvenilirlik sinyalleri kısmen var (gizlilik politikası, hesap silme sayfası, kullanım şartları hepsi linkli ve sitemap'te) ama sitede açık bir "geliştirici hakkında" / şeffaflık sayfası yok. Düşük öncelik — finans uygulamaları için faydalı olur ama bu aşamada (kapalı test) acil değil.

## Sonuç

Web sitesinin teknik SEO temeli **beklenenden daha iyi durumda** — önceki bir oturumda website yeniden kurulurken (miralife.app replikasyonu, commit cbd9830) bu temel işler zaten doğru yapılmış. Gerçek, somut eksik tek madde: **yapılandırılmış veri (schema.org)**. Diğer her şey ya zaten var ya da bu ortamda ölçülemiyor (uydurulmadı).

---
*Kaynak: `website/robots.txt`, `website/sitemap.xml`, `website/index.html` (grep ile doğrudan okundu, 2026-10-03).*
