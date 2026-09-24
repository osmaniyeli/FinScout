# FinScout: reklam çalışması brifingi (Gemini için)

Sahip: **Gemini** (bu klasör: `pazarlama/`). Kod dosyalarına dokunma. Çıktıların Claude tarafından doğrulanır, sonra kullanıcı onaylar.

## Ürün gerçekleri (v3.7.0, yalnız bunları vaat et)
- Android kişisel finans uygulaması. Arayüz yalnız Türkçe.
- **Kredi kartı ekstresi PDF'ini ve maaş bordrosunu okur.** Faiz, gecikme faizi, BSMV, KKDF, kart aidatı, EFT/FAST/havale ücretleri ve vergiler kalem kalem gösterilir. Aylık ve takvim yılı toplamları çıkarılır (Analiz › Masraflar).
- Okunan ekstre, bankanın dönem toplamlarıyla karşılaştırılır. Tutarsa "Bankanın dönem toplamlarıyla eşleşti" yazar, tutmazsa uyarı verir.
- Taksitler, son ödeme tarihi, dönem borcu ve asgari tutar ekstreden okunur. Son ödeme hatırlatması telefon bildirimiyle gelir.
- Manuel gelir/gider girişi her pakette sınırsızdır. Hedefler ve varlıklar (altın, döviz, nakit, araç) tutulabilir.
- **Ekstre ve işlemler telefonda işlenir, sunucuya gönderilmez.** Sunucuda yalnız hesap bilgisi (ad, e-posta) ve abonelik durumu tutulur. Reklam ve reklam kimliği yoktur.
- İlk fazda desteklenen banka **tek**. Diğer bankalar "yakında". Reklamda ve mağazada **banka adı geçmez** ("desteklenen bankalar uygulamada listelenir").
- **Fiyatlar (Google Play):**

  | Paket | Fiyat | Belge hakkı |
  |---|---|---|
  | Ücretsiz | — | Ayda 1 belge |
  | Aylık | ₺79,99 | Ayda 3 belge |
  | Yıllık | ₺599,99 | Ayda 5 belge, 7 gün ücretsiz deneme |
  | Aile yıllık | ₺899,99 | Premium hakkı en fazla 4 kişiyle paylaşılır; herkesin verisi kendi telefonunda kalır |

- Durum: Play'de **dahili testte**. Açık/üretim yayını henüz yok. Reklam harcaması **üretim yayınından önce başlamaz**; şimdi hazırlık yapılır.

## Pazar içgörüleri (araştırmadan, kaynaklı)
- Türkiye'de Şikayetvar'da "kredi kartı aidatı" başlığında 78.189 şikâyet var. KKDF/BSMV şikâyetlerinde "ne olduğunu bilmiyorum" sık geçiyor.
- Yerli rakipler elle girişli. Play'de kart ekstresini PDF'ten okuyan tüketici uygulaması bulunamadı.
- Bankalar açık bankacılıkla kartları tek ekranda gösteriyor; "tüm kartlar tek yerde" artık bir fark değil. **Fark: masrafların kalem kalem görünmesi ve bankanın toplamıyla eşleşme.**
- ₺79,99/ay yerli rakiplerin üst bandında. Yıllık paket ve 7 günlük deneme daha güçlü teklif.

## Kurallar (kesin)
- Uygulamada olmayan özellik yok: açık bankacılık/otomatik banka bağlantısı yok, yapay zekâ danışmanı yok, "tüm bankalar" yok, "sınırsız" yok.
- "%100 güvenli", "kriptolu", "sıfır bilgi" gibi ispatlanamayan iddialar yok. Doğru ifade: "Ekstrelerin telefonunda işlenir, sunucuya gönderilmez."
- Banka adı ve logosu yok (Play "kimliğe bürünme / fikri mülkiyet" politikası). Rakip marka adı anahtar kelime olarak kullanılmaz.
- Sahte yorum, sahte indirme sayısı, uydurma istatistik yok. Her rakamın kaynağı yazılır.
- Finansal tavsiye gibi okunacak ifade yok ("şu kadar kazanırsın" gibi). Reklam Kurulu ve tüketici mevzuatına uyulur.
- Kişisel veri veya gerçek ekstre görüntüsü kullanılmaz; örnek ekranlar uydurma ama açıkça "örnek" veriyle hazırlanır.
- Metinler Türkçe; Play için İngilizce çeviri ayrıca.

## İstenen çıktılar (`pazarlama/` altına)
1. `reklam_plani.md`: hedef kitle segmentleri, konumlandırma cümlesi, 3 mesaj ekseni, kanal planı (Google Ads uygulama kampanyası, Play mağaza içi, Instagram/TikTok organik, Ekşi/forum/Şikayetvar görünürlüğü, influencer), bütçe senaryoları (₺0 / ₺5.000 / ₺20.000 aylık), yayın sonrası 30-60-90 gün takvimi, ölçüm (kurulum, deneme→abonelik dönüşümü, 1. gün/7. gün tutma).
2. `reklam_metinleri.md`: Google App kampanyası başlıkları (30 karakter) ve açıklamaları (90 karakter), en az 10'ar tane; 5 kısa video senaryosu (15 sn); 10 sosyal medya gönderi metni; her birinin hangi ürün gerçeğine dayandığı.
3. `aso_onerileri.md`: mevcut Play başlığı "FinScout Harcama Takibi, Bütçe" ve açıklamasına göre anahtar kelime ve metin önerisi. Biçim: MEVCUT → ÖNERİ → GEREKÇE → NASIL TEST EDİLİR.
4. `gorsel_brifi.md`: ekran görüntüsü ve öne çıkan görsel için sahne sahne brif. Banka logosu yok; örnek veri.
