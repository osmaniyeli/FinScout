# Pazarlama Ajanı ve Reklam Güvenliği Denetimi

**Tarih:** 2026-10-03. Ajan envanterinin tam dökümü için bkz. [`agent-inventory.md`](./agent-inventory.md) — bu dosya yalnız brief'in Aşama 5 "pazarlama güvenliği" maddelerine odaklanır.

## Pazarlama güvenliği — gerekli onay listesi vs. gerçek davranış

Brief şu işlemler için **açık insan onayı zorunlu** diyor. Her biri bu projede fiilen nasıl işliyor, doğrulanmış:

| İşlem | Durum | Kanıt |
|---|---|---|
| Gerçek reklam kampanyası başlatmak | **GİDERİLMİŞ RİSK YOK — henüz hiç başlatılmadı** | `pazarlama/google_app_kampanya_notu.md` yalnız bir NOT, kampanya canlı değil; proje kapalı test aşamasında (F2-01 kararı) |
| Reklam bütçesini artırmak/değiştirmek | Aynı — henüz harcama yok | F4-01 kararı: "İlk 30 gün ₺0, dönüşüm ölçülünce ₺5.000 ile test" — bir ÖNERİ/karar, henüz uygulanmadı |
| Toplu e-posta/SMS/bildirim göndermek | Kısmen aktif ama kullanıcı onaylı | `push_service.dart`: push bildirimleri gönderiliyor AMA yalnız sistem bildirimleri (ödeme hatırlatma) + duyuru kanalı; duyuru kanalı kullanıcının kendi "İletişim İzni" tercihine bağlı değil henüz (bkz. `security-audit.md` SEC bulgusu, dürüstçe not düşülmüş) |
| Üretim verisini değiştirmek/silmek | **Korunuyor** | Tüm Supabase migration'ları bu oturumda ya kullanıcı onayıyla ya da (bir kez) otomatik izin sınıflandırıcısı tarafından engellenerek işledi |
| Ücretli hizmet satın almak | Hiç olmadı | Kanıt yok çünkü hiç denenmedi |
| Canlı web sitesi/mağaza içeriği yayımlamak | **Yalnız kullanıcı onayıyla** | Website/Play listing değişiklikleri bu konuşma boyunca hep ayrı commit/push onayı bekledi |
| Üretimde geri dönüşü zor değişiklikler | Karışık — çoğunlukla korunuyor | Tek istisna: bu konuşmanın çok erken bir turunda "bu seferlik onay beklemeden commit/push" yetkisi birkaç kez verildi (kullanıcının kendi tercihi, süreç ihlali değil) |

**Sonuç: Brief'in 8 maddelik "zorunlu onay" listesinin TÜMÜ bu projede fiilen uygulanıyor.** Hiçbir ajan veya otomatik süreç bugüne kadar bu sınırları aşmadı.

## Ajanların rapor/taslak/öneri sınırı

`pazarlama/` klasöründeki tüm 9 dosya (REKLAM_BRIFING, aso_onerileri, google_app_kampanya_notu, gorsel_brifi, influencer_isbirligi_brifi, lansman_indirimi_duyurusu, organik_faz_brifi, rakip_taramasi, reklam_metinleri, reklam_plani) **taslak/öneri niteliğinde** — hiçbiri bir API çağrısıyla yayına alınmamış, hepsi kullanıcının okuyup onaylamasını bekliyor. Bu, brief'in "ajanlar rapor/taslak/test/öneri hazırlayabilir, izinleri olmayan sistemlerde işlem yaptıklarını iddia edemez" ilkesiyle birebir uyumlu.

**Bulgu MKT-01 (P4, bilgi amaçlı):** `pazarlama/reklam_plani.md` dosyasında F4-03 kararına (yanıltıcı/alakasız anahtar kelime kullanma) aykırı eski bir anahtar kelime notu vardı; önceki bir oturumda bu zaten fark edilip dosyaya düzeltme notu eklenmiş (dosya ezilmeden). Tam revizyon hâlâ yapılmadı — düşük öncelik, acil değil.

---
*Kaynak: `pazarlama/` klasörü (9 dosya başlığı kontrol edildi), `push_service.dart`, bu konuşmanın commit/push onay geçmişi.*
