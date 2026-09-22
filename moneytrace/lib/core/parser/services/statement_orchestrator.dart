// lib/core/parser/services/statement_orchestrator.dart

import '../models/parsed_models.dart';
import '../parsers/enpara_checking_parser.dart';
import '../parsers/yapikredi_card_parser.dart';
import '../parsers/garanti_statement_parser.dart';
import '../parsers/isbankasi_statement_parser.dart';
import '../parsers/akbank_statement_parser.dart';
import '../parsers/generic_bank_statement_parser.dart';
import '../parsers/generic_payslip_parser.dart';
import 'bank_detector.dart';
import 'merchant_sanitizer.dart';
import '../../security/pii_redactor.dart';
import 'custom_field_mapping_service.dart';

class StatementOrchestrator {
  final EnparaCheckingParser _enparaParser;
  final YapiKrediCardParser _yapiKrediParser;
  final GarantiStatementParser _garantiParser;
  final IsBankasiStatementParser _isBankasiParser;
  final AkbankStatementParser _akbankParser;
  final GenericBankStatementParser _genericBankParser;
  final GenericPayslipParser _payslipParser;

  StatementOrchestrator({
    EnparaCheckingParser? enparaParser,
    YapiKrediCardParser? yapiKrediParser,
    GarantiStatementParser? garantiParser,
    IsBankasiStatementParser? isBankasiParser,
    AkbankStatementParser? akbankParser,
    GenericBankStatementParser? genericBankParser,
    GenericPayslipParser? payslipParser,
  })  : _enparaParser = enparaParser ?? EnparaCheckingParser(),
        _yapiKrediParser = yapiKrediParser ?? YapiKrediCardParser(),
        _garantiParser = garantiParser ?? GarantiStatementParser(),
        _isBankasiParser = isBankasiParser ?? IsBankasiStatementParser(),
        _akbankParser = akbankParser ?? AkbankStatementParser(),
        _genericBankParser = genericBankParser ?? GenericBankStatementParser(),
        _payslipParser = payslipParser ?? GenericPayslipParser();

  /// PDF metin katmanını alıp baştan sona işleyen deterministik ana boru hattı.
  /// 1. PII Maskeleme
  /// 2. Parmak İzi ile Banka ve Belge Türü Tespiti
  /// 3. Özel veya Evrensel Ayrıştırıcı Çalıştırma
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

    // 2.5 DETERMINİSTİK ALAN EŞLEŞTİRME (Custom Field Mapping Template)
    // Körü körüne okumak yerine kullanıcı veya yöneticinin tanımladığı özel kural varsa öncelikli uygula
    final matchingTemplate = CustomFieldMappingService.instance.findMatchingTemplate(sanitizedText);
    if (matchingTemplate != null) {
      final customRecord = CustomFieldMappingService.instance.applyTemplate(sanitizedText, matchingTemplate);
      if (customRecord != null) {
        rawRecords = [customRecord];
      }
    }

    // 3. AYRIŞTIRMA: Özel şablon bulunamadıysa tespit edilen kuruma ve belge tipine göre ilgili parser'ı çalıştır
    if (rawRecords.isEmpty) {
      if (docType == DocumentType.payslip) {
        final payslipResult = _payslipParser.parse(sanitizedText);
        rawRecords = [payslipResult.toParsedRecord()];
      } else {
        switch (detection.institution) {
          case SupportedInstitution.enpara:
            rawRecords = _enparaParser.parse(
              sanitizedText,
              accountMask: detection.detectedAccountIdentifier.isNotEmpty
                  ? detection.detectedAccountIdentifier
                  : null,
            );
            break;

          case SupportedInstitution.yapiKredi:
            rawRecords = _yapiKrediParser.parse(sanitizedText);
            break;

          case SupportedInstitution.garanti:
            rawRecords = _garantiParser.parse(
              sanitizedText,
              accountMask: detection.detectedAccountIdentifier.isNotEmpty
                  ? detection.detectedAccountIdentifier
                  : null,
            );
            break;

          case SupportedInstitution.isBankasi:
            rawRecords = _isBankasiParser.parse(
              sanitizedText,
              accountMask: detection.detectedAccountIdentifier.isNotEmpty
                  ? detection.detectedAccountIdentifier
                  : null,
            );
            break;

          case SupportedInstitution.akbank:
            rawRecords = _akbankParser.parse(
              sanitizedText,
              accountMask: detection.detectedAccountIdentifier.isNotEmpty
                  ? detection.detectedAccountIdentifier
                  : null,
            );
            break;

          case SupportedInstitution.ziraat:
          case SupportedInstitution.vakifbank:
          case SupportedInstitution.halkbank:
          case SupportedInstitution.qnb:
            rawRecords = _genericBankParser.parse(
              sanitizedText,
              defaultMask: detection.detectedAccountIdentifier.isNotEmpty
                  ? detection.detectedAccountIdentifier
                  : null,
              institutionName: _getInstitutionDisplayName(detection.institution),
            );
            break;

          case SupportedInstitution.genericUnknown:
          default:
            // Bilinmeyen belgede sırasıyla parser'ları dene (Fallback Zinciri)
            rawRecords = _enparaParser.parse(sanitizedText);
            if (rawRecords.isEmpty) {
              rawRecords = _yapiKrediParser.parse(sanitizedText);
            }
            if (rawRecords.isEmpty) {
              rawRecords = _garantiParser.parse(sanitizedText);
            }
            if (rawRecords.isEmpty) {
              rawRecords = _isBankasiParser.parse(sanitizedText);
            }
            if (rawRecords.isEmpty) {
              rawRecords = _akbankParser.parse(sanitizedText);
            }
            if (rawRecords.isEmpty) {
              rawRecords = _genericBankParser.parse(sanitizedText);
            }
            break;
        }
      }
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

    final String institutionName = _getInstitutionDisplayName(detection.institution);
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

  String _getInstitutionDisplayName(SupportedInstitution institution) {
    switch (institution) {
      case SupportedInstitution.enpara:
        return 'Enpara';
      case SupportedInstitution.yapiKredi:
        return 'Yapı Kredi';
      case SupportedInstitution.garanti:
        return 'Garanti BBVA';
      case SupportedInstitution.isBankasi:
        return 'İş Bankası';
      case SupportedInstitution.akbank:
        return 'Akbank';
      case SupportedInstitution.ziraat:
        return 'Ziraat Bankası';
      case SupportedInstitution.vakifbank:
        return 'VakıfBank';
      case SupportedInstitution.halkbank:
        return 'Halkbank';
      case SupportedInstitution.qnb:
        return 'QNB Finansbank';
      case SupportedInstitution.genericUnknown:
        return 'Banka Ekstresi';
    }
  }
}
