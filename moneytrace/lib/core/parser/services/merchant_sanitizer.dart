// lib/core/parser/services/merchant_sanitizer.dart

class MerchantSanitizer {
  // Sanal POS ve ödeme kuruluşu önekleri: "IYZICO/X", "IYZICO  *X", "PAYTR.  *X", "PAYTR/X", "ÖDEAL//X"
  static final RegExp _gatewayPrefixes = RegExp(
    r'^(?:IYZICO|İYZİCO|PAYTR|SİPAY(?:\s+ELEK)?|SIPAY(?:\s+ELEK)?|ÖDEAL|ODEAL|PARAM|MOKA|PARATIKA|SQUARE|PAYPAL|GARANTI\s*POS|POS\s*\d+)[\s.\/*\-]+(.+)',
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

  /// Anahtar kelime → kategori tablosu (ASCII'ye katlanmış, büyük harf).
  /// Eşleşme kelime başında aranır; 3 karakter ve altı kalıplar tam kelime olmalıdır
  /// ("PET" → "PET SHOP" eşleşir ama "PETROL" eşleşmez; "SOK" → "SOKAK" eşleşmez).
  /// Sıra önemlidir: daha özgül kategoriler (akaryakıt) genel olanlardan (market) önce gelir.
  static const Map<String, List<String>> _rules = {
    'cat_fuel': [
      'OPET', 'SHELL', 'PETROL OFISI', 'BP', 'TOTAL ENERGIES', 'TOTALENERGIES', 'AYGAZ', 'AKARYAKIT', 'PETROL',
      'WAT MOBILITE', 'NATIONAL FUEL', 'LUKOIL', 'ZES', 'TRUGO', 'ESARJ', 'E-SARJ', 'ALPET', 'KADOIL', 'MOIL',
    ],
    'cat_insurance': ['SIGORTA', 'ALLIANZ', 'ANADOLU HAYAT', 'EMEKLILIK', 'BES KATKI', 'AXA', 'MAPFRE', 'HDI'],
    'cat_subscriptions': [
      'YOUTUBE', 'SPOTIFY', 'NETFLIX', 'DISNEY', 'APPLE.COM', 'ITUNES', 'GOOGLE ONE', 'GOOGLE PLAY', 'MICROSOFT',
      'XBOX', 'PLAYSTATION', 'STEAM', 'BLUTV', 'EXXEN', 'GAIN MEDYA', 'AMAZON PRIME', 'CLAUDE', 'ANTHROPIC', 'OPENAI',
      'CHATGPT', 'ICLOUD', 'DROPBOX', 'ADOBE', 'CANVA',
    ],
    'cat_utilities': [
      'VODAFONE', 'TURKCELL', 'TURK TELEKOM', 'TELEKOM', 'PALGAZ', 'SEPAS', 'ENERJISA', 'ISKI', 'ASKI', 'ISU',
      'SUPERONLINE', 'DIGITURK', 'D-SMART', 'IGDAS', 'BASKENTGAZ', 'CK ENERJI', 'ELEKTRIK DAGITIM', 'TTNET',
    ],
    'cat_tax': ['VERGI DAIRESI', 'MOTORLU TASITLAR', 'GELIR IDARESI', 'BELEDIYE', 'HARC', 'MTV', 'GIB'],
    'cat_home': [
      'HIRDAVAT', 'HIRDAVA', 'MR DIY', 'MRDIY', 'MR. DIY', 'KOCTAS', 'IKEA', 'BAUHAUS', 'TEKZEN', 'ENGLISH HOME', 'MADAME COCO',
      'KARACA', 'MOBILYA', 'YAPI MARKET', 'NALBURIYE', 'ELEKTRIK', 'ELEKTRIKLI',
    ],
    'cat_market': [
      'BIM', 'A-101', 'A101', 'SOK', 'HAKMAR', 'FILE', 'MOPAS', 'CARREFOUR', 'MIGROS', 'MACROCENTER', 'HIPERMARKET',
      'SUPERMARKET', 'MARKET', 'MARKETLERI', 'BAKKAL', 'MANAV', 'KASAP', 'ET URUNLERI', 'SARKUTERI', 'GETIR', 'ISTEGELSIN',
    ],
    'cat_transit': [
      'SITAXI', 'TAKSIDE POS', 'TAKSI', 'TOPLU TASIMA', 'BELBIM', 'ISTANBULKART', 'KENTKART', 'UBER', 'BITAKSI',
      'MARTI', 'TCDD', 'OTOBAN', 'HGS', 'OGS', 'OTOPARK', 'ISPARK', 'OTOGAR', 'METRO TURIZM', 'KAMIL KOC',
    ],
    'cat_dining': [
      'FIRIN', 'LOKANTA', 'LOKANTASI', 'RESTORAN', 'RESTAURANT', 'KEBAP', 'DURUM', 'IZGARA', 'BOREK', 'BOREKCI',
      'KAHVE', 'STARBUCKS', 'ESPRESSOLAB', 'TRENDYOL YEMEK', 'YEMEKSEPETI', 'BURGER', 'PIZZA', 'CAFE', 'KAFE',
      'PASTANE', 'PASTANESI', 'TATLI', 'TATLIBAK', 'BUFE', 'EKMEK', 'SIMIT', 'DONER', 'KOFTE', 'MANTI', 'BALIK',
    ],
    'cat_pet': ['PETSHOP', 'PET SHOP', 'AKVARYUM', 'VETERINER', 'PETLEBI', 'PET'],
    'cat_kids': ['LUNAPARK', 'LUNASAN', 'FUNKIDS', 'OYUNCAK', 'BOWLING', 'TOYZZ', 'OYUN PARKI', 'OYUN ALANI'],
    'cat_investment': ['KUYUMCU', 'KUYUMCULUK', 'MUCEVHERAT', 'ALTIN', 'EMIN EVIM', 'EMINEVIM', 'BINANCE', 'BTCTURK', 'MIDAS', 'PARIBU'],
    'cat_clothing': [
      'ZARA', 'MANGO', 'LCW', 'LC WAIKIKI', 'DEFACTO', 'KOTON', 'MAVI', 'BERSHKA', 'H&M', 'PULL&BEAR', 'GIYIM',
      'TEKSTIL', 'AYAKKABI', 'FLO', 'COLINS', 'BOYNER', 'DERIMOD',
    ],
    'cat_health': [
      'ECZANE', 'ECZANESI', 'HASTANE', 'HASTANESI', 'SAGLIK', 'MEDIKAL', 'DOKTOR', 'TIP MERKEZI', 'OPTIK',
      'DIS KLINIGI', 'LABORATUVAR', 'POLIKLINIK',
    ],
    'cat_shopping': ['TRENDYOL', 'HEPSIBURADA', 'AMAZON', 'N11', 'CICEKSEPETI', 'LETGO', 'SAHIBINDEN', 'PAZARAMA', 'IKAS'],
    'cat_electronics': ['TEKNOSA', 'MEDIAMARKT', 'VATAN BILGISAYAR', 'APPLE STORE', 'SAMSUNG', 'XIAOMI', 'GSM SHOP'],
    'cat_travel': ['OTEL', 'HOTEL', 'WYNDHAM', 'TURIZM', 'THY', 'TURK HAVA YOLLARI', 'PEGASUS', 'AJET', 'OBILET', 'ENUYGUN'],
    'cat_education': ['OKUL', 'UNIVERSITE', 'KOLEJ', 'KIRTASIYE', 'KITAP', 'EGITIM', 'KURS'],
    'cat_personal_care': ['GRATIS', 'WATSONS', 'ROSSMANN', 'EVE SHOP', 'KUAFOR', 'BERBER', 'GUZELLIK'],
  };

  /// Temizlenmiş işyeri adını kelime sınırlı anahtar kelime eşleşmesiyle kategoriye bağlar.
  static String resolveCategory(
    String cleanMerchant, {
    Map<String, String>? userMemoryRules,
  }) {
    final folded = fold(cleanMerchant);

    // 1. Kullanıcı Hafıza Kuralları (Human-in-the-Loop)
    if (userMemoryRules != null) {
      for (final entry in userMemoryRules.entries) {
        if (folded.contains(fold(entry.key))) {
          return entry.value;
        }
      }
    }

    // 2. Anahtar kelime tablosu
    for (final rule in _rules.entries) {
      for (final keyword in rule.value) {
        if (_matchesKeyword(folded, keyword)) return rule.key;
      }
    }

    // Varsayılan Kategori
    return 'cat_general';
  }

  static bool _matchesKeyword(String text, String keyword) {
    final strict = keyword.length <= 3;
    var index = text.indexOf(keyword);
    while (index != -1) {
      final beforeOk = index == 0 || !_isAlnum(text.codeUnitAt(index - 1));
      final end = index + keyword.length;
      final afterOk = !strict || end >= text.length || !_isAlnum(text.codeUnitAt(end));
      if (beforeOk && afterOk) return true;
      index = text.indexOf(keyword, index + 1);
    }
    return false;
  }

  static bool _isAlnum(int c) => (c >= 48 && c <= 57) || (c >= 65 && c <= 90);

  /// Türkçe harfleri ASCII'ye katlar, büyük harfe çevirir.
  static String fold(String s) => s
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .toUpperCase()
      .replaceAll('İ', 'I')
      .replaceAll('Ş', 'S')
      .replaceAll('Ğ', 'G')
      .replaceAll('Ü', 'U')
      .replaceAll('Ö', 'O')
      .replaceAll('Ç', 'C')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
