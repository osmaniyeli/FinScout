// lib/features/navigation/main_navigation_scaffold.dart

import 'package:flutter/material.dart';
import '../../../core/layout/adaptive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/widgets/remote_feature_gate.dart';
import '../../../core/widgets/floating_capsule_nav_bar.dart';
import '../../../core/widgets/fade_through_indexed_stack.dart';
import '../../../core/widgets/onboarding_tour/onboarding_tour_controller.dart';
import '../../../core/widgets/onboarding_tour/tour_anchors.dart';
import '../../../core/widgets/onboarding_tour/tour_step.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../analysis/presentation/analysis_screen.dart';
import '../cashflow_projection/presentation/cashflow_screen.dart';
import '../goals/presentation/goals_screen.dart';
import '../goals/presentation/goals_locked_view.dart';
import '../assets_portfolio/presentation/assets_screen.dart';
import '../subscription/services/subscription_service.dart';
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

  @override
  void initState() {
    super.initState();
    // Yeni hesap kaydından hemen sonra, ana ekran ilk kare çizildikten sonra bir kerelik tanıtım
    // turu (bkz. OnboardingTourController). Bu ekran her zaman mount edilen ilk ana ekran olduğu
    // için tetikleme burada yapılır; sinyal main.dart'taki _announceNewAccount ile aynıdır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      OnboardingTourController.instance.maybeStart(context, _buildTourSteps());
    });
  }

  /// Gerçek FinScout ekranlarına işaret eden 5 adımlık tanıtım turu (bkz. karar K28).
  /// Hedeflerden herhangi biri ağaçta yoksa (ör. sekme remote config ile gizli) o adım
  /// OnboardingTourController tarafından atlanır. Hedefler sekmesi bilinçli olarak dışarıda
  /// bırakıldı: ücretsiz planda kilitli olduğu için turun başında kafa karıştırabilir.
  List<TourStep> _buildTourSteps() => [
        TourStep(
          targetKey: OnboardingTourAnchors.uploadButton,
          title: 'Ekstreni veya bordronu yükle',
          description:
              'Ekstreni veya bordronu buradan yükle, harcamaların otomatik ayrılsın.',
          style: TourStyle.spotlight,
        ),
        TourStep(
          targetKey: OnboardingTourAnchors.quickAddButton,
          title: 'Hızlı işlem ekle',
          description:
              'Nakit harcama ya da ek gelir gibi manuel işlemleri buradan tek dokunuşla ekle.',
          style: TourStyle.spotlight,
        ),
        TourStep(
          targetKey: OnboardingTourAnchors.walletTab,
          title: 'Cüzdan',
          description: 'Kart borçlarını ve bakiyeni burada takip et.',
          style: TourStyle.balloon,
        ),
        TourStep(
          targetKey: OnboardingTourAnchors.analysisTab,
          title: 'Analiz',
          description: 'Harcamalarını kategori kategori gör.',
          style: TourStyle.balloon,
        ),
        TourStep(
          targetKey: OnboardingTourAnchors.assetsTab,
          title: 'Varlıklar',
          description: 'Altın, döviz, araç gibi varlıklarını ekle.',
          style: TourStyle.balloon,
        ),
      ];

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

  /// + menüsünün başlığı sekmeye göre değişir; gerçek metin AppStrings.get(...) ile okunur
  /// (bkz. app_strings.dart 'nav_add_menu_*').
  static const Map<String, String> _addMenuTitleKeys = {
    'dashboard': 'nav_add_menu_dashboard',
    'cashflow': 'nav_add_menu_cashflow',
    'analysis': 'nav_add_menu_analysis',
    'goals': 'nav_add_menu_goals',
    'assets': 'nav_add_menu_assets',
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
    final titleKey = _addMenuTitleKeys[key];
    final title = titleKey != null
        ? AppStrings.get(titleKey)
        : AppStrings.get('nav_add_tooltip');
    showTabAddMenu(context, title, actions);
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
          child: ValueListenableBuilder<SubscriptionTier>(
            valueListenable: SubscriptionService.instance.tierNotifier,
            builder: (context, tier, _) => tier != SubscriptionTier.free
                ? GoalsScreen(key: _screenKeys['goals'])
                : const GoalsLockedView(),
          ),
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
        return FloatingCapsuleNavItem(
          icon: Icons.home_rounded,
          label: AppStrings.get('nav_home'),
        );
      case 'cashflow':
        return FloatingCapsuleNavItem(
          icon: Icons.account_balance_wallet_rounded,
          label: AppStrings.get('nav_cashflow'),
          anchorKey: OnboardingTourAnchors.walletTab,
        );
      case 'analysis':
        return FloatingCapsuleNavItem(
          icon: Icons.pie_chart_rounded,
          label: AppStrings.get('nav_analysis'),
          anchorKey: OnboardingTourAnchors.analysisTab,
        );
      case 'goals':
        return FloatingCapsuleNavItem(
          icon: Icons.flag_rounded,
          label: AppStrings.get('nav_goals'),
        );
      case 'assets':
        return FloatingCapsuleNavItem(
          icon: Icons.account_balance_wallet_rounded,
          label: AppStrings.get('nav_assets'),
          anchorKey: OnboardingTourAnchors.assetsTab,
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
      color: AppColors.cardOf(context),
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
      backgroundColor: AppColors.cardOf(context),
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
            // NOT: burada item.anchorKey KASITLI OLARAK kullanılmaz. Aynı GlobalKey'i hem alt
            // çubuktaki (FloatingCapsuleNavBar, Expanded içinde) hem burada (Icon içinde) aynı anda
            // kullanmak, telefon↔tablet dönüşü (useRail geçişi) sırasında Flutter'ın GlobalKey
            // taşıma/uzlaştırma mekanizmasını bozup "Incorrect use of ParentDataWidget" çökmesine
            // yol açıyordu (bkz. test/adaptive_layout_test.dart rotasyon testi). Tanıtım turu
            // yalnız telefon (alt çubuk) hedefine bağlanır; geniş ekran/tablet rayı kapsam dışı.
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
    // Alt gezinme etiketleri ve + menüsü başlıkları AppStrings'ten okunur; dil değişince
    // (Ayarlar > Dil) bu sekme çubuğu da yeniden çizilsin diye locale dinlenir.
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.currentLocale,
      builder: (context, _, __) => AnimatedBuilder(
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

          // NOT: FloatingActionButton'ın KENDİSİ tanıtım turu GlobalKey'ini taşımaz. Scaffold, FAB
          // değiştiğinde kendi iç geçiş animasyonuyla (scale in/out) ESKİ FAB'ı bir süre ağaçta
          // tutar; telefon↔tablet dönüşünde (useRail geçişi) bu eski FAB ile rayın leading'indeki
          // YENİ FAB aynı anda ağaçta bulunabiliyor — aynı GlobalKey ikisinde de olursa
          // "Multiple widgets used the same GlobalKey" çökmesine yol açıyordu (bkz.
          // test/adaptive_layout_test.dart rotasyon testi). Bu yüzden anahtar yalnız aşağıda,
          // SADECE telefon (alt çubuk) dalındaki kullanım bir KeyedSubtree ile sarılarak eklenir;
          // ray dalındaki kullanım (leading:) anahtarsız kalır (tur yalnız telefon hedefine bağlanır).
          final addButton = isFabHidden
              ? null
              : FloatingActionButton(
                  onPressed: _openAddMenu,
                  tooltip: AppStrings.get('nav_add_tooltip'),
                  backgroundColor: AppColors.dynamicPrimary,
                  elevation: useRail ? 0 : buttonConfig.elevation,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(buttonConfig.borderRadius * 1.5),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 28),
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
                        VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: AppColors.borderOf(context)),
                        Expanded(child: stack),
                      ],
                    ),
                  )
                : Scaffold(
                    extendBody:
                        false, // Temiz native fintech barı, içerik arkada kalmaz
                    body: stack,
                    floatingActionButton: addButton == null
                        ? null
                        : KeyedSubtree(
                            // Tanıtım turu (Adım 2, Stil A) bu düğmeyi hedef alır (yalnız telefon).
                            key: OnboardingTourAnchors.quickAddButton,
                            child: addButton,
                          ),
                    floatingActionButtonLocation:
                        _resolveFabLocation(buttonConfig.fabPosition),
                    bottomNavigationBar: FloatingCapsuleNavBar(
                      currentIndex: _currentIndex,
                      onTap: (index) => setState(() => _currentIndex = index),
                      items: navItems,
                      activeIndicatorColor: AppColors.dynamicPrimary,
                      backgroundColor: AppColors.cardOf(context),
                      inactiveColor: AppColors.textMutedOf(context),
                      borderColor: AppColors.borderOf(context),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
