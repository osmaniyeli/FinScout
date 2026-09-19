// lib/core/parser/services/merchant_sanitizer.dart

class MerchantSanitizer {
  // Sanal POS ve Gateway Önekleri
  static final RegExp _gatewayPrefixes = RegExp(
    r'^(?:IYZICO/|PAYTR[\.\/]|SİPAY(?:\s+ELEK)?/|SIPAY(?:\s+ELEK)?/|ÖDEAL//|ODEAL//|SQUARE\s*\*|PAYPAL\s*\*|PARAM/|MOKA/|PARATIKA/|POS\s*\d+\s*-?|GARANTI\s*POS\s*-?)(.+)',
    caseSensitive: false,
  );

  // Şehir ve Ülke Ekleri
  static final RegExp _locationSuffixes = RegExp(
    r'\s+(İSTANBUL|ISTANBUL|KOCAELİ|KOCAELI|ANKARA|İZMİR|IZMIR|SAMSUN|TEKİRDAĞ|TEKIRDAG|BURSA|ANTALYA|GEBZE|KADIKÖY|KADIKOY)?\s*TR$',
    caseSensitive: false,
  );

  /// 'IYZICO/WAT MOBİLİTE İSTANBUL TR' -> 'WAT MOBİLİTE'
  static String sanitize(String rawMerchant) {
    String cleaned = rawMerchant.trim();

    // 1. Gateway önekini temizle
    final match = _gatewayPrefixes.firstMatch(cleaned);
    if (match != null) {
      cleaned = match.group(1)!.trim();
    }

    // 2. Şehir ve Ülke Eklerini Temizle
    cleaned = cleaned.replaceAll(_locationSuffixes, '').trim();

    // 3. Çoklu boşlukları tekle
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }

