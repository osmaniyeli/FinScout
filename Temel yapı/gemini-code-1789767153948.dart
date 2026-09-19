// lib/core/parser/bank_detector.dart

enum DocumentType { checkingAccount, creditCard, payslip, unknown }

enum SupportedInstitution { enpara, yapiKredi, genericUnknown }

class BankDetectionResult {
  final SupportedInstitution institution;
  final DocumentType documentType;
  final double confidence; // 0.0 - 1.0
  final String detectedAccountIdentifier; // Maskeli IBAN veya Kart No

  BankDetectionResult({
    required this.institution,
    required this.documentType,
    required this.confidence,
    this.detectedAccountIdentifier = '',
  });
}

class BankDetector {
  /// Belgenin ilk 1-2 sayfasından çıkarılan metin katmanını tarayarak
  /// kurum ve belge türünü deterministik parmak izleriyle tespit eder.
  static BankDetectionResult identify(String text) {
    final cleanText = text.toUpperCase();

    // 1. ENPARA VADESİZ HESAP ÖZETİ PARMAK İZLERİ
    final hasEnparaBrand = cleanText.contains('ENPARA.COM') || cleanText.contains('ENPARA BANK A.Ş.');
    final hasEnparaCheckingSign = cleanText.contains('VADESİZ TL') && cleanText.contains('DÖNEM BAŞI BAKIYESI');
    final enparaIbanMatch = RegExp(r'TR\d{2}\s?0015\s?\d{4}').firstMatch(text);

    if (hasEnparaBrand || (enparaIbanMatch != null && hasEnparaCheckingSign)) {
      return BankDetectionResult(
        institution: SupportedInstitution.enpara,
        documentType: DocumentType.checkingAccount,
        confidence: 0.99,
        detectedAccountIdentifier: enparaIbanMatch?.group(0) ?? 'Enpara Hesabı',
      );
    }

    // 2. YAPI KREDİ KREDİ KARTI HESAP ÖZETİ PARMAK İZLERİ
    final hasYapiKrediBrand = cleanText.contains('YAPI VE KREDİ BANKASI A.Ş.') || cleanText.contains('YAPI KREDI');
    final hasYapiKrediCardSign = cleanText.contains('HESAP ÖZETİ') && 
                                (cleanText.contains('WORLDPUAN') || cleanText.contains('ASGARİ TUTAR') || cleanText.contains('DÖNEM BORCU'));
    final ykCardMatch = RegExp(r'\b(?:\d{4}[ -]?\d{2}\*{2}[ -]?\*{4}[ -]?\d{4})\b').firstMatch(text);

    if (hasYapiKrediBrand && hasYapiKrediCardSign) {
      return BankDetectionResult(
        institution: SupportedInstitution.yapiKredi,
        documentType: DocumentType.creditCard,
        confidence: 0.99,
        detectedAccountIdentifier: ykCardMatch?.group(0) ?? 'Yapı Kredi Kartı',
      );
    }

    // 3. MAAŞ BORDROSU PARMAK İZLERİ
    final hasPayslipSign = (cleanText.contains('ÜCRET BORDROSU') || cleanText.contains('MAAŞ BORDROSU')) &&
                           cleanText.contains('SGK') && cleanText.contains('GELİR VERGİSİ');
    if (hasPayslipSign) {
      return BankDetectionResult(
        institution: SupportedInstitution.genericUnknown,
        documentType: DocumentType.payslip,
        confidence: 0.90,
      );
    }

    // 4. EŞLEŞMEYEN / BİLİNMEYEN BELGE
    return BankDetectionResult(
      institution: SupportedInstitution.genericUnknown,
      documentType: DocumentType.unknown,
      confidence: 0.0,
    );
  }
}