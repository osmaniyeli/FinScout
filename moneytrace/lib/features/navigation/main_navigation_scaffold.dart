// lib/features/navigation/main_navigation_scaffold.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/widgets/remote_feature_gate.dart';
import '../../../core/widgets/floating_capsule_nav_bar.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../analysis/presentation/analysis_screen.dart';
import '../cashflow_projection/presentation/cashflow_screen.dart';
import '../goals/presentation/goals_screen.dart';
import '../assets_portfolio/presentation/assets_screen.dart';
import '../quick_entry/presentation/quick_entry_sheet.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({Key? key}) : super(key: key);

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;
  final TransactionRepository _transactionRepository = TransactionRepository();
  final RemoteConfigService _remoteConfig = RemoteConfigService.instance;

  void _openQuickEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickEntrySheet(
        onSave: (entry) async {
          final isExpense = entry['type'] == 'expense';
          await _transactionRepository.saveManualTransaction(
            title: entry['title'] as String,
            amountCents: entry['amount_cents'] as int,
            isExpense: isExpense,
            categoryId: entry['category_id'] as String,
            date: DateTime.parse(entry['date'] as String),
          );

          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.dynamicIncome,
                content: Text('İşlem kaydedildi: ${entry['title']}'),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildScreenByKey(String key) {
    switch (key) {
      case 'dashboard':
        return RemoteFeatureGate(
          moduleKey: 'dashboard_summary',
          child: DashboardScreen(
            onOpenAnalytics: () => _navigateToModule('analysis'),
            onOpenGoals: () => _navigateToModule('goals'),
          ),
        );
      case 'cashflow':
        return const RemoteFeatureGate(
          moduleKey: 'cashflow_projection',
          child: CashflowScreen(),
        );
      case 'analysis':
        return const RemoteFeatureGate(
          moduleKey: 'tax_analytics',
          child: AnalysisScreen(),
        );
      case 'goals':
        return const RemoteFeatureGate(
          moduleKey: 'goals_module',
          child: GoalsScreen(),
        );
      case 'assets':
        return const RemoteFeatureGate(
          moduleKey: 'assets_portfolio',
          child: AssetsScreen(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  FloatingCapsuleNavItem _buildCapsuleNavItemByKey(String key) {
    switch (key) {
      case 'dashboard':
        return const FloatingCapsuleNavItem(
          icon: Icons.home_rounded,
          label: 'Ana Sayfa',
        );
      case 'cashflow':
        return const FloatingCapsuleNavItem(
          icon: Icons.timeline_rounded,
          label: 'Nakit Akışı',
        );
      case 'analysis':
        return const FloatingCapsuleNavItem(
          icon: Icons.pie_chart_rounded,
          label: 'Analiz',
        );
      case 'goals':
        return const FloatingCapsuleNavItem(
          icon: Icons.flag_rounded,
          label: 'Hedefler',
        );
      case 'assets':
        return const FloatingCapsuleNavItem(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Varlıklar',
        );
      default:
        return const FloatingCapsuleNavItem(
          icon: Icons.circle,
          label: '',
        );
    }
  }

  void _navigateToModule(String moduleKey) {
    final activeKeys = _getActiveKeys();
    final targetIndex = activeKeys.indexOf(moduleKey);
    if (targetIndex != -1) {
      setState(() => _currentIndex = targetIndex);
    }
  }

  List<String> _getActiveKeys() {
    final order = _remoteConfig.menuConfig.tabOrder;
    final visible = _remoteConfig.menuConfig.visibleTabs;
    return order.where((k) => visible[k] ?? true).toList();
  }

  FloatingActionButtonLocation _resolveFabLocation(String locationKey) {
    switch (locationKey) {
      case 'centerDocked':
        return FloatingActionButtonLocation.centerDocked;
      case 'hidden':
        return FloatingActionButtonLocation.endFloat;
      case 'endFloat':
      default:
        return FloatingActionButtonLocation.endFloat;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _remoteConfig,
      builder: (context, _) {
        final activeKeys = _getActiveKeys();
        if (_currentIndex >= activeKeys.length) {
          _currentIndex = 0;
        }

        final screens = activeKeys.map((k) => _buildScreenByKey(k)).toList();
        final navItems = activeKeys.map((k) => _buildCapsuleNavItemByKey(k)).toList();

        final buttonConfig = _remoteConfig.buttonConfig;
        final isFabHidden = buttonConfig.fabPosition == 'hidden';

        return Scaffold(
          extendBody: true, // Yüzen kapsülün arkasındaki içeriğin zarif görünmesi için
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          floatingActionButton: isFabHidden
              ? null
              : FloatingActionButton(
                  onPressed: _openQuickEntry,
                  backgroundColor: AppColors.dynamicPrimary,
                  elevation: buttonConfig.elevation,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(buttonConfig.borderRadius * 1.5),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
          floatingActionButtonLocation: _resolveFabLocation(buttonConfig.fabPosition),
          bottomNavigationBar: FloatingCapsuleNavBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: navItems,
            activeIndicatorColor: AppColors.dynamicPrimary,
          ),
        );
      },
    );
  }
}
