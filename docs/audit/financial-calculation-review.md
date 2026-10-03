# FinScout — Finansal Hesaplama Doğruluğu İncelemesi (Uçtan uca denetim 2/5)

Tarih: 2026-10-03 · Kapsam: `moneytrace/lib/core/utils/currency_normalizer.dart`, `lib/core/parser/**`, `lib/core/database/repositories/transaction_repository.dart`, `lib/features/{fees,tax_analytics,cashflow_projection,analysis,assets_portfolio,goals,quick_entry}`.
Yöntem: kaynak okuma, `grep` (double/SUM/round), mevcut testler, geçici prob testi (sonuçlar aşağıda alıntılı; prob dosyası silindi). Bu görevde finansal mantık dosyalarında **kod değişikliği yapılmadı** (düzenleme kapsamı dışında); bulgular öneridir.

Durum etiketleri: DOĞRULANDI / BAŞARISIZ / GİDERİLDİ / DOĞRULANMADI / KAPSAM DIŞI / KABUL EDİLEN RİSK.

## Özet tablo

| Kimlik | Başlık | Öncelik | Durum |
|---|---|---|---|
| FIN-01 | Para birimi tamsayı kuruş; double yalnız kur/değerleme/oran tahmininde | — | DOĞRULANDI |
| FIN-02 | Elle tutar girişinde nokta ondalık ayırıcı 100 kat tutar üretiyor | P2 | DOĞRULANDI (birim) / cihaz klavyesi DOĞRULANMADI |
| FIN-03 | `toMinorUnits` "1,155.00" → 116 kuruş; ayrıştıramazsa sessizce 0 | P2 | DOĞRULANDI |
| FIN-04 | Döviz hesabı ekstresi tespiti yok: tüm tutarlar TL varsayılıyor | P2 | DOĞRULANDI (kod) / gerçek döviz ekstresi DOĞRULANMADI |
| FIN-05 | Kategori analizi iadeleri düşmüyor; aylık özet düşüyor → toplamlar farklı | P3 | DOĞRULANDI |
| FIN-06 | Kendi-hesap transferi eşleştirmesi isim/karşı taraf kontrolü yapmıyor, geri alınamıyor | P3 | DOĞRULANDI |
| FIN-07 | Bordro–maaş yatışı tekilleştirmesi tutara bakmıyor | P3 | DOĞRULANDI |
| FIN-08 | Hesap numarası okunamazsa aynı bankanın iki kartı tek hesaba düşer, ikincisi "aynı dönem" diye reddedilir | P3 | DOĞRULANDI (kod) |
| FIN-09 | Maskeleme (PiiRedactor) açıklamayı değiştiriyor; mükerrer anahtarı buna bağlı | P3 | DOĞRULANDI |
| FIN-10 | Mükerrer ekstre korumaları (SHA-256 + aynı dönem + işlem parmak izi) | — | DOĞRULANDI |
| FIN-11 | Çift sayım önlemleri: kart ödemesi, iade, kendi transfer, taksit, bordro | — | DOĞRULANDI (testlerle) |
| FIN-12 | Tarih / saat dilimi / son ödeme sınırları | P4 | DOĞRULANDI (küçük notlar) |
| FIN-13 | Toplamlar kaynak işlemlerden yeniden hesaplanabilir | — | DOĞRULANDI |
| FIN-14 | Faiz/BSMV/KKDF ayrıştırması ve KDV tahmini | P4 | DOĞRULANDI (oranlar finans uzmanınca teyit edilmeli) |

---

## FIN-01 — Para temsili (DOĞRULANDI)

