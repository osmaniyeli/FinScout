// lib/features/navigation/main_navigation_scaffold.dart

import 'package:flutter/material.dart';
import '../../../core/layout/adaptive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/widgets/remote_feature_gate.dart';
import '../../../core/widgets/floating_capsule_nav_bar.dart';
import '../../../core/widgets/fade_through_indexed_stack.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../analysis/presentation/analysis_screen.dart';
import '../cashflow_projection/presentation/cashflow_screen.dart';
import '../goals/presentation/goals_screen.dart';
import '../assets_portfolio/presentation/assets_screen.dart';
import 'tab_add_actions.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;
  final RemoteConfigService _remoteConfig = RemoteConfigService.instance;
  final GlobalKey _stackKey = GlobalKey(debugLabel: 'tab_stack');

  /// Her sekme ekranının State'ine erişim: + düğmesi o sekmenin ekleme seçeneklerini buradan okur.
  final Map<String, GlobalKey> _screenKeys = {
    for (final k in const [
      'dashboard',
      'cashflow',
      'analysis',
      'goals',
      'assets'
    ])
      k: GlobalKey(debugLabel: 'tab_$k'),
  };

  static const Map<String, String> _addMenuTitles = {
    'dashboard': 'Ne eklemek istersin?',
    'cashflow': 'Cüzdana ekle',
    'analysis': 'Analiz',
    'goals': 'Hedefler',
    'assets': 'Varlık ekle',
  };

  /// + düğmesi: açık sekmeye özgü kısa ekleme menüsü. Sekme kapalıysa (bakım) yalnız manuel giriş.
  void _openAddMenu() {
    final keys = _getActiveKeys();
    if (_currentIndex >= keys.length) return;
    final key = keys[_currentIndex];
    // State ile TabAddActions ilişkisiz tipler; `is` terfi etmez, bu yüzden Object üzerinden okunur.
    final Object? state = _screenKeys[key]?.currentState;
    final actions =
        state is TabAddActions ? state.addActions : const <TabAddAction>[];
    if (actions.isEmpty) {
      openQuickEntrySheet(context);
      return;
    }
    showTabAddMenu(context, _addMenuTitles[key] ?? 'Ekle', actions);
  }

  Widget _buildScreenByKey(String key) {
    switch (key) {
      case 'dashboard':
        return RemoteFeatureGate(
          moduleKey: 'dashboard_summary',
          child: DashboardScreen(
            key: _screenKeys['dashboard'],
            onOpenAnalytics: () => _navigateToModule('analysis'),
            onOpenGoals: () => _navigateToModule('goals'),
          ),
        );
      case 'cashflow':
        return RemoteFeatureGate(
          moduleKey: 'cashflow_projection',
          child: CashflowScreen(key: _screenKeys['cashflow']),
        );
      case 'analysis':
        return RemoteFeatureGate(
          moduleKey: 'tax_analytics',
          child: AnalysisScreen(key: _screenKeys['analysis']),
        );
      case 'goals':
        return RemoteFeatureGate(
          moduleKey: 'goals_module',
          child: GoalsScreen(key: _screenKeys['goals']),
        );
      case 'assets':
        return RemoteFeatureGate(
          moduleKey: 'assets_portfolio',
          child: AssetsScreen(key: _screenKeys['assets']),
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
          icon: Icons.account_balance_wallet_rounded,
          label: 'Cüzdan',
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

  /// Geniş ekran gezinmesi: alt çubukla aynı sekmeler, aynı sıra, aynı + düğmesi.
  Widget _buildRail(List<String> activeKeys, Widget? addButton) {
    // Yatay telefonda (alçak pencere) ya da büyük yazı boyutunda ray sığmazsa kaydırılır.
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: _rail(activeKeys, addButton),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rail(List<String> activeKeys, Widget? addButton) {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
      labelType: NavigationRailLabelType.all,
      backgroundColor: Colors.white,
      indicatorColor: AppColors.dynamicPrimary.withValues(alpha: 0.14),
      selectedIconTheme: IconThemeData(color: AppColors.dynamicPrimary),
      unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.dynamicPrimary,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF64748B),
      ),
      groupAlignment: -0.85,
      leading: addButton == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: addButton,
            ),
      destinations: [
        for (final k in activeKeys)
          () {
            final item = _buildCapsuleNavItemByKey(k);
            return NavigationRailDestination(
              icon: Icon(item.icon),
              label: Text(item.label),
            );
          }(),
      ],
    );
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
        final navItems =
            activeKeys.map((k) => _buildCapsuleNavItemByKey(k)).toList();

        final buttonConfig = _remoteConfig.buttonConfig;
        final isFabHidden = buttonConfig.fabPosition == 'hidden';

        // Geniş pencerede (M3 "expanded", ≥ 840 dp: tablet yatay, katlanabilir yatay, masaüstü)
        // alt çubuk yerine sol kenarda NavigationRail; + düğmesi rayın başına taşınır.
        final useRail = WindowSizeClass.of(context).isAtLeastExpanded;

        // Sekmeler canlı tutulur (IndexedStack gibi); geçiş Material fade-through, 280 ms.
        // Anahtar sabit: telefon ↔ ray düzeni arasında geçerken (döndürme, pencere boyutu)
        // sekme ekranlarının durumu korunur.
        final stack = FadeThroughIndexedStack(
          key: _stackKey,
          index: _currentIndex,
          children: screens,
        );

        final addButton = isFabHidden
            ? null
            : FloatingActionButton(
                onPressed: _openAddMenu,
                tooltip: 'Ekle',
                backgroundColor: AppColors.dynamicPrimary,
                elevation: useRail ? 0 : buttonConfig.elevation,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(buttonConfig.borderRadius * 1.5),
                ),
                child:
                    const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              );

        // Ana sayfa dışındaki bir sekmede geri tuşu önce ana sayfaya döner, uygulamadan çıkmaz.
        return PopScope(
          canPop: _currentIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _currentIndex != 0) {
              setState(() => _currentIndex = 0);
            }
          },
          child: useRail
              ? Scaffold(
                  body: Row(
                    children: [
                      _buildRail(activeKeys, addButton),
                      const VerticalDivider(
                          width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                      Expanded(child: stack),
                    ],
                  ),
                )
              : Scaffold(
                  extendBody:
                      false, // Temiz native fintech barı, içerik arkada kalmaz
                  body: stack,
                  floatingActionButton: addButton,
                  floatingActionButtonLocation:
                      _resolveFabLocation(buttonConfig.fabPosition),
                  bottomNavigationBar: FloatingCapsuleNavBar(
                    currentIndex: _currentIndex,
                    onTap: (index) => setState(() => _currentIndex = index),
                    items: navItems,
                    activeIndicatorColor: AppColors.dynamicPrimary,
                  ),
                ),
        );
      },
    );
  }
}
