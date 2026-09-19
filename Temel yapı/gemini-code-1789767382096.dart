// DOSYA ADI: 10_UI_dashboard_view_state.dart
// HEDEF DİZİN: lib/features/dashboard/models/10_UI_dashboard_view_state.dart

import '../../persona_scout/services/08_SCOUT_persona_insight_engine.dart';
import '../../tax_analytics/services/07_TAX_calculator_service.dart';
import '../../statement_parser/models/parsed_record.dart';

class CategoryExpenseShare {
  final String categoryId;
  final String categoryName;
  final String iconName;
  final String colorHex;
  final int totalAmountCents;
  final double percentage; // 0.0 - 100.0

  CategoryExpenseShare({
    required this.categoryId,
    required this.categoryName,
    required this.iconName,
    required this.colorHex,
    required this.totalAmountCents,
    required this.percentage,
  });
}

class DashboardViewState {
  final bool isLoading;
  final String? errorMessage;
  final String selectedPeriod; // '2026-06'
  
  // 1. Ana Finansal Özet Blokları (Kuruş Tamsayı)
  final int totalIncomeCents;
  final int totalExpenseCents;
  final int netBalanceCents;

  // 2. Persona Katmanı
  final ScoutFeedback scoutFeedback;

  // 3. Harcama Dağılımı ve Grafikler
  final List<CategoryExpenseShare> categoryShares;

  // 4. Gelecek Dönem Sabit Yük Projeksiyonu
  final int nextMonthCommittedInstallmentsCents;

  // 5. Devlet Payı ve Kesintiler
  final TaxBreakdown taxSummary;

  // 6. Kronolojik Hareket Akışı
  final List<ParsedRecord> recentTransactions;

  DashboardViewState({
    this.isLoading = false,
    this.errorMessage,
    required this.selectedPeriod,
    required this.totalIncomeCents,
    required this.totalExpenseCents,
    required this.netBalanceCents,
    required this.scoutFeedback,
    required this.categoryShares,
    required this.nextMonthCommittedInstallmentsCents,
    required this.taxSummary,
    required this.recentTransactions,
  });

  factory DashboardViewState.initial() {
    return DashboardViewState(
      isLoading: true,
      selectedPeriod: '',
      totalIncomeCents: 0,
      totalExpenseCents: 0,
      netBalanceCents: 0,
      scoutFeedback: ScoutFeedback(
        badgeText: 'İzci Beklemede',
        mood: ScoutMood.neutral,
        message: 'Analiz edilecek ekstre veya harcama kaydı aranıyor...',
      ),
      categoryShares: [],
      nextMonthCommittedInstallmentsCents: 0,
      taxSummary: TaxBreakdown(
        directTaxesCents: 0,
        financialLeviesCents: 0,
        officialFeesCents: 0,
        estimatedVatCents: 0,
        totalStateShareCents: 0,
        stateShareRatio: 0.0,
      ),
      recentTransactions: [],
    );
  }
}