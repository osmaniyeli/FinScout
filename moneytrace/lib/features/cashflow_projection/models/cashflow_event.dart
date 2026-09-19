// lib/features/cashflow_projection/models/cashflow_event.dart

enum CashflowEventType {
  salary,
  installment,
  subscription,
  oneTimeExpense,
  otherIncome,
}

class CashflowCalendarEvent {
  final String id;
  final String title;
  final DateTime date;
  final int amountCents;
  final CashflowEventType type;
  final String? subtitle; // Örn: 'Taksit 3/6 - Vatan Bilgisayar'
  final bool isCompleted;

  const CashflowCalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.amountCents,
    required this.type,
    this.subtitle,
    this.isCompleted = false,
  });

  bool get isIncome => type == CashflowEventType.salary || type == CashflowEventType.otherIncome;
}

class CashflowMonthSummary {
  final String monthLabel; // Örn: 'AĞUSTOS 2026'
  final int projectedIncomeCents;
  final int projectedExpenseCents;
  final int netBalanceCents;
  final List<CashflowCalendarEvent> events;

  const CashflowMonthSummary({
    required this.monthLabel,
    required this.projectedIncomeCents,
    required this.projectedExpenseCents,
    required this.netBalanceCents,
    required this.events,
  });
}
