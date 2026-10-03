# FinScout — UI/UX Modernizasyon Raporu

**Tarih:** 2026-10-03
**Hazırlayan:** Tasarım direktörü ajanı (finscout-tasarim)
**Tür:** Salt-okunur analiz. Bu turda hiçbir `lib/` dosyası değiştirilmedi, hiçbir paket kurulmadı (`pub add` çalıştırılmadı).
**Kapsam:** Uygulama içi ekranların UI/UX/tasarım sistemi/widget/animasyon tarafı. Mimari, güvenlik, performans, yerelleştirme-altyapısı, test stratejisi **docs/audit/** klasöründe (architecture-review.md, risk-register.md, master-report.md vb.) zaten işlendi — bu rapor onları tekrarlamaz, çakışan yerlerde çapraz referans verir.

---

## 0. Yöntem ve dayanak

Tüm bulgular gerçek kod okunarak (grep + dosya okuma) çıkarıldı; `lib/` altında varsayım yapılmadı. Doğrulanamayan noktalar **DOĞRULANMADI** olarak işaretlendi. Sayımlar bu oturumda çalıştırılan komutlarla elde edildi (aşağıdaki envanterde komutlar değil sonuçlar verilmiştir).

---

## 1. Teknik/Mimari Envanter (UI açısından)

| Alan | Bulgu | Kanıt |
|---|---|---|
| Flutter sürümü | **3.47.5** (stable kanal), Dart **3.13.4** | `flutter --version` çıktısı (yerel kurulum) |
| pubspec SDK kısıtı | `sdk: '>=3.0.0 <4.0.0'`, `flutter: ">=3.10.0"` — gerçek kuruludan çok daha gevşek | `pubspec.yaml:6-8`; ayrıca ARCH-17'de (docs/audit/architecture-review.md) bu kısıtın gerçeği yansıtmadığı not edilmiş — tekrarlanmıyor |
| Android min/target/compile SDK | minSdk **24**, targetSdk **36**, compileSdk **36** | `android/app/build.gradle:34-36,41` |
| State management | **Yok** (Provider/Riverpod/Bloc paketi pubspec'te yok). Ekranlar `StatefulWidget` + `setState`; global değişim bildirimi `ValueNotifier` tabanlı `DataChanges.revision` (7 dinleyici — ayrıntı ARCH-10, tekrarlanmıyor) | `pubspec.yaml` içinde state-mgmt paketi yok; `core/services/data_changes.dart` |
| Navigation | Klasik `Navigator`/`MaterialPageRoute`, özel sayfa geçişi `AppMotion.pageTransitionsTheme` (Android'de predictive-back + fade-forwards); alt sekmeler `FadeThroughIndexedStack` ile canlı tutuluyor | `lib/core/theme/app_motion.dart:53-74`, `lib/core/widgets/fade_through_indexed_stack.dart` |
| Tema sistemi | `app_colors.dart` (183 satır), `app_theme.dart` (171 satır, içinde `AppSpacing`/`AppRadius`/`AppShadows` kısmi token sınıfları), `app_motion.dart` (113 satır, süre+eğri tokenleri + "azalt animasyon" desteği) | `lib/core/theme/*.dart` |
| Koyu mod | Bu oturumda **ilk dilim** eklendi: yalnız 3 ekran dark-aware (`canvasOf`/`cardOf`/`borderOf` kullanıyor) — Dashboard, Onboarding, Settings. 4 ekran hâlâ statik `AppColors.background`/`Colors.white` kullanıyor — Analysis, Assets, Cashflow, Goals. Bu bilinen/beklenen bir durum, **yeniden keşfedilmiyor**, sadece doğrulandı. | grep: `canvasOf(context)` → `dashboard_screen.dart`, `onboarding_screen.dart`, `settings_screen.dart`; `AppColors.background` → `analysis_screen.dart`, `assets_screen.dart`, `cashflow_screen.dart`, `goals_screen.dart` |
| Widget/component klasörü | `lib/core/widgets/` içinde 10 dosya + `fintech/` alt klasöründe 5 (FinanceCard, IzciInsightCard, CleanTransactionRow, SlidingOverlayCard, SecurityAuthSheet, AppLockScreen, BankSelectionSheet) + `onboarding_tour/` alt klasöründe 7 → toplam **22 paylaşılan widget dosyası** | `find lib/core/widgets` çıktısı |
| Ekran sayısı | `lib/features/` altında **14** özellik klasörü; `presentation/` altında **26** dart dosyası; bunlardan **11**'i `*_screen.dart` (asıl tam ekranlar), kalanı sheet/dialog/alt-widget | `find lib/features -path "*/presentation/*" -name "*.dart"` çıktısı (26 dosya listelendi) |
| En büyük dosyalar | `assets_screen.dart` 2401, `statement_upload_sheet.dart` 1299, `dashboard_screen.dart` 1227, `settings_screen.dart` 883, `analysis_screen.dart` 864, `onboarding_screen.dart` 834 satır | `wc -l` — **ARCH-09 ile çapraz referans**, boyut/modülerlik sorunu orada işlendi, burada tekrarlanmıyor; bu rapor sadece bu dosyaların **içindeki görsel tutarlılığa** bakıyor (bkz. §4) |
| İkon sistemi | Yalnız Material `Icons.*` (Cupertino/özel ikon fontu/SVG seti yok) — tutarlı ve doğru tercih | grep: `Icons\.` kullanımı genel, ayrı ikon paketi pubspec'te yok |
| Testler | `test/` altında **34** dosya, tamamı mantık/birim testi (parser, hesaplama, migrasyon, kota). **Widget/golden testi yok** → bir ekranı değiştirirken görsel regresyonu yakalayacak otomatik bir ağ bulunmuyor (docs/audit/test-strategy.md kapsamı dışında, UI'a özgü bu boşluk orada da adlandırılmamış) | `find test -name "*.dart"` (34 dosya), hiçbiri `testWidgets`+`matchesGoldenFile` içermiyor (DOĞRULANMADI: golden dosyası aranmadı, ama dosya adlarından hiçbiri "golden"/"widget" değil) |
| UI/animasyon bağımlılıkları | `fl_chart: ^0.68.0`, `google_fonts: ^6.2.1` — **tek grafik ve tek font paketi**. `flutter_animate`, `lottie`, `animations`, `shimmer`, `flex_color_scheme`, `home_widget` **pubspec'te yok** | `pubspec.yaml:9-11` |
| Font | Plus Jakarta Sans (gövde/başlık), JetBrains Mono (`AppTheme.numericStyle`, finansal rakamlar için) — Google Fonts üzerinden, ikisi de markaya uygun, tutarlı çift | `app_theme.dart:50,167-170` |

**Pozitif not:** Bu envanter beklenenden daha olgun bir temel gösteriyor — `AppSpacing`/`AppRadius`/`AppShadows`/`AppMotion` gibi kısmi bir token sistemi **zaten var**, "animasyonları azalt" erişilebilirlik ayarına saygı duyan bir hareket katmanı **zaten var**, ve paylaşılan `FinanceCard`/`IzciInsightCard` bileşenleri **zaten var**. Asıl sorun bu sistemin kurulu olması değil, §4'te gösterildiği gibi **tutarlı biçimde kullanılmaması**.

---

## 2. AI-görünümü Risk Taraması

Brief'in listelediği kalıpların her biri ayrı ayrı arandı. Sonuç: **K7 temizliği hâlâ geçerli, geri gelmemiş** — ama birkaç küçük, somut risk var.

| Kalıp | Sonuç | Kanıt / not |
|---|---|---|
| "Dynamic Island" kapsül, radar, streak modal, pulse rozet, laser shimmer | **TEMİZ — doğrulandı, geri gelmemiş.** `lib/` içinde `dynamic island`, `radar`, `streak`, `pulse`, `laser` dize/yorum araması **sıfır sonuç** verdi. | `grep -rni "dynamic.island\|radar\|streak\|pulse\|laser" lib/` → boş çıktı |
| Glassmorphism / blur | **Yok.** `ImageFilter.blur`, `BackdropFilter` hiçbir dosyada yok. | grep sonucu: 0 |
| Jenerik mor-mavi "AI" gradyanı | **Yok — yanlış alarm riski elendi.** Toplam 7 `LinearGradient` kullanımı var, hepsi marka paletine bağlı: onboarding kayıt/giriş kapakları `#047857→#0F172A` (zümrüt→lacivert) ve `#2563EB→#0F172A` (kobalt→lacivert); dashboard boş-durum ikon kutusu `actionPrimary %8 → #6366F1 %5` (çok soluk, dekoratif değil). Jenerik mor-mavi "yapay zekâ" gradyanı **yok**. | `onboarding_screen.dart:316-320,359-363`, `sliding_overlay_card.dart:118-130`, `dashboard_screen.dart:1151-1156` |
| Emoji ikon | **Yok.** UI metinlerinde emoji taraması sıfır sonuç verdi. | grep (emoji unicode aralıkları) → eşleşme yok |
| Sahte veri / mockup / placeholder metin | **Yok — ve bilinçli.** `dashboard_screen.dart:207`'de doğrudan şu yorum var: *"SIFIR MOCKUP: Tamamen temiz ve boş başlar"*. `lorem`/`dummy`/`fake data`/`mock` taraması kodda eşleşme vermedi. | `dashboard_screen.dart:207`; grep sonucu boş |
| İngilizce-Türkçe karışık UI metni | **Yok.** Kalıcı buton/etiket metinlerinde İngilizce leftover (Loading/Save/Cancel/Submit vb.) bulunamadı. | grep taraması boş |
| Dekoratif/anlamsız "sparkle" ikon (`Icons.auto_awesome`) | **Küçük risk — P3.** `Icons.auto_awesome_rounded` iki yerde kullanılıyor: `fintech_components.dart:97` (İzci asistan notu başlığında) ve `dashboard_screen.dart:1164` (boş-durum pazarlama kutusunda). İkisi de "yapay zekâ sihri" çağrışımı yapan klasik "AI sparkle" ikonu; İzci bir maskot/asistan kimliği olduğu için bir ölçüde savunulabilir, ama iki farklı bağlamda (asistan notu + genel pazarlama kutusu) tekrar etmesi "otomatik AI önerisi" hissini güçlendiriyor. | `fintech_components.dart:97`, `dashboard_screen.dart:1164` |
| Kod yorumlarında abartılı pazarlama/AI dili (görsel değil, isimlendirme) | **Orta risk — P3.** Widget doc-comment'leri hâlâ "Video & Shakuro Micro-Interaction", "ultra modern alt menü", "neon aktif hap göstergeli", "Video & FinTech Dynamic Ticker" gibi ifadeler taşıyor. **Gerçek render çıktısı bu ifadelerle örtüşmüyor** — örn. `FloatingCapsuleNavBar`'ın gerçek kodu gayet sade, düz renk dolgulu bir kapsül (neon/glow efekti yok); yorum metni kalıntı. Bu durum zararsız görünse de iki risk taşıyor: (1) yeni bir geliştirici/ajan bu yorumu okuyup "neon efekt eklemeliyim" sanabilir, (2) `AGENTS.md`'de de aynı "Shakuro/Dynamic Island/radar" ifadeleri referans standardı gibi geçiyor — ARCH-19'da zaten çelişkili yönerge olarak işaretlenmiş, burada **tasarım dili** açısından teyit ediliyor: bu ifadeler artık ürünün gerçek görsel dilini tanımlamıyor. | `floating_capsule_nav_bar.dart:5-7`, `morphing_segmented_bar.dart:10-12`, `rolling_number_ticker.dart:6-9` (yorumlar); karşılaştır: aynı dosyaların gerçek `build()` çıktısı — düz renk, gölge yok |
| Her şeyi kart içine koyma / aşırı yuvarlak köşe | Ayrı bir bulgu olarak §4'te derinlemesine işlendi (token tutarsızlığı bağlamında) — burada tekrarlanmıyor. | — |

**Sonuç:** Önceki K7 temizliği (dynamic island/radar/streak/pulse/laser silinmesi) **sağlam durumda, rejresyon yok**. Kalan risk görsel değil, isimlendirme/yorum düzeyinde (P3) ve iki `auto_awesome` ikonu (P3) — acil değil ama bir temizlik turunda ele alınmalı.

---

## 3. Tasarım Sistemi Tutarsızlık Taraması

### 3.1 Mevcut durum: token var, ama kullanılmıyor

`AppSpacing` (xs=4…xxxl=32), `AppRadius` (sm=8, md=12, card=16, button=14, sheet=24, pill=99) ve `AppShadows` (card, subtle) `lib/core/theme/app_theme.dart:7-42`'de tanımlı. Ama:

- `lib/features/` altında bu üç sınıfa toplam **30 referans** var, ve bunlar yalnız **4 dosyada** toplanıyor (`analysis_screen.dart`, `payslip_view.dart`, `assets_screen.dart`, `dashboard_screen.dart`). **26 presentation dosyasının 22'si bu token'lara hiç dokunmuyor.**
- Buna karşılık `EdgeInsets.all/symmetric/only` ile **231** adet elle yazılmış boşluk değeri, `BorderRadius.circular(...)` ile **~230** adet elle yazılmış köşe değeri var.

Bu, "merkezi bir token sistemi kurulmuş ama benimsenmemiş" durumunun doğrudan kanıtı — brief'in varsaydığı "muhtemelen hiç token sistemi yok" senaryosundan daha iyi ama pratikte aynı sonucu veriyor: **görsel tutarlılık koda değil, geliştiricinin o anki hafızasına bağlı.**

### 3.2 Köşe yarıçapı (border-radius) dağılımı

`lib/` genelinde `BorderRadius.circular(...)` için **14 farklı değer** ölçüldü: 2, 3, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24 (bunlardan sadece 8/12/14/16/24/99 tanımlı token'a karşılık geliyor — diğerleri (2,3,4,6,10,18,20,22) tamamen ad-hoc).

Somut çarpışma örneği — **alt sayfa (bottom sheet) köşesi**:
- Tema seviyesinde tanımlı: `AppRadius.sheet = 24` (`app_theme.dart:22`, `BottomSheetThemeData` içinde de kullanılıyor, `app_theme.dart:88-91`).
- Ama ekranlar kendi `Container`'ını elle çiziyor ve **28** kullanıyor: `statement_upload_sheet.dart:637` (`BorderRadius.vertical(top: Radius.circular(28))`), `analysis_screen.dart:206` (kategori detay sheet'i, aynı şekilde 28).
- Sonuç: Ekstre yükleme sheet'i ile kategori detay sheet'i, uygulamanın standart alt sayfasından (ör. `subscription_plans_sheet.dart`'ın `showModalBottomSheet` + tema `BottomSheetThemeData` kullanımı) **gözle fark edilir** biçimde daha köşeli/büyük bir radius ile açılıyor.

İkinci örnek — tek dosya içi tutarsızlık (`statement_upload_sheet.dart`): aynı sheet içinde 6, 10, 12, 16, 20 olmak üzere **5 farklı radius** yan yana kullanılıyor (`:649,685` vb.) — hiçbiri `AppRadius.*`'a referans vermiyor, hepsi ayrı ayrı yazılmış sabit sayı.

### 3.3 Font boyutu (fontSize) dağılımı

`lib/features` + `lib/core/widgets` içinde doğrudan yazılmış `fontSize:` değerleri için **25 farklı sayı** ölçüldü: 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, 15.5, 16, 17, 18, 20, 22, 24, 26, 28, 30, 32 (+ az sayıda ara değer). Merkezi bir `AppTypography`/`TextTheme` ölçeği (ör. `display/headline/title/body/label` gibi 6-8 adımlı sabit bir merdiven) **yok** — `app_theme.dart`'taki `textTheme` yalnız `displayLarge/titleLarge/titleMedium/bodyLarge/bodyMedium` seviyelerinde ağırlık (weight) tanımlıyor, ekranlar bunu kullanmak yerine neredeyse hep elle `TextStyle(fontSize: X, ...)` yazıyor.

Somut örnek — aynı "ikincil/alt metin" rolü için üç farklı dosyada üç farklı boyut: `payslip_view.dart:177` → 11.5, `analysis_screen.dart:438` → 10.5, `credit_card_action_sheet.dart:328` → 10.5 ama `cashflow_screen.dart:203` → 11.5, `goal_summary_header.dart` → 12. Sonuç: aynı hiyerarşi seviyesi (etiket/alt başlık) ekrandan ekrana 1-1.5px kayıyor — kullanıcı bunu bilinçli fark etmez ama "bir yerlerde tutarsız" hissi birikir; bu tür mikro-tutarsızlıklar finans uygulamalarında (Wise/Revolut/N26) neredeyse sıfırdır çünkü tipografi ölçeği kod seviyesinde zorunlu kılınır.

### 3.4 Renk — merkezi, ama yan yana iki sistem

`AppColors` iyi organize (Canvas/Surface/Border/Text/Action/Status + kategori renkleri, `catXxx`) ve dark-mode-aware getter'lar (`canvasOf`, `surfaceOf` vb.) doğru kurulmuş. Ama ekranlarda **ad-hoc hex renkler** de bolca var: `Color(0xFF6366F1)`, `Color(0xFFEFF6FF)`, `Color(0xFFDBEAFE)`, `Color(0xFFF59E0B)` (varlık kartı rengi, `AppColors`'taki `installment`/`scout` ile aynı ton ama ayrı sabit olarak tekrar yazılmış) gibi değerler `assets_screen.dart`, `goals_screen.dart`, `onboarding_screen.dart` içinde doğrudan satır içi tanımlanıyor. Bunların çoğu `AppColors` paletiyle **aynı ton** (ör. `#F59E0B` zaten `AppColors.installment`/`AppColors.scout`) ama token'a referans vermiyor — yani palet değişirse (ör. marka rengi güncellenirse) bu satırlar görünmez kalır ve güncellenmeyi unutulur.

### 3.5 Öneri: token seti taslağı (UYGULANMAMIŞ — öneri niteliğinde)

Mevcut kısmi sistemin üzerine inşa edilmesi öneriliyor (sıfırdan yazmak yerine):

```
// ÖNERİ — henüz kodda yok
AppRadius:   xs=6, sm=8, md=12, lg=16(card), xl=20, pill=999   // mevcutları koru, "card"ı "lg" ile eşitle, 14/18/22/24/28 gibi ara değerleri kaldır
AppSpacing:  xs=4, sm=8, md=12, lg=16, xl=20, xxl=24, xxxl=32  // mevcut — değişmesin, sadece disiplinli kullan

AppTypography (ÖNERİ, yeni):
  display     28 / w800   // tutar hero'ları (ör. dashboard net bakiye RollingNumberTicker)
  headline    20 / w800   // ekran/sheet başlığı
  title       16 / w700   // kart başlığı
  bodyLarge   14 / w500   // ana gövde
  bodyMedium  13 / w500   // ikincil gövde
  label       12 / w700   // etiket/rozet (ALL CAPS kullanılan yerler)
  caption     11 / w600   // meta bilgi (tarih, sayaç)
  financialAmount  → mevcut AppTheme.numericStyle (JetBrains Mono) — DEĞİŞTİRME, iyi çalışıyor

AppMotion: mevcut (short=220/medium=280/page=300ms + M3 eğrileri) — DEĞİŞTİRME, zaten doğru kurulmuş.
```

Bu öneri **yeni bir görsel dil değil**, var olanın adlandırılması ve zorunlu kılınmasıdır — "minimum ama doğru" ilkesiyle çelişmez.

---

## 4. Widget/Component Kullanım Haritası

| Ekran/Dosya | Mevcut widget | Sorun | Önerilen widget | Animasyon | Paket | Öncelik |
|---|---|---|---|---|---|---|
| Dashboard (`dashboard_screen.dart:1141` `_buildEmptyStateCard`) | Elle `Container`+`BoxDecoration` + `Icons.auto_awesome_rounded` | §2'de belirtilen "AI sparkle" ikonu; gradyan ad-hoc (`#6366F1` token'da yok) | Aynı widget, ikonu `Icons.insights_rounded`/marka maskotuna çevir, rengi `AppColors`'a bağla | Değişmesin (statik kart) | — | P3 |
| Analysis / Assets / Cashflow / Goals sheet'leri (`statement_upload_sheet.dart:637`, `analysis_screen.dart:206`) | Elle çizilmiş `BorderRadius.vertical(top: Radius.circular(28))` | `AppRadius.sheet=24` ile çelişiyor, tema `BottomSheetThemeData`'yı bypass ediyor | `showModalBottomSheet` + tema varsayılanı (zaten `subscription_plans_sheet.dart`'ta doğru kullanılıyor, örnek alınabilir) | Yok (statik düzeltme) | — | P2 |
| `goal_card_tile.dart`, `goal_summary_header.dart` (Goals ekranı) | Her ikisi de kendi `BoxDecoration`'ını elle yazıyor (16/12/10/8/4 radius karışık) | Aynı ekran içinde FinanceCard yerine özel kart; radius token'a bağlı değil | `FinanceCard` tabanlı ortak `GoalCard` bileşeni | Yok | — | P3 |
| 25 dosyada ad-hoc `BoxDecoration` kartı (en yoğun: `assets_screen.dart` 16, `dashboard_screen.dart` 15, `statement_upload_sheet.dart` 13, `settings_screen.dart` 11 adet) | `FinanceCard` sadece 6 dosyada kullanılıyor (`analysis_screen.dart`, `payslip_view.dart`, `assets_screen.dart`, `cashflow_screen.dart`, `dashboard_screen.dart`, `fees_view.dart`) — kalan 20 dosya kendi kartını icat ediyor | Tutarsız gölge/border/radius riski, bakım yükü | Mevcut `FinanceCard`'ı genişletip (ör. `compact`/`flat` varyant parametresi) tüm ekranlarda zorunlu kıl | Yok | — | **P1** (en yüksek etki/en düşük risk — mevcut widget zaten var, sadece benimsetme işi) |
| Dashboard net bakiye (`dashboard_screen.dart:749` `RollingNumberTicker`) | İyi çalışıyor, reduce-motion destekli | Yok — pozitif örnek | Değişmesin | 300ms M3 emphasized-decelerate (mevcut) | — | — (örnek alınacak referans) |
| Analiz sekmesi grafik (`analysis_screen.dart` `_buildDistributionTab`) | `fl_chart` (DOĞRULANMADI: grafik tipi detaylı okunmadı, kapsam zaman kısıtı) | — | — | — | fl_chart (zaten var) | — |
| Alt navigasyon (`floating_capsule_nav_bar.dart`) | Sade, doğru; yorum metni yanıltıcı (§2) | Görsel sorun yok, yalnız yorum/isimlendirme | Yorum güncellensin | 240ms easeOutCubic (mevcut, token'a değil sabit sayıya bağlı — `AppMotion.short=220` ile 20ms fark) | — | P4 |
| Segment bar (`morphing_segmented_bar.dart`) | Aynı durum — iyi çalışıyor, yorum abartılı | Görsel sorun yok | Yorum güncellensin; `280ms` zaten `AppMotion.medium` ile eşleşiyor ama sabit yazılmış, token'a bağlanmamış | — | — | P4 |

**Not:** Brief'in istediği "Paket" sütunu büyük ölçüde boş bırakıldı çünkü mevcut sorunların hiçbiri yeni paket gerektirmiyor — hepsi var olan widget'ların (özellikle `FinanceCard`) daha disiplinli kullanılmasıyla çözülüyor. Bu, §6'daki paket değerlendirmesiyle tutarlı: "minimum ama doğru" ilkesi burada da geçerli.

---

## 5. Ekran Bazlı UX Değerlendirmesi

### Dashboard (`dashboard_screen.dart`)
İlk bakışta: üst bar → ay seçici kapsül → net bakiye hero kartı (gelir/gider ikili döküm) → yaklaşan taksitler → son işlemler. Hiyerarşi mantıklı, finansal "en önemli sayı en üstte" ilkesine uyuyor (Monzo/N26 benzeri). `FinanceCard` burada tutarlı kullanılmış, dark-mode-aware. Gereksiz kart yok. Tek pazarlama dokunuşu boş-durum kartındaki motto + sparkle ikonu (§2) — minör. **Bu ekran, dark-mode kapsamına da girmiş olması tesadüf değil; genel olarak en olgun ekran.**

### Analiz (`analysis_screen.dart`)
4 sekmeli yapı (`MorphingSegmentedBar`: Dağılım/Aylık Trend/Masraflar/Maaş-Vergi) — tek ekranda 4 farklı veri görünümünü sekmeyle ayırmak doğru bir karar (ayrı ayrı ekran açmaktan daha az gezinme). Kategori detay sheet'i (`_showCategoryDetail`) iyi bilgi mimarisine sahip (toplam + yüzde + kapat) ama §3.2'deki radius tutarsızlığını taşıyor ve dark-mode'a hiç uyarlanmamış (`Colors.white` sabit, `:170,205`). Grafiğin "gerçekten faydalı mı" sorusu — **DOĞRULANMADI**, `fl_chart` çağrısının tam parametreleri (ör. gerçek vs. abartılı ölçek) bu turda satır satır incelenmedi.

### Ekstre/Bordro Yükleme (`statement_upload_sheet.dart`)
Akış: tür seçimi → dosya seçici → önizleme/uzlaşma banner'ı → toplu rapor. Güven unsurları doğru yerleştirilmiş: `Icons.shield_rounded` + "gizlilik rozeti" başlığın yanında (`:690-699`), uzlaşma banner'ı (`_buildReconciliationBanner`) ile "banka toplamıyla eşleşti mi" kontrolü kullanıcıya gösteriliyor — bu tam olarak finans uygulamalarında güven inşa eden türden bir detay. Sorun görsel değil: 1299 satırlık tek `State` sınıfı (ARCH-09'da not edilmiş, tekrarlanmıyor) ve §3.2/3.3'teki radius/fontSize savrulması bu dosyada yoğunlaşmış (tek dosyada 5 farklı radius, 28 farklı `TextStyle` çağrısı).

### Yaklaşan Ödemeler (ayrı ekran değil — Dashboard'un bir bloğu)
`_buildUpcomingInstallmentsBlock` (`dashboard_screen.dart:918`) kart borcu ile taksit satırını aynı listede, `row_kind` ayrımıyla farklı biçimde gösteriyor (`:967` `isCardDue`). Bilgi önceliklendirmesi doğru (son ödeme tarihi + asgari tutar kart borcunda, taksit kalanı taksitte). **Not:** Brief bunu "ekran" olarak saydı ama kodda bağımsız bir ekran yok, Dashboard'a gömülü bir blok — bu rapor ayrı ekran icat etmedi, mevcut yapıyı olduğu gibi değerlendirdi.

### Hedefler/Varlıklar (`goals_screen.dart`, `assets_screen.dart`)
Goals ekranı: özet header + filtre segment + kart listesi + boş-durum (mavi daire + bayrak ikonu, iyi bir boş-durum örneği). Assets ekranı 2401 satırla uygulamanın en büyük dosyası (ARCH-09) ve en çok ad-hoc `BoxDecoration` içeren ekran (16 adet) — döviz/altın/araç/kart olmak üzere 4 farklı varlık türünü tek ekranda sekmelerle yönetiyor; bu veri çeşitliliği göz önüne alınırsa sekme sayısı/bilgi yoğunluğu mantıklı ama görsel tutarlılık (radius/renk) en çok burada dağılmış durumda — §3'teki bulguların çoğu bu dosyadan örneklendi.

---

## 6. Paket Değerlendirmesi (ÖNERİ — KURULMADI)

Brief'in bahsettiği 5 paket, mevcut Flutter 3.47.5/Dart 3.13.4 kurulumuna göre değerlendirildi (pub.dev sayfaları bu oturumda çekildi; sürüm/uyumluluk bilgisi pub.dev'in genel paket sayfasından alındı, pubspec.yaml içeriği tek tek doğrulanmadı → **DOĞRULANMADI** olarak işaretlenen kısımlar var):

| Paket | Son sürüm (pub.dev) | SDK uyumu | Gerekli mi? | Not |
|---|---|---|---|---|
| `flutter_animate` | 4.5.2 | Minimum SDK kısıtı sayfada görünmedi — **DOĞRULANMADI** | **Hayır, gerekli değil.** Mevcut `AppMotion` + `AnimatedContainer`/`AnimatedPositioned`/`AnimatedDefaultTextStyle` zaten tüm ihtiyacı karşılıyor (bkz. `morphing_segmented_bar.dart`, `rolling_number_ticker.dart`) ve reduce-motion desteğini elle doğru yönetiyor. Bu paket soyutlama katmanı ekler ama **yeni bir görsel yetenek getirmez** — "minimum ama doğru" ilkesiyle çelişir. | Kurulmazsa APK boyutuna etkisi: yok (zaten kurulmadı) |
| `animations` (resmi Flutter paketi, Material motion) | 3.0.0 | **DOĞRULANMADI** | **Hayır.** `FadeThroughIndexedStack` zaten kendi fade-through implementasyonunu taşıyor (`lib/core/widgets/fade_through_indexed_stack.dart`) ve test edilmiş (`test/fade_through_indexed_stack_test.dart`). Paketi eklemek aynı işi iki yerde yapmak olur. | — |
| `lottie` | 3.6.1 | **DOĞRULANMADI** | **Hayır — brief'in kendi ilkesiyle çelişir.** Lottie dosyaları genelde stok/jenerik animasyon kütüphanelerinden gelir (confetti, karakter animasyonları) — bu tam olarak "AI/şablon ürün" hissini güçlendiren türden bir eklentidir, "sahte/anlamsız süs" riskiyle örtüşür. Uygulamanın hiçbir ekranında şu an Lottie gerektiren bir boşluk yok (boş-durumlar zaten statik ikon+metinle doğru çözülmüş). | Eklenirse: `lottie` paketinin kendisi küçük (~200KB) ama her `.json` animasyon dosyası ek boyut getirir — ölçülmedi, DOĞRULANMADI |
| `flex_color_scheme` | 9.0.0 | **"Flutter 3.47 veya üstü gerektirir"** (pub.dev sayfasında açıkça yazıyor) — proje tam olarak **3.47.5** kullanıyor, yani **sınırda uyumlu, tamponsuz** | **Hayır, önerilmiyor.** Proje zaten elle yazılmış, anlaşılır bir `AppTheme`/`AppColors` çiftine sahip ve koyu mod ilk dilimi bu elle yazılmış sistemle uyumlu şekilde ilerliyor. `flex_color_scheme`'e geçmek koyu mod işini **sıfırdan** bu paketin şema diline taşımak demektir — yarım kalmış koyu-mod geçişinin ortasında büyük bir mimari değişiklik, risk/getiri dengesi kötü. | Versiyon marjı sıfıra yakın olduğu için ayrıca bir Flutter patch güncellemesinde uyumsuzluk riski var |
| `home_widget` (Android ana ekran widget'ı) | 0.10.0 | **DOĞRULANMADI** | **Hayır — kapsam dışı.** Bu bir *yeni özellik* (ana ekran widget'ı) önerisidir; brief'in kendi kuralı "yeni özellik önerme" ile çelişir. Değerlendirme sadece tamlık için yapıldı. | — |

**Genel sonuç:** 5 paketin **hiçbiri önerilmiyor**. Mevcut sorunların tamamı (§3, §4) paket eksikliğinden değil, var olan token/widget sisteminin tutarsız uygulanmasından kaynaklanıyor. Yeni paket eklemek APK boyutunu ve bakım yüzeyini büyütür ama bu raporun bulduğu hiçbir sorunu çözmez.

---

## 7. Öncelikli Aksiyon Listesi

| # | Öncelik | Aksiyon | Risk | Etki | Kanıt |
|---|---|---|---|---|---|
| 1 | **P1** | `FinanceCard`'ı 20 ad-hoc kart dosyasında (`assets_screen.dart`, `statement_upload_sheet.dart`, `settings_screen.dart`, `goal_card_tile.dart` vb.) zorunlu hale getir; yeni kart yazımını yasakla (kod incelemesi kuralı) | Düşük (widget zaten var, davranış değişmiyor) | Yüksek (en görünür tutarsızlık kaynağı) | §3.1, §4 tablo satır 4 |
| 2 | **P1** | Alt sayfa (`showModalBottomSheet`) köşe yarıçapını her yerde tema varsayılanına (`AppRadius.sheet=24`) bağla; `statement_upload_sheet.dart:637` ve `analysis_screen.dart:206`'daki elle yazılmış `28`'i kaldır | Düşük | Orta-Yüksek (sheet'ler arası görsel tutarlılık) | §3.2 |
| 3 | **P2** | `AppTypography` ölçeğini tanımla (§3.5 taslağı) ve en az dashboard/analysis/goals'ta pilot uygula; 25 farklı `fontSize` değerini 6-8 adıma indir | Düşük-Orta (çok satır değişir ama görsel davranış aynı kalır) | Yüksek (uzun vadede en büyük tutarlılık kazancı) | §3.3 |
| 4 | **P2** | `Icons.auto_awesome_rounded` kullanımını (`fintech_components.dart:97`, `dashboard_screen.dart:1164`) İzci maskotuna özgü bir simgeyle değiştir; "AI sparkle" çağrışımını azalt | Düşük | Orta (marka kimliği netleşir) | §2 |
| 5 | **P3** | Ad-hoc hex renkleri (`#6366F1`, `#F59E0B` tekrarları vb.) `AppColors` sabitlerine bağla; yeni renk eklenmeden önce paletle eşleşip eşleşmediği kontrol edilsin | Düşük | Orta (palet güncellemesi tek noktadan yönetilir) | §3.4 |
| 6 | **P3** | Widget doc-comment'lerindeki "Shakuro/neon/ultra modern/Video Micro-Interaction" ifadelerini gerçek, sade görsel davranışı anlatan nötr açıklamalarla değiştir (`floating_capsule_nav_bar.dart:5-7`, `morphing_segmented_bar.dart:10-12`, `rolling_number_ticker.dart:6-9`); `AGENTS.md`'deki aynı ifadelerle birlikte ele alınabilir (ARCH-19 çapraz referans) | Düşük (yalnız yorum) | Düşük-Orta (gelecekteki yanlış yönlendirmeyi önler) | §2 |
| 7 | **P3** | `goal_card_tile.dart`/`goal_summary_header.dart`'ı `FinanceCard` tabanına taşı (madde 1'in parçası ama Goals'a özgü ikinci bir bileşen seti olduğu için ayrı madde) | Düşük | Orta | §4 |
| 8 | **P4** | Dashboard boş-durum kartındaki `#6366F1` ad-hoc gradyan rengini `AppColors`'a taşı | Düşük | Düşük | §3.4, §4 |

**Kapsam dışı / devam eden iş (yeniden keşfedilmedi, sadece not edildi):**
- Koyu mod yaygınlaştırması (kalan ~4 ana ekran + sheet'ler) — bilinen devam işi, bu raporun kapsamı değil.
- `assets_screen.dart`/`statement_upload_sheet.dart`'ın bölünmesi (modülerlik) — ARCH-09.
- Yerelleştirme kapsamı (179 sabit literal vs 130 `AppStrings` referansı) — ARCH-11.
- Tarih biçimlendirme kopyaları — ARCH-12.
- Widget/golden test eksikliği — not edildi (§1 tablo) ama test stratejisi kararı docs/audit kapsamında, burada aksiyon olarak maddelenmedi.

---

## 8. Kapsam dışı bırakılanlar / DOĞRULANMADI işaretli noktalar

- `fl_chart` grafiklerinin veri/ölçek doğruluğu tek tek incelenmedi (zaman kısıtı) — **DOĞRULANMADI**.
- 5 önerilen paketin tam SDK alt sınırı pub.dev genel sayfasından okundu, `pubspec.yaml` düzeyinde derleme denemesi yapılmadı (kurulum bu turda yasaktı) — **DOĞRULANMADI**.
- Ekran okuyucu (TalkBack) ile gerçek cihaz testi yapılmadı — ARCH-13'te de aynı şekilde DOĞRULANMADI işaretli, tekrar ediliyor çünkü bu da bir UX/erişilebilirlik bulgusu.
- Golden test dosyası aranmadı dosya içeriği düzeyinde (yalnız dosya adlarına bakıldı) — **DOĞRULANMADI**.

---

*Bu rapor bir analiz belgesidir; hiçbir kod değiştirilmedi, hiçbir paket kurulmadı. Uygulamaya geçiş, kullanıcının onayı ve ayrı bir çalışma turu gerektirir.*
