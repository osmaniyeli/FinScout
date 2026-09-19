// lib/core/security/pii_redactor.dart

class PiiRedactor {
  // T.C. Kimlik Numarası (11 haneli sayı öbeği)
  static final RegExp _tcknRegex = RegExp(r'\b(\d{3})\d{4}(\d{4})\b');

  // Kredi Kartı Numarası (16 haneli veya aralıklı format)
  static final RegExp _panRegex = RegExp(
    r'\b(\d{4})[ -]?(\d{2})\d{2}[ -]?\d{4}[ -]?(\d{4})\b',
  );

  // TR IBAN formatı (TR + 2 kontrol + 4 banka + 4erli 4 grup + son 2-4 hane)
  static final RegExp _ibanRegex = RegExp(
    r'\bTR(\d{2})\s?(\d{4})\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?(\d{2,4})\b',
    caseSensitive: false,
  );

  // Açık Adres blokları (Mah., Sok., Cad., Sitesi, Blok, No vb.)
  static final RegExp _addressRegex = RegExp(
    r'(?:MAH\.|MAHALLESİ|SOK\.|SOKAK|CAD\.|CADDESİ|SİTESİ|BLOK|İÇ KAPI NO|APARTMANI).*?(?:KOCAELİ|İSTANBUL|ANKARA|İZMİR|BURSA|ANTALYA|ADANA|GEBZE|KADIKÖY)',
    caseSensitive: false,
  );

  // Telefon numaraları (+90 5xx xxx xx xx veya 05xx xxx xx xx)
  static final RegExp _phoneRegex = RegExp(
    r'(?:\+?90|0)?\s*(5\d{2})[\s\.-]?(\d{3})[\s\.-]?(\d{2})[\s\.-]?(\d{2})\b',
  );

  /// Ham metindeki tüm hassas kişisel verileri (TCKN, Kart No, IBAN, Adres, Telefon) anında maskeler.
  static String redact(String rawText) {
    String sanitized = rawText;

    // 1. IBAN: TR43 0015 ... (Önce IBAN maskelenir ki içindeki 16 hane kredi kartı sanılmasın)
    sanitized = sanitized.replaceAllMapped(_ibanRegex, (m) {
      final check = m.group(1) ?? '00';
      final bank = m.group(2) ?? '0000';
      final lastDigits = m.group(3) ?? '****';
      return 'TR$check $bank **** **** **** $lastDigits';
    });

    // 2. TCKN: 12345678901 -> 123****8901
    sanitized = sanitized.replaceAllMapped(_tcknRegex, (m) {
      final prefix = m.group(1) ?? '***';
      final suffix = m.group(2) ?? '****';
      return '$prefix****$suffix';
    });

    // 3. Kart No: 4462 1234 5678 8281 -> 4462 12** **** 8281
    sanitized = sanitized.replaceAllMapped(_panRegex, (m) {
      final p1 = m.group(1) ?? '****';
      final p2 = m.group(2) ?? '**';
      final p4 = m.group(3) ?? '****';
      return '$p1 $p2** **** $p4';
    });

    // Telefon: 0532 123 45 67 -> 0532 *** ** 67
    sanitized = sanitized.replaceAllMapped(_phoneRegex, (m) {
      final prefix = m.group(1) ?? '5**';
      final suffix = m.group(4) ?? '**';
      return '0$prefix *** ** $suffix';
    });

    // Açık Adres
    sanitized = sanitized.replaceAll(_addressRegex, '[ADRES BİLGİSİ MASKELLENDİ]');

    return sanitized;
  }
}
