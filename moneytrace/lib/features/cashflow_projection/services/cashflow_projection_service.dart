// lib/features/cashflow_projection/services/cashflow_projection_service.dart

import '../../../core/database/app_database.dart';
import '../models/cashflow_event.dart';

class CashflowProjectionService {
  final AppDatabase _dbProvider;

  CashflowProjectionService({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  /// Veritabanındaki taksitler, düzenli abonelikler ve belirlenen maaş günüyle
  /// önümüzdeki N ayı simüle eden deterministik projeksiyon üretir.
  Future<List<CashflowMonthSummary>> calculateProjections({
    required int salaryDayOfMonth,
    required int netSalaryCents,
    int numberOfMonths = 6,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now();

    // 1. Veritabanındaki aktif taksitleri çek
    final installmentRows = await db.rawQuery('''
      SELECT 
        i.id,
        i.current_installment,
        i.total_installment,
        i.monthly_amount_cents,
        i.due_date,
        t.clean_merchant,
        t.raw_description
      FROM installments i
      JOIN transactions t ON i.transaction_id = t.id
      ORDER BY i.due_date ASC
    ''');

    // 2. Düzenli abonelikleri çek (is_recurring = 1)
    final subscriptionRows = await db.rawQuery('''
      SELECT 
        id,
        clean_merchant,
        billing_amount_cents,
        transaction_date
      FROM transactions
      WHERE is_recurring = 1
    ''');

    final List<CashflowMonthSummary> monthSummaries = [];

    // Önümüzdeki numberOfMonths ayı tek tek projeksiyona tabi tut
    for (int i = 0; i < numberOfMonths; i++) {
      final targetDate = DateTime(now.year, now.month + i, 1);
      final monthName = _formatMonthYear(targetDate);

      final List<CashflowCalendarEvent> events = [];
      int totalIncome = 0;
      int totalExpense = 0;

      // A) Maaş Günü Eklemesi (Sadece kullanıcı gerçek maaş/bütçe belirttiyse)
      if (netSalaryCents > 0) {
        final salaryDate = DateTime(
            targetDate.year, targetDate.month, salaryDayOfMonth.clamp(1, 28));
        events.add(CashflowCalendarEvent(
          id: 'salary_${targetDate.year}_${targetDate.month}',
          title: 'Maaş Geliri Tahakkuku',
          date: salaryDate,
          amountCents: netSalaryCents,
          type: CashflowEventType.salary,
          subtitle: 'Düzenli Aylık Bordro',
        ));
        totalIncome += netSalaryCents;
      }

      // B) Bu aya düşen taksitler
      for (final row in installmentRows) {
        final currentInst = row['current_installment'] as int;
        final totalInst = row['total_installment'] as int;
        final monthlyCents = row['monthly_amount_cents'] as int;
        final merchant = row['clean_merchant'] as String;

        // Kaçıncı taksitte olduğumuzu hesapla
        final projectedInstNumber = currentInst + i;
        if (projectedInstNumber <= totalInst) {
          final instDate = DateTime(
              targetDate.year, targetDate.month, 20); // Ekstre kesim günü
          events.add(CashflowCalendarEvent(
            id: 'inst_${row['id']}_$i',
            title: merchant,
            date: instDate,
            amountCents: monthlyCents,
            type: CashflowEventType.installment,
            subtitle: 'Taksit $projectedInstNumber / $totalInst',
          ));
          totalExpense += monthlyCents;
        }
      }

      // C) Düzenli Dijital Abonelikler
      for (final sub in subscriptionRows) {
        final subAmount = sub['billing_amount_cents'] as int;
        final subMerchant = sub['clean_merchant'] as String;
        final subDate = DateTime(targetDate.year, targetDate.month, 10);

        events.add(CashflowCalendarEvent(
          id: 'sub_${sub['id']}_$i',
          title: subMerchant,
          date: subDate,
          amountCents: subAmount,
          type: CashflowEventType.subscription,
          subtitle: 'Aylık Düzenli Abonelik',
        ));
        totalExpense += subAmount;
      }

      events.sort((a, b) => a.date.compareTo(b.date));

      monthSummaries.add(CashflowMonthSummary(
        monthLabel: monthName,
        projectedIncomeCents: totalIncome,
        projectedExpenseCents: totalExpense,
        netBalanceCents: totalIncome - totalExpense,
        events: events,
      ));
    }

    return monthSummaries;
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'OCAK',
      'ŞUBAT',
      'MART',
      'NİSAN',
      'MAYIS',
      'HAZİRAN',
      'TEMMUZ',
      'AĞUSTOS',
      'EYLÜL',
      'EKİM',
      'KASIM',
      'ARALIK'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
