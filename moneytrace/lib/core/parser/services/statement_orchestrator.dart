// lib/core/parser/services/statement_orchestrator.dart

import '../../security/pii_redactor.dart';
import '../enrichment/category_engine.dart';
import '../enrichment/counterparty_extractor.dart';
import '../enrichment/transaction_classifier.dart';
import '../layout/statement_layout.dart';
import '../models/parsed_models.dart';
import '../parsers/enpara_checking_parser.dart';
import '../parsers/garanti_statement_parser.dart';
import '../parsers/generic_bank_statement_parser.dart';
import '../parsers/generic_payslip_parser.dart';
import '../parsers/statement_parser.dart';
import '../parsers/yapikredi_card_parser.dart';
import '../util/tr_statement_text.dart';
import 'bank_detector.dart';
import 'statement_reconciler.dart';

class StatementParseException implements Exception {
  final String message;
  const StatementParseException(this.message);
  @override
  String toString() => message;
}

/// PDF düzeninden (StatementLayout) başlayıp zenginleştirilmiş ve mutabakatı yapılmış
/// ekstre sonucuna giden deterministik boru hattı:
///
/// 1. Tespit      → kurum + belge türü (kart / vadesiz / bordro)
/// 2. Ayrıştırma  → kuruma özel sütun tabanlı parser, olmazsa genel tablo okuyucu
/// 3. Zenginleştirme → işlem türü, karşı taraf, kategori + sektör
/// 4. Gizlilik    → açıklamalardaki TCKN / kart no / IBAN / telefon maskelenir
/// 5. Mutabakat   → bankanın beyan ettiği toplamlar ve bakiye zinciri ile kontrol
class StatementOrchestrator {
  final CategoryEngine _categories;

  StatementOrchestrator({CategoryEngine? categoryEngine})
      : _categories = categoryEngine ?? CategoryEngine.instance;

  Future<StatementDocumentResult> processDocument({
    required StatementLayout layout,
    String? documentTypeHint,
    Map<String, String> userRules = const {},
  }) async {
    final text = layout.plainText;
    final detection = BankDetector.identify(text);

    var docType = detection.documentType;
    if (docType == DocumentType.unknown && documentTypeHint != null) {
      docType = switch (documentTypeHint) {
        'CHECKING' => DocumentType.checkingAccount,
        'CREDIT_CARD' => DocumentType.creditCard,
        'PAYSLIP' => DocumentType.payslip,
        _ => DocumentType.unknown,
      };
    }
    final isCard = docType == DocumentType.creditCard;

    // 1-2. Ayrıştırma
    // Kullanıcı tanımlı alan eşleme şablonları devre dışı: kayıt kategorisi veritabanında olmadığı
    // için içe aktarımı düşürüyordu ve tek banka fazında gerekmiyor.
    var output = _parserFor(detection.institution, docType).parse(layout);
    if (output.records.isEmpty && docType != DocumentType.payslip) {
      // Kurum parser'ı düzeni tanımadıysa genel tablo okuyucu dener
      output = GenericBankStatementParser(isCardStatement: isCard).parse(layout);
    }

    if (output.records.isEmpty) {
      throw const StatementParseException(
        'Belgede işlem tablosu bulunamadı. Lütfen bankanızın internet/mobil şubesinden indirdiğiniz e-ekstreyi yükleyin.',
      );
    }

    // 3-4. Zenginleştirme + gizlilik
    final holder = output.accountHolder == null ? null : TrStatementText.fold(output.accountHolder!);
    final records = output.records
        .map((r) => _enrich(r, isCard: isCard, userRules: userRules, holder: holder))
        .toList();

    // 5. Mutabakat
    final reconciliation = StatementReconciler.check(
      records: records,
      summary: output.summary,
      isCardStatement: isCard,
    );

    var totalDebit = 0, totalCredit = 0, totalTaxes = 0;
    var periodStart = records.first.date, periodEnd = records.first.date;
    for (final r in records) {
      if (r.type == ParsedTransactionType.debit) {
        totalDebit += r.billingAmountCents;
      } else {
        totalCredit += r.billingAmountCents;
      }
      totalTaxes += r.taxes.fold<int>(0, (s, t) => s + t.amountCents);
      if (r.date.isBefore(periodStart)) periodStart = r.date;
      if (r.date.isAfter(periodEnd)) periodEnd = r.date;
    }

    final account = output.accountIdentifier ??
        (detection.detectedAccountIdentifier.isNotEmpty ? detection.detectedAccountIdentifier : '');

    return StatementDocumentResult(
      institution: _displayName(detection.institution, docType),
      documentType: switch (docType) {
        DocumentType.creditCard => 'CREDIT_CARD',
        DocumentType.payslip => 'PAYSLIP',
        _ => 'CHECKING',
      },
      accountIdentifier: PiiRedactor.redact(account),
      records: records,
      totalDebitCents: totalDebit,
      totalCreditCents: totalCredit,
      totalTaxCents: totalTaxes,
      periodStart: periodStart,
      periodEnd: periodEnd,
      summary: output.summary,
      reconciliation: reconciliation,
    );
  }

