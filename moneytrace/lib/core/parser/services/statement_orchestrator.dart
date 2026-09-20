// lib/core/parser/services/statement_orchestrator.dart

import '../models/parsed_models.dart';
import '../parsers/enpara_checking_parser.dart';
import '../parsers/yapikredi_card_parser.dart';
import '../parsers/generic_payslip_parser.dart';
import 'bank_detector.dart';
import 'merchant_sanitizer.dart';
import '../../security/pii_redactor.dart';

class StatementOrchestrator {
  final EnparaCheckingParser _enparaParser;
  final YapiKrediCardParser _yapiKrediParser;
  final GenericPayslipParser _payslipParser;

  StatementOrchestrator({
    EnparaCheckingParser? enparaParser,
    YapiKrediCardParser? yapiKrediParser,
    GenericPayslipParser? payslipParser,
  })  : _enparaParser = enparaParser ?? EnparaCheckingParser(),
        _yapiKrediParser = yapiKrediParser ?? YapiKrediCardParser(),
        _payslipParser = payslipParser ?? GenericPayslipParser();

  /// PDF metin katmanını alıp baştan sona işleyen deterministik ana boru hattı.
  /// 1. PII Maskeleme
  /// 2. Parmak İzi ile Banka ve Belge Türü Tespiti
  /// 3. Özel Ayrıştırıcı Çalıştırma
  /// 4. Marka Normalizasyonu ve Kategori Eşleme
  /// 5. Vergi ve Taksitlerin Konsolide Edilmesi
  Future<StatementDocumentResult> processDocument({
    required String rawPdfText,
    String? documentTypeHint,
    Map<String, String>? userMemoryRules,
  }) async {
    // 1. GÜVENLİK: Bellek içinde tüm hassas verileri (TCKN, Kart No, IBAN, Adres) maskele
    final String sanitizedText = PiiRedactor.redact(rawPdfText);

    // 2. TESPİT: Belge türünü ve kurumu tespit et
    final BankDetectionResult detection = BankDetector.identify(sanitizedText);

    List<ParsedRecord> rawRecords = [];

    // Belge türü ipucu varsa ve detection unknown ise veya ipucu öncelikliyse kullan
    var docType = detection.documentType;
    if (docType == DocumentType.unknown && documentTypeHint != null) {
      if (documentTypeHint == 'CHECKING') docType = DocumentType.checkingAccount;
      if (documentTypeHint == 'CREDIT_CARD') docType = DocumentType.creditCard;
      if (documentTypeHint == 'PAYSLIP') docType = DocumentType.payslip;
    }

    // 3. AYRIŞTIRMA: Tespit edilen belge tipine göre ilgili parser'ı çalıştır
    switch (docType) {
      case DocumentType.checkingAccount:
        rawRecords = _enparaParser.parse(
          sanitizedText,
          accountMask: detection.detectedAccountIdentifier.isNotEmpty
              ? detection.detectedAccountIdentifier
              : null,
        );
        break;

      case DocumentType.creditCard:
        rawRecords = _yapiKrediParser.parse(sanitizedText);
        break;

      case DocumentType.payslip:
        final payslipResult = _payslipParser.parse(sanitizedText);
        rawRecords = [payslipResult.toParsedRecord()];
        break;

      case DocumentType.unknown:
      default:
        // Bilinmeyen belgede Enpara ve Yapı Kredi parser'larını ardışık dene (fallback)
        final enparaAttempt = _enparaParser.parse(sanitizedText);
        if (enparaAttempt.isNotEmpty) {
          rawRecords = enparaAttempt;
        } else {
          final ykAttempt = _yapiKrediParser.parse(sanitizedText);
          if (ykAttempt.isNotEmpty) {
            rawRecords = ykAttempt;
          }
        }
        break;
    }

    if (rawRecords.isEmpty) {
      throw Exception(
        'Belge içerisinde tanınan harcama veya işlem satırı bulunamadı. Lütfen desteklenen bir banka dökümü yükleyin.',
      );
    }

    // 4. NORMALİZASYON & KATEGORİZASYON: Her işlem satırını temizle ve kategorilendir
    final List<ParsedRecord> finalRecords = [];
    int totalDebit = 0;
    int totalCredit = 0;
    int totalTaxes = 0;

    for (final record in rawRecords) {
      final cleanMerchant = record.cleanMerchant.isNotEmpty
          ? record.cleanMerchant
          : MerchantSanitizer.sanitize(record.rawDescription);

      final category = (record.categoryId != 'cat_general' && record.categoryId != 'cat_salary')
          ? record.categoryId
          : MerchantSanitizer.resolveCategory(
              cleanMerchant,
              userMemoryRules: userMemoryRules,
            );

      // Vergi toplamı
      for (final tax in record.taxes) {
        totalTaxes += tax.amountCents;
      }

      if (record.type == ParsedTransactionType.debit) {
        totalDebit += record.billingAmountCents;
      } else {
        totalCredit += record.billingAmountCents;
      }

      finalRecords.add(record.copyWith(
        cleanMerchant: cleanMerchant,
        categoryId: category,
      ));
    }

    // Tarih aralığını belirle
    DateTime periodStart = finalRecords.first.date;
    DateTime periodEnd = finalRecords.last.date;
    for (final r in finalRecords) {
      if (r.date.isBefore(periodStart)) periodStart = r.date;
      if (r.date.isAfter(periodEnd)) periodEnd = r.date;
    }

    final String institutionName = detection.institution == SupportedInstitution.enpara
        ? 'Enpara'
        : (detection.institution == SupportedInstitution.yapiKredi
            ? 'Yapı Kredi'
            : (detection.documentType == DocumentType.payslip ? 'Kurumsal Bordro' : 'Bilinmeyen Kurum'));

    final String docTypeName = detection.documentType == DocumentType.creditCard
        ? 'CREDIT_CARD'
        : (detection.documentType == DocumentType.checkingAccount ? 'CHECKING' : 'PAYSLIP');

    return StatementDocumentResult(
      institution: institutionName,
      documentType: docTypeName,
      accountIdentifier: detection.detectedAccountIdentifier.isNotEmpty
          ? detection.detectedAccountIdentifier
          : (finalRecords.isNotEmpty ? finalRecords.first.cardOrAccountMask : ''),
      records: finalRecords,
      totalDebitCents: totalDebit,
      totalCreditCents: totalCredit,
      totalTaxCents: totalTaxes,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }
}