- Ekstre tutarları katı Türkçe biçim regex'iyle yakalanıyor (`^([+-])?\s?(\d{1,3}(?:\.\d{3})*,\d{2})…$`) ve kuruşa çevriliyor: `lib/core/parser/util/tr_statement_text.dart:11-19`. Veritabanında `billing_amount_cents` tamsayı; tüm toplamlar SQLite `SUM(INTEGER)` (`transaction_repository.dart:461-463`, `:578`, `:614-620`, `:680`, `:705`, `:755`; `wallet_history_service.dart:169-171`, `:225`; `tax_analysis_service.dart:102`).
- `toMinorUnits` içi `double.tryParse(...) * 100` sonra `.round()` (`currency_normalizer.dart:45-46`): 15-16 anlamlı basamağa kadar kesin; prob: `99999999999,99` → `9999999999999` doğru.
- `double` kullanılan yerler ve değerlendirme:
  - `exchangeRate = billing / original` (`yapikredi_card_parser.dart:170`, `parsed_models.dart:86`) — yalnız bilgi amaçlı, hiçbir toplama girmiyor → kabul edilebilir.
  - Canlı kur/altın fiyatları ve maliyet (`live_market_service.dart:11-13`, `assets_screen.dart:39-48`, `:1126`) — tahmini değerleme; sonuç `(… * 100).round()` ile kuruşa dönüyor → kabul edilebilir (finansal kayıt değil).
  - KDV tahmini `(spent * rate / (1 + rate)).round()` (`tax_analysis_service.dart:17`) ve hedef ilerleme yüzdeleri — gösterim amaçlı → kabul edilebilir.

## FIN-02 — Nokta ondalık ayırıcı 100 kat tutar (P2)

- **Açıklama:** `ThousandsInputFormatter` girilen tüm `.` karakterlerini siler (binlik ayırıcı sayar); ondalık yalnız `,`. Kullanıcı `12.50` yazarsa alan `1.250` olur ve `toMinorUnits` → **125000 kuruş (₺1.250,00)**.
- **Kanıt:** `lib/core/utils/thousands_input_formatter.dart:13-27`; prob çıktısı: `formatter 12.50 => 1.250 => 125000`. Etkilenen girişler: hızlı giriş (`quick_entry_sheet.dart:300-301`, `:78`), kart ödemesi (`credit_card_action_sheet.dart:110`), hedefler (`add_goal_sheet.dart:76`, `:96`; `goal_contribution_dialog.dart:43`), varlıklar (`assets_screen.dart:545`, `:648`, `:1988`, `:2012`), piyasa hesaplayıcı.
- **Olasılık:** Türkçe yerel ayarlı klavyede ondalık tuşu `,` → düşük; uygulamanın İngilizce dili var, İngilizce yerel ayarlı cihazda sayı klavyesi `.` gösterebilir (cihazda DOĞRULANMADI).
- **Önerilen çözüm:** Son ayırıcıdan sonra 1-2 basamak varsa onu ondalık kabul et ya da `.`'yı ilk `,` yoksa ondalığa çevir; kaydetmeden önce biçimlenmiş tutarı onaylat. Test: "12.50", "12,50", "1.250", "1.250,5".

## FIN-03 — `toMinorUnits` belgelenmiş biçimi yanlış okuyor, hatada 0 (P2)

- **Kanıt (prob):** `1,155.00 → 116` (beklenen 115500; dosya başındaki yorum bu biçimi destekliyor diyor: `currency_normalizer.dart:4`), `1,155 → 116`, `1234,56- → 0`, `(1.234,56) → 0`, `abc → 0`.
- **Etki:** Ekstre ayrıştırma yolu etkilenmiyor (regex yalnız TR biçimini geçiriyor). Elle girişlerde yanlış/0 tutar; hızlı giriş `<= 0` reddediyor (`quick_entry_sheet.dart:82`) ama hedef/varlık alanları 0'ı kabul edebilir.
- **Önerilen çözüm:** Ayrıştırılamayan girişte `null`/hata döndür (sessiz 0 yok); İngilizce biçimi (virgül binlik, nokta ondalık) açıkça destekle ya da yorumdan çıkar; sondaki eksi ve parantezli negatifleri destekle.

## FIN-04 — Döviz hesabı ekstresi (P2)

