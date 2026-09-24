// lib/core/parser/models/parsed_models.dart

enum ParsedTransactionType {
  debit,
  credit,
}

/// İşlemin ekonomik anlamı. Borç/alacak yönünden bağımsızdır; analiz ve kategorizasyon bunu kullanır.
enum TransactionKind {
  purchase, // Kartla / POS ile alışveriş
  refund, // İptal / iade
  cardPayment, // Kredi kartı borç ödemesi
  interestFee, // Dönem faizi, gecikme faizi, kart ücreti, işlem ücreti
  tax, // BSMV, KKDF, MTV, vergi dairesi
  cashAdvance, // Nakit çekim / ATM
  transferIn, // Gelen havale / EFT / FAST
  transferOut, // Giden havale / EFT / FAST
  ownTransfer, // Kişinin kendi hesapları arası aktarım (gelir/gider sayılmaz)
  salary, // Maaş / bordro geliri
  billPayment, // Fatura ödemesi (elektrik, su, doğalgaz, telekom)
  loanPayment, // Kredi taksidi
  other,
}

extension TransactionKindCode on TransactionKind {
  String get code => name.toUpperCase();

  static TransactionKind fromCode(String? code) => TransactionKind.values.firstWhere(
        (k) => k.code == code,
        orElse: () => TransactionKind.other,
      );
}

class ParsedInstallmentData {
  final int currentInstallment;
  final int totalInstallment;
  final int remainingAmountCents;
  final int monthlyAmountCents;

  const ParsedInstallmentData({
    required this.currentInstallment,
    required this.totalInstallment,
    required this.remainingAmountCents,
    required this.monthlyAmountCents,
  });

  Map<String, dynamic> toMap() {
    return {
      'current_installment': currentInstallment,
      'total_installment': totalInstallment,
      'remaining_amount_cents': remainingAmountCents,
      'monthly_amount_cents': monthlyAmountCents,
    };
  }
}

class ParsedTaxData {
  final String taxType; // BSMV, KKDF, VAT, MTV, INCOME_TAX, STAMP_TAX, SGK_WORKER
  final int amountCents;

  const ParsedTaxData({
    required this.taxType,
    required this.amountCents,
  });

  Map<String, dynamic> toMap() {
    return {
      'tax_type': taxType,
      'amount_cents': amountCents,
    };
  }
}

class ParsedRecord {
  final String cardOrAccountMask;
  final String? cardHolder;
  final DateTime date;
  final ParsedTransactionType type;
  final String rawDescription;
  final String cleanMerchant;
  final String categoryId;
  final int billingAmountCents;
  final String billingCurrency;
  final int? originalAmountCents;
  final String? originalCurrency;
  final double? exchangeRate;
  final ParsedInstallmentData? installment;
  final List<ParsedTaxData> taxes;
  final String? fastOrTrackingId;

  /// İşlemin ekonomik türü (alışveriş, kart ödemesi, faiz, havale...)
  final TransactionKind kind;

  /// Paranın gittiği / geldiği taraf (üye işyeri, havale alıcısı/göndereni, kurum)
  final String counterparty;

  /// Sektör etiketi (ör. "Süpermarket", "Akaryakıt"); sözlükten veya kurallardan gelir
  final String? sector;

  /// İşlem sonrası hesap bakiyesi (vadesiz hesap ekstrelerinde)
  final int? balanceAfterCents;

  ParsedRecord({
    required this.cardOrAccountMask,
    this.cardHolder,
    required this.date,
    required this.type,
    required this.rawDescription,
    this.cleanMerchant = '',
    this.categoryId = 'cat_general',
    required this.billingAmountCents,
    this.billingCurrency = 'TRY',
    this.originalAmountCents,
    this.originalCurrency,
    this.exchangeRate,
    this.installment,
    this.taxes = const [],
    this.fastOrTrackingId,
    this.kind = TransactionKind.other,
    this.counterparty = '',
    this.sector,
    this.balanceAfterCents,
  });

  /// İşaretli tutar: gider negatif, gelir pozitif (kuruş)
  int get signedAmountCents =>
      type == ParsedTransactionType.debit ? -billingAmountCents : billingAmountCents;

  ParsedRecord copyWith({
    String? cardOrAccountMask,
    String? cardHolder,
    DateTime? date,
    ParsedTransactionType? type,
    String? rawDescription,
    String? cleanMerchant,
    String? categoryId,
    int? billingAmountCents,
    String? billingCurrency,
    int? originalAmountCents,
    String? originalCurrency,
    double? exchangeRate,
    ParsedInstallmentData? installment,
    List<ParsedTaxData>? taxes,
    String? fastOrTrackingId,
    TransactionKind? kind,
    String? counterparty,
    String? sector,
    int? balanceAfterCents,
  }) {
    return ParsedRecord(
      cardOrAccountMask: cardOrAccountMask ?? this.cardOrAccountMask,
      cardHolder: cardHolder ?? this.cardHolder,
      date: date ?? this.date,
      type: type ?? this.type,
      rawDescription: rawDescription ?? this.rawDescription,
      cleanMerchant: cleanMerchant ?? this.cleanMerchant,
      categoryId: categoryId ?? this.categoryId,
      billingAmountCents: billingAmountCents ?? this.billingAmountCents,
      billingCurrency: billingCurrency ?? this.billingCurrency,
      originalAmountCents: originalAmountCents ?? this.originalAmountCents,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      installment: installment ?? this.installment,
      taxes: taxes ?? this.taxes,
      fastOrTrackingId: fastOrTrackingId ?? this.fastOrTrackingId,
      kind: kind ?? this.kind,
      counterparty: counterparty ?? this.counterparty,
      sector: sector ?? this.sector,
      balanceAfterCents: balanceAfterCents ?? this.balanceAfterCents,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'card_or_account_mask': cardOrAccountMask,
      'card_holder': cardHolder,
      'date': date.toIso8601String().split('T')[0],
      'type': type == ParsedTransactionType.debit ? 'DEBIT' : 'CREDIT',
      'raw_description': rawDescription,
      'clean_merchant': cleanMerchant,
      'category_id': categoryId,
      'billing_amount_cents': billingAmountCents,
      'billing_currency': billingCurrency,
      'original_amount_cents': originalAmountCents,
      'original_currency': originalCurrency,
      'exchange_rate': exchangeRate,
      'installment': installment?.toMap(),
      'taxes': taxes.map((t) => t.toMap()).toList(),
      'fast_or_tracking_id': fastOrTrackingId,
      'kind': kind.code,
      'counterparty': counterparty,
      'sector': sector,
      'balance_after_cents': balanceAfterCents,
    };
  }
}

