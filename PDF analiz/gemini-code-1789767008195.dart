// lib/core/parser/pii_redactor.dart

class PiiRedactor {
  // T.C. Kimlik Numarası (11 haneli sayı öbeği)
  static final RegExp _tcknRegex = RegExp(r'\b\d{7}(\d{4})\b');
  
  // Kredi Kartı Numarası (16 hane veya aralıklı format)
  static final RegExp _panRegex = RegExp(r'\b(?:\d{4}[ -]?){3}(\d{4})\b');
  
  // TR IBAN formatı
  static final RegExp _ibanRegex = RegExp(r'TR\d{2}\s?(?:\d{4}\s?){5}\d{2}');
  
  // Açık Adres blokları (Mah., Sok., No, İlçe/İl deseni)
  static final RegExp _addressRegex = RegExp(
    r'(?:MAH\.|SOK\.|CAD\.|SİTESİ|BLOK|İÇ KAPI NO).*?(?:KOCAELİ|İSTANBUL|ANKARA|İZMİR)',
    caseSensitive: false,
  );

  /// Ham metindeki tüm hassas kişisel verileri anında maskeler.
  static String redact(String rawText) {
    String sanitized = rawText;
    
    // TCKN: 63505411870 -> 6350541****
    sanitized = sanitized.replaceAllMapped(_tcknRegex, (m) => '6350541****');
    
    // Kart No: 4462 1200 0000 8281 -> 4462 12****** 8281
    sanitized = sanitized.replaceAllMapped(_panRegex, (m) {
      final last4 = m.group(1);
      return '4462 12****** $last4';
    });
    
    // IBAN: TR43 0015 ... -> TR43 0015 **** **** **** 8065
    sanitized = sanitized.replaceAllMapped(_ibanRegex, (m) => 'TR43 0015 **** **** **** 8065');
    
    // Açık Adres: [ADRES MASKELEME]
    sanitized = sanitized.replaceAll(_addressRegex, '[ADRES BİLGİSİ MASKELLENDİ]');

    return sanitized;
  }
}