  LayoutStatementParser _parserFor(SupportedInstitution institution, DocumentType docType) {
    if (docType == DocumentType.payslip) return GenericPayslipParser();
    return switch (institution) {
      SupportedInstitution.enpara => EnparaCheckingParser(),
      SupportedInstitution.yapiKredi => YapiKrediCardParser(),
      SupportedInstitution.garanti => GarantiStatementParser(),
      _ => GenericBankStatementParser(isCardStatement: docType == DocumentType.creditCard),
    };
  }

  ParsedRecord _enrich(
    ParsedRecord record, {
    required bool isCard,
    required Map<String, String> userRules,
    String? holder,
  }) {
    var kind = TransactionClassifier.classify(record, isCardStatement: isCard);
    var withKind = record.copyWith(kind: kind);
    final counterparty = CounterpartyExtractor.extract(withKind);

    // Hesap sahibinin kendi adına giden/gelen havale → kendi hesapları arası aktarım
    final isTransfer = kind == TransactionKind.transferIn || kind == TransactionKind.transferOut;
    if (isTransfer && holder != null && TrStatementText.fold(counterparty) == holder) {
      kind = TransactionKind.ownTransfer;
      withKind = withKind.copyWith(kind: kind);
    }
    final match = record.categoryId != 'cat_general'
        ? CategoryMatch(record.categoryId, sector: record.sector, source: CategorySource.userRule)
        : _categories.resolve(withKind, counterparty: counterparty, userRules: userRules);

    final display = match.brand ?? (counterparty.isNotEmpty ? counterparty : record.rawDescription);
    return withKind.copyWith(
      rawDescription: PiiRedactor.redact(record.rawDescription),
      counterparty: PiiRedactor.redact(counterparty),
      cleanMerchant: PiiRedactor.redact(display),
      categoryId: match.categoryId,
      sector: match.sector,
    );
  }

  String _displayName(SupportedInstitution institution, DocumentType docType) {
    if (docType == DocumentType.payslip) return 'Maaş Bordrosu';
    return switch (institution) {
      SupportedInstitution.enpara => 'Enpara',
      SupportedInstitution.yapiKredi => 'Yapı Kredi',
      SupportedInstitution.garanti => 'Garanti BBVA',
      SupportedInstitution.isBankasi => 'İş Bankası',
      SupportedInstitution.akbank => 'Akbank',
      SupportedInstitution.ziraat => 'Ziraat Bankası',
      SupportedInstitution.vakifbank => 'VakıfBank',
      SupportedInstitution.halkbank => 'Halkbank',
      SupportedInstitution.qnb => 'QNB',
      SupportedInstitution.genericUnknown => 'Banka Ekstresi',
    };
  }
}