  /// Temizlenmiş marka adını ve açıklamasını ISO 18245 MCC & anahtar kelime eşleşmesiyle kategoriye bağlar.
  static String resolveCategory(
    String cleanMerchant, {
    Map<String, String>? userMemoryRules,
  }) {
    final upper = cleanMerchant.toUpperCase();

    // 1. Kullanıcı Hafıza Kuralları (Human-in-the-Loop)
    if (userMemoryRules != null) {
      for (final entry in userMemoryRules.entries) {
        if (upper.contains(entry.key.toUpperCase())) {
          return entry.value;
        }
      }
    }

    // 2. Market & Bakkaliye (MCC 5411, 5499)
    if (upper.contains('BIM') || upper.contains('BİM') ||
        upper.contains('A-101') || upper.contains('A101') ||
        upper.contains('SOK') || upper.contains('ŞOK') ||
        upper.contains('HAKMAR') || upper.contains('FILE') || upper.contains('FİLE') ||
        upper.contains('MOPAS') || upper.contains('MOPAŞ') ||
        upper.contains('CARREFOUR') || upper.contains('MIGROS') || upper.contains('MİGROS') ||
        upper.contains('MACROCENTER') || upper.contains('GROCERY') || upper.contains('MARKET')) {
      return 'cat_market';
    }

    // 3. Akaryakıt & Şarj (MCC 5541, 5542)
    if (upper.contains('OPET') || upper.contains('SHELL') ||
        upper.contains('PETROL OFISI') || upper.contains('PETROL OFİSİ') ||
        upper.contains('BP ') || upper.contains('TOTAL') || upper.contains('AYGAZ') ||
        upper.contains('WAT MOBILITE') || upper.contains('WAT MOBİLİTE') ||
        upper.contains('NATIONAL FUEL') || upper.contains('LUKOIL') ||
        upper.contains('ZES') || upper.contains('TRUGO') || upper.contains('E-SARJ')) {
      return 'cat_fuel';
    }

    // 4. Ulaşım & Taksi (MCC 4121, 4111)
    if (upper.contains('SITAXI') || upper.contains('TAKSIDE POS') || upper.contains('TAKSİ') ||
        upper.contains('TOPLU TASIMA') || upper.contains('TOPLU TAŞIMA') ||
        upper.contains('BELBIM') || upper.contains('BELBİM') ||
        upper.contains('ISTANBULKART') || upper.contains('İSTANBULKART') ||
        upper.contains('UBER') || upper.contains('BITAKSI') || upper.contains('BİTAKSİ') ||
        upper.contains('MARTI') || upper.contains('TCDD') || upper.contains('OTOBAN') || upper.contains('HGS')) {
      return 'cat_transit';
    }

    // 5. Yeme - İçme & Restoran (MCC 5812, 5814)
    if (upper.contains('YUSUF') || upper.contains('FIRIN') || upper.contains('LOKANTA') ||
        upper.contains('RESTORAN') || upper.contains('RESTAURANT') ||
        upper.contains('KEBAP') || upper.contains('DURUM') || upper.contains('DÜRÜM') ||
        upper.contains('IZGARA') || upper.contains('BOREK') || upper.contains('BÖREK') ||
        upper.contains('KAHVE') || upper.contains('STARBUCKS') || upper.contains('ESPRESSOLAB') ||
        upper.contains('TRENDYOL YEMEK') || upper.contains('YEMEKSEPETI') || upper.contains('YEMEKSEPETİ') ||
        upper.contains('BURGER') || upper.contains('PIZZA') || upper.contains('PİZZA') || upper.contains('CAFE')) {
      return 'cat_dining';
    }

    // 6. Dijital Abonelik (MCC 5734, 4899)
    if (upper.contains('GOOGLE') || upper.contains('YOUTUBE') ||
        upper.contains('SPOTIFY') || upper.contains('NETFLIX') ||
        upper.contains('DISNEY') || upper.contains('APPLE') ||
        upper.contains('MICROSOFT') || upper.contains('CLAUDE') || upper.contains('ANTHROPIC') ||
        upper.contains('OPENAI') || upper.contains('CHATGPT') ||
        upper.contains('XBOX') || upper.contains('PLAYSTATION') || upper.contains('STEAM') ||
        upper.contains('BLUTV') || upper.contains('GAIN')) {
      return 'cat_subscriptions';
    }

    // 7. Faturalar & Kamu Hizmetleri (MCC 4900, 9399)
    if (upper.contains('VODAFONE') || upper.contains('TURKCELL') || upper.contains('TELEKOM') ||
        upper.contains('PALGAZ') || upper.contains('SEPAS') || upper.contains('SEPAŞ') ||
        upper.contains('ENERJISA') || upper.contains('ENERJİSA') ||
        upper.contains('ISU') || upper.contains('İSU') || upper.contains('SUPERONLINE') ||
        upper.contains('DIGITURK') || upper.contains('D-SMART') || upper.contains('IGDAS') || upper.contains('İGDAŞ')) {
      return 'cat_utilities';
    }

    // 8. Vergi & Harçlar (MCC 9311)
    if (upper.contains('VERGI DAIRESI') || upper.contains('VERGİ DAİRESİ') ||
        upper.contains('MOTORLU TASITLAR') || upper.contains('MOTORLU TAŞITLAR') ||
        upper.contains('GELIR IDARESI') || upper.contains('GELİR İDARESİ') ||
        upper.contains('BELEDIYE') || upper.contains('BELEDİYE') ||
        upper.contains('HARC') || upper.contains('HARÇ') || upper.contains('MTV') || upper.contains('GIB')) {
      return 'cat_tax';
    }

    // 9. Ev & Yapı Market (MCC 5200, 5251)
    if (upper.contains('HIRDAVAT') || upper.contains('MR DIY') || upper.contains('MR. DIY') ||
        upper.contains('KOCTAS') || upper.contains('KOÇTAŞ') ||
        upper.contains('IKEA') || upper.contains('BAUHAUS') || upper.contains('TEKZEN')) {
      return 'cat_home';
    }

    // 10. Evcil Hayvan (MCC 5995)
    if (upper.contains('PETSHOP') || upper.contains('PET SHOP') || upper.contains('AKVARYUM') ||
        upper.contains('VETERINER') || upper.contains('VETERİNER') || upper.contains('PET')) {
      return 'cat_pet';
    }

    // 11. Çocuk & Eğlence (MCC 7996, 5945)
    if (upper.contains('LUNAPARK') || upper.contains('LUNASAN') ||
        upper.contains('FUNKIDS') || upper.contains('FUNKİDS') ||
        upper.contains('OYUNCAK') || upper.contains('BOWLING') || upper.contains('TOYZZ')) {
      return 'cat_kids';
    }

    // 12. Yatırım, Birikim & Altın (MCC 5094, 6051)
    if (upper.contains('KUYUMCU') || upper.contains('MUKELLEF') ||
        upper.contains('ALTIN') || upper.contains('MÜCEVHERAT') ||
        upper.contains('EMINEVIM') || upper.contains('EMİN EVİM') ||
        upper.contains('BINANCE') || upper.contains('BTCTURK') ||
        upper.contains('MIDAS') || upper.contains('MİDAS') || upper.contains('PARIBU')) {
      return 'cat_investment';
    }

    // 13. Giyim & Moda (MCC 5651)
    if (upper.contains('ZARA') || upper.contains('MANGO') || upper.contains('LCW') ||
        upper.contains('LC WAIKIKI') || upper.contains('DEFACTO') || upper.contains('KOTON') ||
        upper.contains('MAVI') || upper.contains('MAVİ') || upper.contains('BERSHKA') ||
        upper.contains('H&M') || upper.contains('PULL&BEAR')) {
      return 'cat_clothing';
    }

    // 14. Sağlık & Eczane (MCC 5912, 8099)
    if (upper.contains('ECZANE') || upper.contains('HASTANE') ||
        upper.contains('SAGLIK') || upper.contains('SAĞLIK') ||
        upper.contains('MEDIKAL') || upper.contains('MEDİKAL') ||
        upper.contains('DOKTOR') || upper.contains('TIP MERKEZI')) {
      return 'cat_health';
    }

    // Varsayılan Kategori
    return 'cat_general';
  }
}
