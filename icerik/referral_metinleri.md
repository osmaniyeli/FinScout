> Taslak: Claude (FinScout pazarlama uzmanı) üretti (29.09.2026). Kullanıcı onayı bekliyor.
> Kaynak karar: F4-14 — "Arkadaş davet (referral): davet eden ve edilen 1 ay ek belge hakkı kazanır." Kod tarafı (davet kodu/link üretimi, ödül tetikleme) ayrı bir mühendislik işi; bu dosya yalnız ekranda görünecek metni içerir. Format, mevcut `aile_rehberi.md`'deki davet kodu mekaniğiyle (Ayarlar > Aile, kod üretme/girme) tutarlı varsayılmıştır — mühendislik farklı bir mekanizma (ör. deep link) seçerse metin buna göre uyarlanmalı.

# FinScout — Arkadaşını Davet Et Ekranı Metinleri

## Şablon 1: Davet ekranı başlığı ve açıklaması
- **Başlık:** Arkadaşını Davet Et
- **Açıklama:** Arkadaşın davetini kabul edip FinScout'u kullanmaya başladığında, ikinizin de belge yükleme hakkına 1 ay ekstra eklenir.
- **CTA buton:** Davet Kodumu Paylaş

## Şablon 2: Paylaşım mesajı (kullanıcı davet linkini/kodunu paylaştığında dışarı giden metin)
- **Metin:** "FinScout'u kullanıyorum — kredi kartı ekstresi ve bordronu PDF'ten otomatik okuyup masraflarını, vergilerini kalem kalem gösteriyor. Bu kodla katılırsan ikimiz de 1 ay ekstra belge hakkı kazanıyoruz: [KOD/LİNK]"
- **Not:** "ücretsiz" veya "sınırsız" gibi kodda karşılığı olmayan ifade kullanılmaz; yalnız gerçek ödül (1 ay ek belge hakkı) belirtilir.

## Şablon 3: Davet kodu girme ekranı
- **Başlık:** Davet Kodun Var mı?
- **Açıklama:** Bir arkadaşından aldığın kodu gir; ikinizin de belge yükleme hakkına 1 ay ekstra eklensin.
- **Alan etiketi:** Davet Kodu
- **CTA buton:** Kodu Uygula

## Şablon 4: Başarı durumu (kod kabul edildiğinde)
- **Başlık:** Davet Tamamlandı
- **Metin:** Belge yükleme hakkına 1 ay ekstra eklendi. Arkadaşına da aynı ödül tanımlandı.

## Şablon 5: Hata/geçersiz kod durumu
- **Metin:** Bu kod geçerli değil veya süresi dolmuş. Kodu gönderen arkadaşından güncel kodu isteyebilirsin.

## Şablon 6: Push bildirimi — davet kabul edildiğinde (davet edene gönderilir)
*(`bildirim_sablonlari.md` formatına uygun, o dosyaya ek olarak kullanılabilir — dosya ezilmedi, yalnız burada referans olarak tutuluyor.)*
- **Başlık:** Davetin Kabul Edildi
- **Metin:** Arkadaşın davetini kullandı; belge yükleme hakkına 1 ay ekstra eklendi.
- **Tetiklenme Koşulu:** Davet edilen kullanıcı kodu başarıyla uyguladığında, davet eden kullanıcıya gönderilir.

## Netleştirilmesi gereken noktalar (mühendislik + ürün kararı, metin bunları varsaymadan bırakıyor)
- Ödül sınırı var mı (ör. ayda en fazla kaç davet ödül kazandırır)? Karar F4-14'te belirtilmemiş — "veri yok". Kötüye kullanımı (sınırsız kendi kendine davet vb.) önlemek için bir üst sınır önerilir, ama bu bir ürün/mühendislik kararı.
- Davet mekanizması kod mu, link mi, her ikisi mi? Bu dosya her ikisini de karşılayacak nötr dille yazıldı ("[KOD/LİNK]"), kesinleşince metin güncellenmeli.
- Ücretsiz kullanıcı mı yoksa yalnız premium kullanıcı mı davet edebilir? Belirtilmemiş — "veri yok".
