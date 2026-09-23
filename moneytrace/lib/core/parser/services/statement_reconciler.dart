// lib/core/parser/services/statement_reconciler.dart

import '../../utils/currency_normalizer.dart';
import '../models/parsed_models.dart';

/// Ayrıştırılan işlemleri bankanın kendi beyanlarıyla karşılaştırır.
/// Bu kontrol tutmuyorsa kullanıcıya gösterilir; veri sessizce yanlış kaydedilmez.
class StatementReconciler {
  StatementReconciler._();

  static ReconciliationReport check({
    required List<ParsedRecord> records,
    required StatementSummary summary,
    required bool isCardStatement,
  }) {
    final issues = <String>[];
    var checks = 0;

    final debits = records
        .where((r) => r.type == ParsedTransactionType.debit)
        .fold<int>(0, (s, r) => s + r.billingAmountCents);
    final credits = records
        .where((r) => r.type == ParsedTransactionType.credit)
        .fold<int>(0, (s, r) => s + r.billingAmountCents);

    // Bazı bankalar (ör. Yapı Kredi) iadeleri harcama toplamından düşer ve ödeme toplamına katmaz;
    // bazıları brüt gösterir. İki gösterimden biri tutuyorsa mutabık sayılır.
    final refunds = records
        .where((r) => r.type == ParsedTransactionType.credit && r.kind == TransactionKind.refund)
        .fold<int>(0, (s, r) => s + r.billingAmountCents);

    // 1. Banka beyanı: dönem içi harcama / ödeme toplamları
    if (summary.periodDebitsCents != null) {
      checks++;
      final declared = summary.periodDebitsCents!;
      if (declared != debits && declared != debits - refunds) {
        issues.add('Harcama toplamı tutmuyor: ekstre ${_fmt(summary.periodDebitsCents!)}, okunan ${_fmt(debits)}');
      }
    }
    if (summary.periodCreditsCents != null) {
      checks++;
      final declared = summary.periodCreditsCents!;
      if (declared != credits && declared != credits - refunds) {
        issues.add('Ödeme/iade toplamı tutmuyor: ekstre ${_fmt(summary.periodCreditsCents!)}, okunan ${_fmt(credits)}');
      }
    }

    // 2. Vadesiz hesap: satır satır bakiye zinciri (önceki bakiye ± tutar = yeni bakiye)
    final withBalance = records.where((r) => r.balanceAfterCents != null).toList();
    if (!isCardStatement && withBalance.length == records.length && records.isNotEmpty) {
      checks++;
      var running = summary.previousBalanceCents ?? (records.first.balanceAfterCents! - records.first.signedAmountCents);
      for (var i = 0; i < records.length; i++) {
        final r = records[i];
        running += r.signedAmountCents;
        if (running != r.balanceAfterCents) {
          issues.add('${i + 1}. satırda bakiye tutmuyor (${r.rawDescription.split(',').first}): '
              'beklenen ${_fmt(running)}, ekstre ${_fmt(r.balanceAfterCents!)}');
          running = r.balanceAfterCents!; // tek hatanın zincirleme yayılmasını engelle
        }
      }
      if (summary.statementBalanceCents != null && running != summary.statementBalanceCents) {
        issues.add('Dönem sonu bakiyesi tutmuyor: ekstre ${_fmt(summary.statementBalanceCents!)}, hesaplanan ${_fmt(running)}');
      }
    }

    if (checks == 0) return ReconciliationReport.notVerifiable;
    return ReconciliationReport(isVerifiable: true, isBalanced: issues.isEmpty, issues: issues);
  }

  static String _fmt(int cents) => CurrencyNormalizer.formatCents(cents);
}
