// lib/core/parser/models/parsed_models.dart

enum ParsedTransactionType {
  debit,
  credit,
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
  });

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
  });
}
