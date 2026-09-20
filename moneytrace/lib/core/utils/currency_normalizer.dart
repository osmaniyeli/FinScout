// lib/core/utils/currency_normalizer.dart

class CurrencyNormalizer {
  /// '1.637,38 TL', '1,155.00', '+18.237,58' formatlarını kuruş (cents) tamsayısına çevirir.
  static int toMinorUnits(String rawAmount) {
    String clean = rawAmount
        .replaceAll('TL', '')
        .replaceAll('TRY', '')
        .replaceAll('USD', '')
        .replaceAll(r'$', '')
        .replaceAll('EUR', '')
        .replaceAll('€', '')
        .replaceAll('+', '')
        .replaceAll(' ', '')
        .trim();

    // Negatif işareti kontrolü
    final bool isNegative = clean.startsWith('-');
    if (isNegative) {
      clean = clean.replaceFirst('-', '').trim();
    }

    // Kıta Avrupası / TR Formatı: 1.250,50 -> 1250.50
    if (clean.contains('.') && clean.contains(',')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (clean.contains(',')) {
      // Yalnızca virgül varsa: 363,84 -> 363.84
      clean = clean.replaceAll(',', '.');
    } else if (clean.contains('.')) {
      // Sadece nokta var: 76.000 (Binlik ayracı) vs 76.50 (Ondalık)
      final parts = clean.split('.');
      if (parts.length > 2) {
        // 1.500.000 -> Binlik ayracı
        clean = clean.replaceAll('.', '');
      } else if (parts.length == 2) {
        if (parts[1].length == 3) {
          // 76.000 -> 3 basamak varsa kesinlikle binlik ayracıdır (76 bin TL)
          clean = clean.replaceAll('.', '');
        }
        // Eğer 1 veya 2 basamaksa (örn 76.5 veya 76.50), ondalık nokta olarak kalır
      }
    }

    final double value = double.tryParse(clean) ?? 0.0;
    final int cents = (value * 100).round();
    return isNegative ? -cents : cents;
  }

  /// Kuruş değerini biçimlendirilmiş para birimi dizgisine çevirir.
  /// Örnek: 125050 -> "₺1.250,50"
  static String formatCents(int cents, {String currency = 'TRY', bool showSign = false}) {
    final bool isNegative = cents < 0;
    final int absCents = cents.abs();
    final int whole = absCents ~/ 100;
    final int fraction = absCents % 100;

    final String fractionStr = fraction.toString().padLeft(2, '0');
    final String wholeStr = _formatThousands(whole);

    final String symbol = _currencySymbol(currency);
    final String sign = isNegative ? '-' : (showSign ? '+' : '');

    return '$sign$symbol$wholeStr,$fractionStr';
  }

  static String _formatThousands(int number) {
    final String s = number.toString();
    final StringBuffer sb = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      sb.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        sb.write('.');
      }
    }
    return sb.toString().split('').reversed.join('');
  }

  static String _currencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'TRY':
      case 'TL':
        return '₺';
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '$currency ';
    }
  }
}
