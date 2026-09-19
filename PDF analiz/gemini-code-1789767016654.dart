// lib/core/utils/currency_normalizer.dart

class CurrencyNormalizer {
  /// '1.637,38 TL', '1,155.00', '+18.237,58' formatlarını kuruş (cents) tamsayısına çevirir.
  static int toMinorUnits(String rawAmount) {
    String clean = rawAmount
        .replaceAll('TL', '')
        .replaceAll('TRY', '')
        .replaceAll('USD', '')
        .replaceAll(r'$', '')
        .replaceAll('€', '')
        .replaceAll('+', '')
        .trim();

    // Negatif işareti kontrolü
    bool isNegative = clean.startsWith('-');
    if (isNegative) {
      clean = clean.replaceFirst('-', '').trim();
    }

    // Kıta Avrupası / TR Formatı: 1.250,50 -> 1250.50
    if (clean.contains('.') && clean.contains(',')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (clean.contains(',')) {
      // Yalnızca virgül varsa: 363,84 -> 363.84
      clean = clean.replaceAll(',', '.');
    }

    final double value = double.tryParse(clean) ?? 0.0;
    final int cents = (value * 100).round();
    return isNegative ? -cents : cents;
  }
}