class ParsedPayslipResult {
  final DateTime periodDate;
  final int grossSalaryCents;
  final int netSalaryCents;
  final int sgkWorkerCents;
  final int incomeTaxCents;
  final int stampTaxCents;
  final int? besDeductionCents;
  final List<ParsedTaxData> taxes;

  const ParsedPayslipResult({
    required this.periodDate,
    required this.grossSalaryCents,
    required this.netSalaryCents,
    required this.sgkWorkerCents,
    required this.incomeTaxCents,
    required this.stampTaxCents,
    this.besDeductionCents,
    required this.taxes,
  });

  /// Bordroyu ana sisteme 'Gelir' (Net Maaş) ve 'Vergi Kesintileri' olarak dönüştürür.
  ParsedRecord toParsedRecord() {
    return ParsedRecord(
      cardOrAccountMask: 'BORDRO_GELIR',
      cardHolder: 'Çalışan Maaşı',
      date: periodDate,
      type: ParsedTransactionType.credit,
      rawDescription: 'Aylık Net Maaş Tahakkuku',
      cleanMerchant: 'Maaş Geliri',
      categoryId: 'cat_salary',
      billingAmountCents: netSalaryCents,
      taxes: taxes,
    );
  }
}

/// Ekstrede bildirilen, henüz gerçekleşmemiş planlı ödeme (talimat, kredi taksidi).
class ScheduledPayment {
  final DateTime date;
  final String description;
  final int amountCents;

  const ScheduledPayment({required this.date, required this.description, required this.amountCents});
}

/// Ekstrenin başlık bölümündeki banka beyanları (ödeme düzeni ve mutabakat için).
class StatementSummary {
  final DateTime? statementDate; // Hesap kesim tarihi
  final DateTime? dueDate; // Son ödeme tarihi
  final int? statementBalanceCents; // Dönem borcu (kart) / dönem sonu bakiyesi (hesap)
  final int? minimumPaymentCents; // Asgari ödeme tutarı
  final int? previousBalanceCents; // Önceki dönem borcu / dönem başı bakiyesi
  final int? periodDebitsCents; // Dönem içi harcamalar (banka beyanı)
  final int? periodCreditsCents; // Dönem içi ödemeler (banka beyanı)
  final int? creditLimitCents;
  final DateTime? nextStatementDate;
  final DateTime? nextDueDate;
  final List<ScheduledPayment> scheduledPayments;
  // Bordro beyanları: brüt − yasal kesintiler − özel kesintiler = net ödenen
  final int? payslipGrossCents;
  final int? payslipLegalDeductionsCents;
  final int? payslipOtherDeductionsCents;

  const StatementSummary({
    this.statementDate,
    this.dueDate,
    this.statementBalanceCents,
    this.minimumPaymentCents,
    this.previousBalanceCents,
    this.periodDebitsCents,
    this.periodCreditsCents,
    this.creditLimitCents,
    this.nextStatementDate,
    this.nextDueDate,
    this.scheduledPayments = const [],
    this.payslipGrossCents,
    this.payslipLegalDeductionsCents,
    this.payslipOtherDeductionsCents,
  });

  static const empty = StatementSummary();
}

/// Ayrıştırılan işlemlerin bankanın beyan ettiği toplamlarla karşılaştırılması.
class ReconciliationReport {
  /// Kontrol yapılabildi mi (bankanın beyan ettiği bir toplam/bakiye bulundu mu)
  final bool isVerifiable;

  /// Tüm kontroller tuttu mu
  final bool isBalanced;

  /// Kullanıcıya gösterilecek açıklamalar (tutmayan kalemler)
  final List<String> issues;

  const ReconciliationReport({
    required this.isVerifiable,
    required this.isBalanced,
    this.issues = const [],
  });

  static const notVerifiable = ReconciliationReport(isVerifiable: false, isBalanced: false);
}

class StatementDocumentResult {
  final String institution;
  final String documentType;
  final String accountIdentifier;
  final List<ParsedRecord> records;
  final int totalDebitCents;
  final int totalCreditCents;
  final int totalTaxCents;
  final DateTime periodStart;
  final DateTime periodEnd;
  final StatementSummary summary;
  final ReconciliationReport reconciliation;

  const StatementDocumentResult({
    required this.institution,
    required this.documentType,
    required this.accountIdentifier,
    required this.records,
    required this.totalDebitCents,
    required this.totalCreditCents,
    required this.totalTaxCents,
    required this.periodStart,
    required this.periodEnd,
    this.summary = StatementSummary.empty,
    this.reconciliation = ReconciliationReport.notVerifiable,
  });
}
