// DOSYA ADI: 13_CONTROLLER_dashboard_controller.dart
// HEDEF DİZİN: lib/features/dashboard/controllers/13_CONTROLLER_dashboard_controller.dart

import 'dart:async';
import '../models/10_UI_dashboard_view_state.dart';
import '../../statement_parser/data/12_REPO_transaction_repository.dart';
import '../../tax_analytics/services/07_TAX_calculator_service.dart';
import '../../cashflow_projection/services/09_PROJECTION_installment_scheduler.dart';
import '../../persona_scout/services/08_SCOUT_persona_insight_engine.dart';
import '../../statement_parser/models/parsed_record.dart';

class DashboardController {
  final TransactionRepository repository;
  final TaxCalculatorService taxService;
  final InstallmentScheduler installmentScheduler;
  final ScoutPersonaInsightEngine scoutEngine;

  final StreamController<DashboardViewState> _stateController = StreamController<DashboardViewState>.broadcast();
  Stream<DashboardViewState> get stateStream => _stateController.stream;

  DashboardController({
    required this.repository,
    required this.taxService,
    required this.installmentScheduler,
    required this.scoutEngine,
  });

  Future<void> loadPeriodData(String yearMonth) async {
    _stateController.add(DashboardViewState.initial().copyWith(isLoading: true, selectedPeriod: yearMonth));

    try {
      final rows = await repository.getTransactionsByPeriod(yearMonth);

      int totalIncome = 0;
      int totalExpense = 0;
      int groceryExpense = 0;
      int fuelExpense = 0;

      final Map<String, int> categoryTotals = {};
      final List<ParsedRecord> txList = [];

      for (final r in rows) {
        final amount = r['billing_amount_cents'] as int;
        final type = r['transaction_type'] as String;
        final catId = r['category_id'] as String;

        if (type == 'CREDIT') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
          categoryTotals[catId] = (categoryTotals[catId] ?? 0) + amount;

          if (catId == 'cat_market') groceryExpense += amount;
          if (catId == 'cat_fuel') fuelExpense += amount;
        }

        txList.add(ParsedRecord(
          cardOrAccountMask: r['account_id'] as String,
          date: DateTime.parse(r['transaction_date'] as String),
          type: type == 'DEBIT' ? ParsedTransactionType.debit : ParsedTransactionType.credit,
          rawDescription: r['raw_description'] as String,
          billingAmountCents: amount,
        ));
      }

      // 1. Kategori Dağılımını Yüzdeye Çevir
      final List<CategoryExpenseShare> shares = [];
      categoryTotals.forEach((catId, sum) {
        shares.add(CategoryExpenseShare(
          categoryId: catId,
          categoryName: catId, // UI katmanında lokalize edilir
          iconName: 'category',
          colorHex: '#2E7D32',
          totalAmountCents: sum,
          percentage: totalExpense > 0 ? (sum / totalExpense) * 100 : 0.0,
        ));
      });

      // 2. Vergi ve Devlet Payı Analizi
      final taxBreakdown = taxService.calculateMonthlyTaxLoad(
        transactions: rows,
        totalExpenditureCents: totalExpense,
      );

      // 3. Gelecek Ayın Taksit Yükü
      final projections = installmentScheduler.projectNextMonths(txList, monthHorizon: 1);
      final nextMonthCommitment = projections.isNotEmpty ? projections.first.totalCommittedCents : 0;

      // 4. "İzci" Geri Bildirimi
      final scoutFeedback = scoutEngine.generateFeedback(
        currentMonthExpenditureCents: totalExpense,
        previousMonthExpenditureCents: totalExpense, // Önceki ay veritabanından bağlanır
        currentGroceryCents: groceryExpense,
        previousGroceryCents: 0,
        currentFuelCents: fuelExpense,
        previousFuelCents: 0,
        futureCommittedInstallmentsCents: nextMonthCommitment,
        monthlyNetIncomeCents: totalIncome,
        stateShareRatio: taxBreakdown.stateShareRatio,
      );

      _stateController.add(DashboardViewState(
        isLoading: false,
        selectedPeriod: yearMonth,
        totalIncomeCents: totalIncome,
        totalExpenseCents: totalExpense,
        netBalanceCents: totalIncome - totalExpense,
        scoutFeedback: scoutFeedback,
        categoryShares: shares,
        nextMonthCommittedInstallmentsCents: nextMonthCommitment,
        taxSummary: taxBreakdown,
        recentTransactions: txList,
      ));
    } catch (e) {
      _stateController.add(DashboardViewState.initial().copyWith(
        isLoading: false,
        errorMessage: 'Veriler işlenirken hata oluştu: $e',
      ));
    }
  }

  void dispose() {
    _stateController.close();
  }
}

extension DashboardViewStateCopy on DashboardViewState {
  DashboardViewState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? selectedPeriod,
  }) {
    return DashboardViewState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      totalIncomeCents: totalIncomeCents,
      totalExpenseCents: totalExpenseCents,
      netBalanceCents: netBalanceCents,
      scoutFeedback: scoutFeedback,
      categoryShares: categoryShares,
      nextMonthCommittedInstallmentsCents: nextMonthCommittedInstallmentsCents,
      taxSummary: taxSummary,
      recentTransactions: recentTransactions,
    );
  }
}