- **Açıklama:** `ParsedRecord.billingCurrency` varsayılanı `'TRY'` (`parsed_models.dart:112`) ve hiçbir ayrıştırıcı bunu değiştirmiyor (`grep billingCurrency: lib/core/parser` → yalnız `copyWith`). Bir USD/EUR vadesiz hesap ekstresi (genel ayrıştırıcı veya Enpara) yüklenirse tutarlar TL gibi toplanır. Kart ekstresinde yurt dışı harcamalar TL'ye çevrilmiş olarak geldiği ve orijinal tutar ayrı tutulduğu için kart tarafı doğru.
- **Kısmi koruma:** KDV tahmini yalnız `billing_currency IN ('TRY','TL')` alıyor (`tax_analysis_service.dart:100`) — diğer toplamlarda böyle filtre yok.
- **Önerilen çözüm:** Ekstre başlığında "Döviz Cinsi / Hesap Para Birimi / USD / EUR" tespiti; TL dışı hesabı ya reddet ya da para birimiyle kaydedip toplamlarda ayrı göster. Gerçek döviz hesabı ekstresiyle DOĞRULANMADI.

## FIN-05 — Kategori analizi iadeleri düşmüyor (P3)

- **Kanıt:** Aylık özet iadeyi harcamadan düşüyor (`transaction_repository.dart:459-466`), aylık trend de düşüyor (`:614-621`); kategori analizi yalnız `transaction_type = 'DEBIT'` topluyor (`:567-570`, `:578`). Analiz ekranındaki "Toplam Harcama Hacmi" ve paylaşılan rapor bu toplamı kullanıyor (`analysis_screen.dart:621`).
- **Etki:** İade olan ayda analiz ekranı toplamı ana ekrandaki aylık giderden büyük görünür; kullanıcı iki rakamı karşılaştırırsa güven kaybı.
- **Önerilen çözüm:** İadeyi kendi kategorisinden düş (iade satırının `category_id`'si varsa) ya da "brüt harcama" olarak etiketle. Test: aynı ay 100 TL harcama + 30 TL iade → iki ekran aynı 70 TL.

## FIN-06 — Kendi-hesap transferi eşleştirmesi (P3)

- **Kanıt:** `_reconcileOwnTransfersIn` (`transaction_repository.dart:286-326`): koşullar `TRANSFEROUT`↔`TRANSFERIN`, farklı `account_id`, kuruşuna eşit tutar, ±3 gün (`:254`). Karşı taraf adı/IBAN kontrolü yok; eşleşen iki kaydın `tx_kind`'ı kalıcı olarak `OWNTRANSFER` olur, kullanıcı için "eşleştirmeyi geri al" yolu bulunamadı.
- **Senaryo:** A hesabından ev sahibine 15.000 TL kira EFT'si ve 2 gün içinde B hesabına bir arkadaştan 15.000 TL gelen havale → ikisi de nötrleşir; gelir ve gider aynı anda eksik görünür (net etki 0 ama kategori/bütçe yanlış).
- **Mevcut testler:** `test/own_transfer_reconciliation_test.dart` (7 test: 1 kuruş fark eşleşmez, ±3 gün sınırı, aynı hesap eşleşmez, nötr kayıtlar tekrar işlenmez, açılışta bağımsız çağrı).
- **Önerilen çözüm:** Karşı taraf alanında kullanıcının adı/kendi IBAN'ı veya hesap sahibi eşleşmesi koşulu; birden çok aday varsa eşleştirme yapma; işlem detayında "kendi transferim değil" düğmesi.

## FIN-07 — Bordro–maaş yatışı tekilleştirmesi tutara bakmıyor (P3)

- **Kanıt:** `payslipDuplicateFilterSql` (`transaction_repository.dart:70-76`): bordrodaki `SALARY`, ±20 gün içinde bordro dışı **herhangi** bir `SALARY` kaydı varsa gelirden çıkarılıyor; tutar karşılaştırması yok.
- **Senaryo:** Eşin bordrosu (karar gereği eklenebilir, bkz. `payslip_duplicate_rule_test.dart`) + yalnız kullanıcının kendi maaş yatışı yüklü → eşin bordrosu da "yatışı zaten var" sayılıp gelirden düşer → hane geliri eksik.
- **Önerilen çözüm:** Eşleşmeyi net tutar (± küçük tolerans) ve birebir eşleştirme (bir yatış yalnız bir bordroyu nötrler) ile yap.

## FIN-08 — Hesap kimliği okunamazsa hesaplar birleşir (P3)

- **Kanıt:** `accountIdFor` (`transaction_repository.dart:29-35`) kimlik boşsa `acc_<banka>_<belgeTürü>`; aynı-dönem kontrolü bu kimlik + ekstre tarihiyle (`:45-66`). Aynı bankanın kart numarası okunamayan iki kartı tek hesapta toplanır; aynı kesim tarihli ikinci kartın ekstresi "bu dönem daha önce aktarılmış" diye reddedilir.
- **Etki:** Kayıp ekstre / birleşik kart borcu. Yapı Kredi ayrıştırıcısının kart numarasını her zaman okuyup okumadığı korpusla DOĞRULANMADI.
- **Öneri:** Kimlik boşsa aynı-dönem kontrolünü yalnız SHA-256'ya düşür ve kullanıcıya kartı seçtir.

## FIN-09 — Maskeleme veriyi değiştiriyor (P3)

- **Kanıt:** Açıklama, karşı taraf, satıcı ve hesap kimliği kaydedilmeden önce `PiiRedactor.redact` ile değiştiriliyor (`statement_orchestrator.dart:140`, `:184-186`). Prob: 16 haneli FAST referansı ve 11 haneli sipariş numarası maskeleniyor (bkz. security-audit SEC-15). İşlem parmak izi maskelenmiş açıklamayı kullanıyor (`transaction_repository.dart:83-98`).
- **Etki:** Referans numarası kaybı; maskeleme kuralı değişirse yeniden yüklenen aynı işlemin parmak izi değişir → mükerrer kayıt riski (aynı-dönem kontrolü kart/hesap ekstrelerinde çoğunu yine de durdurur).
- **Öneri:** Kural değişikliklerinde parmak izini maskelenmemiş-normalize metinden (ör. SHA-256'sı) üret; bu bir şema/göç işi.

## FIN-10 — Mükerrer ekstre korumaları (DOĞRULANDI)

1. Dosya SHA-256: `isStatementAlreadyImported` (`transaction_repository.dart:15-25`), yükleme akışında ayrıştırmadan sonra, kayıttan önce (`statement_upload_sheet.dart:193`, toplu: `:274`).
2. Aynı hesap + aynı ekstre tarihi (yoksa dönem başı/sonu): `isSamePeriodAlreadyImported` (`:45-66`), bordroda uygulanmaz (karar; `samePeriodCheckApplies`, `:40`). Çağrı: `statement_upload_sheet.dart:216`, `:275`.
3. İşlem parmak izi + `ConflictAlgorithm.ignore` (`:83-98`, `:205-208`) → `skippedDuplicates`.
- Testler: `test/payslip_duplicate_rule_test.dart` (7), `test/uploaded_statements_test.dart`, `test/statement_pipeline_test.dart` (18).

## FIN-11 — Çift sayım önlemleri (DOĞRULANDI, testlerle)

| Durum | Kod | Test |
|---|---|---|
| Vadesizden kart borcu ödemesi nötr (`CARDPAYMENT`) | `neutralKindsSql` `transaction_repository.dart:66` | `statement_pipeline_test.dart:53`, `credit_card_payment_flow_test.dart:54,78` |
| Kart ödemesi cüzdanda bir kez düşülür, yalnız kendi bankasının kartına | `allocateCardPayments` | `wallet_card_payments_test.dart` (4) |
| İade gelir değil, harcamadan düşer | `:459-466`, `:614-621` | `statement_pipeline_test.dart:60,157` (FIN-05 istisnası) |
| Kendi hesaplar arası transfer nötr | `:286-326` | `own_transfer_reconciliation_test.dart` (7) |
| Taksit planı iki ekstrede tekrar etmez, bitmiş taksit listelenmez | `getUpcomingInstallments` | `upcoming_payments_dedup_test.dart:91,130` |
| Kart borcu (CARD_DUE) en güncel ekstreden | `getUpcomingPayments` | `upcoming_payments_dedup_test.dart:149` |
| Bordro net maaşı + banka yatışı iki kez gelir sayılmaz | `payslipDuplicateFilterSql` `:70-76` | `payslip_duplicate_rule_test.dart` (FIN-07 istisnası) |
| Faizdeki BSMV/KKDF ayrı satır varsa tekrar bölünmez | `fee_report_service.dart:144-156` | `fee_report_test.dart:52` |
| Ekstre toplamları bankanın beyanıyla mutabakat | `statement_reconciler.dart:9-30` | korpus testi (`pdf_corpus_probe_test.dart`, `verify_parsers.ps1`) |

Bu turda tam test paketi geçti (sonuçlar görev raporunda).

## FIN-12 — Tarih / saat dilimi / son ödeme (P4)

- Tarihler `YYYY-MM-DD` metni, yerel `DateTime(y,m,d)`; geçersiz gün/ay reddediliyor (`tr_statement_text.dart:60-64`); 2 haneli yıl `+2000` (`:46`) — 2100'e kadar sorun yok.
- Aylık gruplama işlem tarihine göre (`transaction_date LIKE 'YYYY-MM%'`), ekstre dönemine göre değil — kart ekstresi dönem toplamı ile "bu ay harcama" farklı olabilir; tasarım gereği, ama ekranlarda hangi tanımın kullanıldığı açıkça yazılmalı.
- Son ödeme hatırlatıcısı `DateTime(y, m, d - 2, 10)` — ay/yıl taşması Dart tarafından doğru normalize edilir; geçmişe düşerse aynı gün 09:00 (`notification_service.dart:135-137`), `tz.local` ile zamanlanıyor (`:75`). Son ödeme tarihi bankanın ekstresindeki değer olduğu için tatil kayması bankaca uygulanmış olur.
- Kota dönemi sunucuda `Europe/Istanbul` (`private.current_period`), istemcinin "geçmiş dönem" kararı cihaz saatiyle (`user_profile_service.dart:322-325`) — cihaz saati değiştirilerek etkilenebilir (security-audit SEC-04).

## FIN-13 — Yeniden hesaplanabilirlik (DOĞRULANDI)

- Saklanan bir "bakiye/toplam" alanı yok; tüm özetler sorgu anında `transactions` üzerinden toplanıyor (FIN-01 satır listesi). Ekstre özet değerleri (`statementBalanceCents`, asgari ödeme — `yapikredi_card_parser.dart:183-184`) bankanın beyanı olarak ayrı saklanıyor ve mutabakatta karşılaştırılıyor. Kendi-transfer eşleştirmesi açılışta yeniden çalıştırılıyor (idempotent: eşleşen kayıt tekrar aday olmuyor).

## FIN-14 — Faiz vergisi ayrıştırması ve KDV tahmini (P4)

- Kart faizi tek satırda "BSMV dahil" ise faiz = toplam × 100/130, BSMV = faiz × %15, KKDF = kalan; yuvarlama farkı KKDF'de kalır, toplam korunur (`fee_report_service.dart:145-153`, test `fee_report_test.dart:41`). Oranların (%15 BSMV, %15 KKDF) güncel mevzuata uygunluğu finans uzmanınca teyit edilmeli (DOĞRULANMADI).
- KDV tahmini "tahmini" etiketli, gerçek masraflarla toplanmıyor, sınıflanamayan kategoriye oran varsaymıyor (`tax_analysis_service.dart:20-28`, `:61-68`; test `fee_report_test.dart:101,132`).

## Önerilen yeni testler (yazılmadı — ilgili dosyalar bu görevin kapsamı dışında)

1. `ThousandsInputFormatter` + `toMinorUnits`: "12.50", "12,50", "1.250", "1.250,5", "1,155.00" (FIN-02/03).
2. Kategori analizi toplamı = aylık özet gideri (iade varken) (FIN-05).
3. Kendi transfer: farklı karşı taraf adlarıyla aynı tutar eşleşmemeli (FIN-06).
4. Bordro tekilleştirme: farklı tutarlı yatış bordroyu nötrlememeli (FIN-07).
5. Kart kimliği boş iki farklı kart, aynı kesim tarihi (FIN-08).
