# SEO/Büyüme Ölçümleme Planı

**Tarih:** 2026-10-03.

## Mevcut ölçümleme altyapısı (DOĞRULANDI)

F2-23/F2-24 kararları zaten ölçümleme kapsamını netleştirmiş: **"Yalnız Play Console Android vitals (ek SDK yok)"** ve **"Yalnız Play Console + sunucudaki kota/abonelik sayıları (kişi bazlı değil, toplam)"**. Yani proje BİLİNÇLİ OLARAK üçüncü taraf analitik SDK'sı (Firebase Analytics, Mixpanel vb.) kullanmıyor — bu `security-audit.md`/`privacy-review.md` bulgularıyla da tutarlı (PII'nin analitik sistemine gitmemesi zaten yapısal olarak garanti, çünkü böyle bir sistem yok).

F2-23'ün notunda ayrıca şu da var: *"Uygulamadaki tüm hatalarını takip için bunu yönetim paneline de ekle. Giriş çıkış, tıklama notlarına bakmak istiyorum."* — bu, [[admin-panel-user-tracking]] hafıza notunda zaten kayıtlı, henüz YAPILMADI (ayrı, büyük bir iş — admin panel CMS'inin devamı).

## Web sitesi ölçümleme (F4-10 kararı)

F4-10: **"Çerezsiz, kişisel veri toplamayan basit sayaç."** Bu denetimde `website/` içinde böyle bir sayaç script'i aranmadı/doğrulanmadı — **DOĞRULANMADI**, ayrı bir kontrol gerekir.

## Önerilen minimal huni (brief'in istediği olaylar, mevcut veri kaynaklarıyla eşlenmiş)

| Olay | Mevcut veri kaynağı | Durum |
|---|---|---|
| Kayıt tamamlandı | Supabase `auth.users` | DOĞRULANDI (tablo var) |
| İlk ekstre yüklendi | `document_uploads`/`upload_consumptions` | DOĞRULANDI (tablo var, kota sayımı için zaten kullanılıyor) |
| Ekstre başarıyla ayrıştırıldı | Yerel SQLite, sunucuya gitmiyor | Sunucu tarafında GÖRÜNMÜYOR — yalnız kota düşümü (ayrıştırma BAŞARILI olursa düşülüyor, dolaylı sinyal) |
| Abonelik/satın alma | `subscriptions` tablosu | DOĞRULANDI |
| Hata/başarısız yükleme | YOK | **Bulgu SEO-M-01 (P3):** ayrıştırma hataları yalnız cihazda (`debugPrint`), sunucuya hiç gitmiyor — kaç kullanıcının hangi bankada/hangi hatada takıldığını bilme imkânı şu an yok. F2-23'ün notuyla birebir örtüşen bir boşluk. |

## Claude sentezi

Mevcut "yalnız Play Console + sunucu toplamları" ölçümleme ilkesi gizlilik açısından DOĞRU bir tercih (fazla veri toplamamak). Ama bu, **ayrıştırma hatalarının görünürlüğü** konusunda gerçek bir kör nokta yaratıyor — kullanıcı F2-23 notunda bunu zaten fark etmiş. Öneri (uygulanmadı, kapsam dışı): yalnız HATA TÜRÜNÜ ve BANKA ADINI (işlem içeriği/tutar DEĞİL) içeren minimal, PII içermeyen bir hata-sayacı tablosu — mevcut `app_content`/`document_uploads` desenine benzer, küçük bir iş. Bu [[admin-panel-user-tracking]] hafıza notundaki işin bir parçası olarak ele alınmalı, ayrı bir yeni iş açılmadı.

---
*Kaynak: F2-23/F2-24/F4-10 kararları, Supabase şema (`list_tables` ile daha önce doğrulanmış), proje hafızası.*
