> Taslak: Claude (FinScout pazarlama uzmanı) üretti (29.09.2026). Kullanıcı onayı bekliyor.
> Kaynak kararlar: F4-01 (bütçe), F4-03 (yasaklı terim), F4-04 (kanal sırası — bu, "SONRA" aşamasıdır). Rakip kaynağı: `rakip_taramasi.md`.
> **Bu bir hazırlık notudur, kampanya HENÜZ başlatılmaz.** F4-04'e göre önce ASO + organik video + forum (bkz. `organik_faz_brifi.md`), dönüşüm organik trafikte ölçülünce bu nota geçilir.

# FinScout — Google App Kampanyası Hazırlık Notu

## Ne zaman başlar
- F4-01: ilk 30 gün ₺0 (organik). Dönüşüm (kurulum → hesap → deneme) organik kanallarda ölçülüp yeterli görüldüğünde **₺5.000/ay** ile test başlar.
- "Yeterli görülme" eşiği önceden tanımlanmadı — veri yok. Önerilen yaklaşım: organik dönemde en az 2 hafta, en az birkaç yüz kurulumluk veri toplanmadan Ads'e geçilmemesi (rakamı yükseltmek/düşürmek kullanıcı kararı).

## Bütçe ve hedef (F4-01)
- Test bütçesi: ₺5.000/ay (~₺165/gün).
- Optimizasyon hedefi: Google Ads Universal App Campaign'de "uygulama içi işlem" hedefi seçilebiliyorsa **hesap oluşturma** veya **ilk belge yükleme** olayı hedeflenmeli — ham "yükleme" hedefi tek başına düşük niyetli trafik getirebilir. (Bu olayların analytics/conversion tracking tarafı ayrı bir mühendislik işi; bu not yalnız pazarlama tarafını kapsıyor.)
- Hedef CPA: **veri yok** — yeni ürün, geçmiş dönüşüm verisi yok. İlk 2 hafta "öğrenme modu"nda hedef CPA yerine bütçe sınırlı otomatik teklif kullanılması, gerçek CPA'nın gözlemlenmesi önerilir.

## Anahtar kelime kümeleri (F4-03'e uygun — yasaklı terim HARİÇ)

**Kullanılacak kümeler:**
| Küme | Örnek terimler | Dayanağı |
|---|---|---|
| Ekstre okuma / PDF | "ekstre okuma uygulaması", "pdf ekstre analiz", "kredi kartı ekstresi uygulama" | Ürünün ana işlevi |
| Masraf/vergi dökümü | "kredi kartı masraf takibi", "bsmv kkdf hesaplama", "kart aidatı takibi" | Faiz/BSMV/KKDF/aidat kalem kalem gösterimi |
| Bordro | "bordro analiz uygulaması", "maaş bordrosu okuma", "bordro kesinti hesaplama" | Bordro PDF okuma özelliği |
| Otomasyon mesajı | "elle girişe son", "otomatik harcama takibi", "harcama takibi pdf" | F4-02 konumlandırması |
| Hatırlatma | "son ödeme tarihi hatırlatma", "kredi kartı taksit takibi" | Son ödeme/taksit bildirimi |

**Kullanılmayacak / hariç tutulacak terimler (F4-03 ve türevleri):**
- "kredi kartı aidatı iadesi", "aidat iadesi", "ücret iadesi", "kart aidatı geri alma", "kredi kartı iadesi" — bunlar ayrı bir hizmet kategorisini (aidat iadesi danışmanlığı/hukuk hizmeti) çağrıştırıyor, FinScout'un yaptığından farklı ve yanıltıcı.
- Rakip marka/banka adları anahtar kelime olarak kullanılmaz (mevcut kural, `REKLAM_BRIFING.md`).

**Önerilen negatif anahtar kelimeler (yeni öneri, F4-03'ün ruhuna uygun):**
- "iade", "geri ödeme", "dava", "avukat", "şikayet dilekçesi" — bu terimlerle arama yapan kullanıcılar büyük olasılıkla bir hukuki/idari iade süreci arıyor, FinScout'un ürünüyle örtüşmüyor; bu trafiği filtrelemek reklam harcamasını verimli kullanır.
- **Nasıl test edilir:** Kampanya raporunda "arama terimleri" (search terms) sekmesi 2 haftalık aralıkla incelenir; negatif listeye eklenen terimlerin gösterim/tıklama payı düşüşü izlenir.

## Reklam öğeleri
- Başlık/açıklama metinleri için yeni üretim gerekmiyor — mevcut `reklam_metinleri.md`'deki Google App Kampanyası bölümü (10 başlık, 5 açıklama) zaten F4-03'e uyumlu, doğrudan kullanılabilir.
- **Dikkat:** `reklam_plani.md`'nin "4. Kanal Planı" bölümünde Google Ads için örnek anahtar kelime kümesinde **"kredi kartı aidatı iadesi"** geçiyor — bu artık F4-03 ile çelişiyor (o dosya yazıldığında bu karar henüz yoktu). O dosyaya kısa bir düzeltme notu eklendi (bkz. rapor), asıl anahtar kelime kümesi olarak bu belgedeki liste kullanılmalı.

## Ölçüm
- Play Console + Google Ads bağlantısı üzerinden: gösterim → tıklama → kurulum → (varsa) uygulama içi olay dönüşümü.
- Organik dönemle (F4-01, ₺0) kıyaslanacak temel metrik: kurulum başına ilk belge yükleme oranı — Ads trafiğinin organik trafikten daha düşük "niyet" taşıyıp taşımadığını gösterir.
- Veri yok: sektör ortalaması CPA/CPI karşılaştırması (FinScout'a özgü araştırma yapılmadı, uydurulmadı).
