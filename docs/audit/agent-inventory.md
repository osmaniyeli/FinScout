# Ajan Envanteri ve Pazarlama Ajanları Denetimi

**Tarih:** 2026-10-03 · **Yöntem:** `.claude/agents/*.md` doğrudan okundu (uydurulmadı); değerlendirme Gemini'ye (`ask_gemini.py`) danışılıp Claude tarafından gözden geçirilip düzeltildi (K40 kararı: taslak/araştırma Gemini, doğrulama Claude).

## Gerçek ajan envanteri (4 adet, hepsi doğrulandı — dosyalar gerçekten var)

| Ajan | Dosya | Amaç (description alanından) |
|---|---|---|
| `finscout-arastirma` | `.claude/agents/finscout-arastirma.md` | Rakip analizi, kullanıcı yorumları/şikâyetleri, sektör en iyi uygulamaları, tasarım araçları/platformları, ücretli entegrasyon araştırması (web kaynaklı) |
| `finscout-finans` | `.claude/agents/finscout-finans.md` | Türk bankacılık/bordro terimleri, vergi hesapları (BSMV/KKDF/MTV/KDV/gelir-damga vergisi/SGK), gösterilen finansal bilginin doğruluğu, KVKK/BDDK dili, abonelik fiyatlaması |
| `finscout-pazarlama` | `.claude/agents/finscout-pazarlama.md` | Google Play ASO, konumlandırma, mesajlaşma, kullanıcı edinme, dönüşüm, elde tutma |
| `finscout-tasarim` | `.claude/agents/finscout-tasarim.md` | UI/UX denetimi, tasarım sistemi, mağaza görselleri/reklam kreatifleri, "yapay zekâ yapımı gibi görünme" riski |

