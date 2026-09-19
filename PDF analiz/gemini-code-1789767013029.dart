// lib/core/parser/models/parsed_models.dart

enum ParsedTransactionType { debit, credit }

class ParsedInstallmentData {
  final int currentInstallment;
  final int totalInstallment;
  final int remainingAmountCents;
  final int monthlyAmountCents;

  ParsedInstallmentData({
    required this.currentInstallment,
    required this.totalInstallment,
    required this.remainingAmountCents,
    required this.monthlyAmountCents,
  });
}

class ParsedTaxData {
  final String taxType; // BSMV, KKDF, VAT, MTV
  final int amountCents;

  ParsedTaxData({required this.taxType, required this.amountCents});
}

class ParsedRecord {
  final String cardOrAccountMask;
  final String? cardHolder;
  final DateTime date;
  final ParsedTransactionType type;
  final String rawDescription;
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
    required this.billingAmountCents,
    this.billingCurrency = 'TRY',
    this.originalAmountCents,
    this.originalCurrency,
    this.exchangeRate,
    this.installment,
    this.taxes = const [],
    this.fastOrTrackingId,
  });
}