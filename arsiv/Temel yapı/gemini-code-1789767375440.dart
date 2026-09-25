// DOSYA ADI: 09_PROJECTION_installment_scheduler.dart
// HEDEF DİZİN: lib/features/cashflow_projection/services/09_PROJECTION_installment_scheduler.dart

import '../../statement_parser/models/parsed_record.dart';

class ScheduledInstallmentItem {
  final String merchantName;
  final int monthlyAmountCents;
  final int installmentIndex; // Kaçıncı taksit olduğu (Örn: 2/3 için 2)
  final int totalInstallments; // Toplam taksit (Örn: 3)
  final String accountMask;

  ScheduledInstallmentItem({
    required this.merchantName,
    required this.monthlyAmountCents,
    required this.installmentIndex,
    required this.totalInstallments,
    required this.accountMask,
  });
}

class MonthlyDebtCommitment {
  final int year;
  final int month;
  final int totalCommittedCents;
  final List<ScheduledInstallmentItem> items;

  MonthlyDebtCommitment({
    required this.year,
    required this.month,
    required this.totalCommittedCents,
    required this.items,
  });

  String get periodLabel => '$year-${month.toString().padLeft(2, '0')}';
}

class InstallmentScheduler {
  /// Ekstrelerden ayrıştırılan kayıtları tarayarak gelecek aylara sarkan 
  /// kesinleşmiş taksit projeksiyonunu hesaplar.
  List<MonthlyDebtCommitment> projectNextMonths(
    List<ParsedRecord> records, {
    DateTime? fromDate,
    int monthHorizon = 6,
  }) {
    final baseDate = fromDate ?? DateTime.now();
    
    // Gelecek ayların havuzunu oluştur
    final Map<String, List<ScheduledInstallmentItem>> projectionMap = {};
    for (int i = 1; i <= monthHorizon; i++) {
      final targetDate = DateTime(baseDate.year, baseDate.month + i, 1);
      final key = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}';
      projectionMap[key] = [];
    }

    // Taksitli kayıtları filtrele ve takvime dağıt
    for (final record in records) {
      final inst = record.installment;
      if (inst == null) continue;

      final int remainingCount = inst.totalInstallment - inst.currentInstallment;
      if (remainingCount <= 0) continue;

      // Kalan taksitleri sonraki aylara sırayla yerleştir
      for (int step = 1; step <= remainingCount; step++) {
        if (step > monthHorizon) break;

        final targetDate = DateTime(record.date.year, record.date.month + step, 1);
        final key = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}';

        if (projectionMap.containsKey(key)) {
          projectionMap[key]!.add(
            ScheduledInstallmentItem(
              merchantName: record.rawDescription,
              monthlyAmountCents: inst.monthlyAmountCents,
              installmentIndex: inst.currentInstallment + step,
              totalInstallments: inst.totalInstallment,
              accountMask: record.cardOrAccountMask,
            ),
          );
        }
      }
    }

    // Haritayı sıralı listeye dönüştür
    final List<MonthlyDebtCommitment> commitments = [];
    final sortedKeys = projectionMap.keys.toList()..sort();

    for (final key in sortedKeys) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final items = projectionMap[key]!;

      final int monthlySum = items.fold(0, (sum, item) => sum + item.monthlyAmountCents);

      commitments.add(
        MonthlyDebtCommitment(
          year: year,
          month: month,
          totalCommittedCents: monthlySum,
          items: items,
        ),
      );
    }

    return commitments;
  }
}