**Girdi/çıktı:** Hepsi Claude Code içi alt-ajan (Task tool ile çağrılır); girdi doğal dil görev tanımı, çıktı metin/öneri/taslak. **Hiçbiri canlı bir sisteme otomatik erişime sahip değil** — her biri genel amaçlı Claude Code araç setini kullanır (dosya okuma/yazma, web araştırması, bash), ama bu oturumun kendi kuralları (CLAUDE.md, bu denetimin "insan onayı" ilkesi) dışında ayrı bir yetki/izin katmanları YOK. Yani teknik olarak `finscout-pazarlama` çağrıldığında dosya yazabilir veya komut çalıştırabilir — pratikte kapsamı "öneri/metin üretimi" ile sınırlı tutulması tamamen görev tanımına ve çağıran oturumun disiplinine bağlı, ayrı bir teknik izin sınırlaması yok. **Bulgu AGT-01 (P2):** Bu 4 ajanın hiçbirinde "şunu YAPMA" (commit atma, dış API'ye yazma, para harcama) şeklinde açık bir kısıt maddesi yok; mevcut disiplin bu oturumdaki (CLAUDE.md + konuşma kuralları) genel ilkelere dayanıyor, ajan tanımının kendisine gömülü değil. Öneri: her ajan dosyasına "Bu ajan hiçbir zaman commit/push yapmaz, canlı reklam/satın alma işlemi başlatmaz, yalnız öneri üretir" gibi tek satırlık bir sınır eklenmesi, ajanın kendi kapsamını daha sağlam hale getirir.

## Görev çakışması değerlendirmesi

`finscout-arastirma` (veri toplama: rakip/kullanıcı/sektör) ile `finscout-pazarlama` (bu veriyi ASO/konumlandırmaya çevirme) arasındaki sınır **açıklamalarda zaten net**: biri "araştırma", diğeri "uygulama/stratejiye çevirme". Pratikte önemli olan, bir göreve HANGİ ajanın çağrılacağına ben (oturumu yürüten) karar veriyorum — ajan tanımları birbirini çağırmıyor, iç içe geçmiyor. **Bulgu AGT-02 (P3, kabul edilebilir risk):** Çakışma riski düşük, gerçek risk ajanları YANLIŞ görev için çağırmak (ör. ASO metni için arastirma ajanını çağırıp kaynaksız/doğrulanmamış bir metin almak) — bu bir süreç disiplini, ajan tanımı sorunu değil.

## Eksik rol değerlendirmesi (Gemini önerisi, Claude tarafından elenmiş)

Gemini iki yeni ajan önerdi: `finscout-analytics` (dönüşüm/hata oranı analizi) ve `finscout-compliance` (KVKK/BDDK/Play politika denetimi). **Claude değerlendirmesi:** İkisi de projenin mevcut ölçeğinde (kapalı test, tek geliştirici) AYRI BİR AJAN olarak gerekli değil — `finscout-finans` zaten KVKK/BDDK dilini kapsıyor (description'da açıkça yazıyor), analitik ise şu an elle (Play Console + Supabase sorguları) yapılacak kadar küçük (bkz. F2-24 kararı: "Yalnız Play Console + sunucudaki kota/abonelik sayıları"). **Öneri: şimdilik yeni ajan AÇMA**, ölçek büyüyünce (gerçek kullanıcı sayısı/veri hacmi artınca) tekrar değerlendir.

## İnsan onayı gerektiren işlemler — doğrulanmış liste

Mevcut proje genelinde (bu oturumun gözlemlediği davranış + CLAUDE.md/memory kuralları) şu işlemler için insan onayı FİİLEN uygulanıyor:
- Git commit/push (bu konuşma boyunca defalarca doğrulandı — yalnız kullanıcı "commit et"/"yap" dediğinde yapılıyor).
- Supabase canlı şemaya migration uygulama (bu konuşmada bir kez otomatik izin sınıflandırıcısı tarafından fiilen ENGELLENDİ — "Modify Shared Resources").
- Play Console/mağaza metni, fiyat, reklam kampanyası, bütçe değişikliği — bugüne kadar hiçbiri otomatik yapılmadı, hepsi öneri/taslak aşamasında kaldı (bkz. `pazarlama/` klasöründeki taslaklar).

**Bulgu AGT-03 (P2):** Bu onay disiplini CLAUDE.md'de VE konuşma geçmişinde var ama **tek bir merkezi "yasak işlemler" listesi olarak yazılı değil** — dağınık (bazı kurallar memory'de, bazı kurallar bu konuşmanın kendi talimatlarında). Öneri: `CLAUDE.md`'ye kısa bir "İnsan Onayı Gerektiren İşlemler" bölümü eklenmesi (bu denetimin kapsamı dışında, kod dosyası değil — ayrı bir karar/iş olarak bırakıldı, KENDİM DEĞİŞTİRMEDİM).

## Pazarlama ajanı — ek değerlendirme (finscout-pazarlama)

`finscout-pazarlama`'nın description'ı "ASO, konumlandırma, mesajlaşma, kullanıcı edinme, dönüşüm, elde tutma" kapsıyor — brief'in istediği "SEO ve içerik", "ücretli reklam", "analitik ve dönüşüm optimizasyonu", "rekabet ve pazar araştırması" alt-görevlerinin çoğunu zımnen kapsıyor (ücretli reklam → "kullanıcı edinme"; SEO/içerik → kısmen, web sitesi SEO'su net atanmamış). **Bulgu AGT-04 (P3):** Web sitesi teknik SEO'su hiçbir ajanın net sorumluluğunda değil (ne arastirma ne pazarlama'nın description'ında "web sitesi"/"SEO" kelimesi geçiyor). Pratikte bu işi bu denetimde doğrudan ben (ana oturum) yaptım. Öneri: `finscout-pazarlama`'nın description'ına "web sitesi SEO'su" eklenebilir — küçük bir netlik iyileştirmesi, acil değil.

---
*Kaynak: `.claude/agents/*.md` (4 dosya, tam okundu), bu konuşmanın geçmişi (commit/push onay deseni gözlemi), `pazarlama/` klasörü (taslak-only kanıtı).*
