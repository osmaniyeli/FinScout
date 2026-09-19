// lib/core/parser/merchant_sanitizer.dart

class MerchantSanitizer {
  static final RegExp _gatewayPrefixes = RegExp(
    r'^(?:IYZICO/|PAYTR[\.\/]|SİPAY(?:\s+ELEK)?/|ÖDEAL//|SQUARE\s*\*|PAYPAL\s*\*|POS\s*\d+\s*-?)(.+)',
    caseSensitive: false,
  );

  /// 'IYZICO/WAT MOBİLİTE İSTANBUL TR' -> 'WAT MOBİLİTE'
  static String sanitize(String rawMerchant) {
    String cleaned = rawMerchant.trim();
    final match = _gatewayPrefixes.firstMatch(cleaned);
    if (match != null) {
      cleaned = match.group(1)!.trim();
    }
    
    // Şehir ve Ülke Eklerini Temizleme ('İSTANBUL TR', 'KOCAELI TR')
    cleaned = cleaned.replaceAll(RegExp(r'\s+(İSTANBUL|KOCAELİ|ANKARA|İZMİR|SAMSUN|TEKİRDAĞ)?\s*TR$', caseSensitive: false), '');
    return cleaned.trim();
  }

  /// Temizlenmiş metne göre dahili kategori ID'si döndürür
  static String resolveCategory(String cleanMerchant) {
    final upper = cleanMerchant.toUpperCase();

    if (upper.contains('BIM') || upper.contains('A-101') || upper.contains('A101') || 
        upper.contains('SOK') || upper.contains('HAKMAR') || upper.contains('FILE') || upper.contains('CARREFOUR')) {
      return 'cat_market';
    }
    if (upper.contains('OPET') || upper.contains('SHELL') || upper.contains('PETROL OFISI') || upper.contains('WAT MOBILITE')) {
      return 'cat_fuel';
    }
    if (upper.contains('SITAXI') || upper.contains('TOPLU TASIMA') || upper.contains('BELBIM') || upper.contains('ISTANBULKART')) {
      return 'cat_transit';
    }
    if (upper.contains('YUSUF') || upper.contains('FIRIN') || upper.contains('LOKANTA') || 
        upper.contains('KEBAP') || upper.contains('TRENDYOL YEMEK') || upper.contains('YEMEKSEPETI')) {
      return 'cat_dining';
    }
    if (upper.contains('GOOGLE') || upper.contains('SPOTIFY') || upper.contains('CLAUDE') || upper.contains('XBOX') || upper.contains('DISNEY')) {
      return 'cat_subscriptions';
    }
    if (upper.contains('VODAFONE') || upper.contains('PALGAZ') || upper.contains('SEPAS') || upper.contains('SUPERONLINE') || upper.contains('ISU')) {
      return 'cat_utilities';
    }
    if (upper.contains('VERGI DAIRESI') || upper.contains('MOTORLU TASITLAR')) {
      return 'cat_tax';
    }

    return 'cat_general'; // Belirsiz pazar yerleri ve yerel satıcılar için
  }
}