// Farklı ekran boyutları ve büyük yazı boyutunda yerleşim testleri.
// Golden değil: yalnız taşma (RenderFlex overflowed / FlutterError) olmadığını ve
// geniş ekranda doğru gezinme/sütun düzeninin seçildiğini doğrular.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/layout/adaptive.dart';
import 'package:moneytrace/core/widgets/fintech/app_lock_screen.dart';
import 'package:moneytrace/core/widgets/floating_capsule_nav_bar.dart';
import 'package:moneytrace/core/widgets/morphing_segmented_bar.dart';
import 'package:moneytrace/features/analysis/presentation/payslip_view.dart';
import 'package:moneytrace/features/analysis/services/payslip_analytics_service.dart';
import 'package:moneytrace/features/goals/models/financial_goal.dart';
import 'package:moneytrace/features/goals/services/goal_calculator_service.dart';
import 'package:moneytrace/features/goals/widgets/goal_card_tile.dart';
import 'package:moneytrace/features/goals/widgets/goal_summary_header.dart';
import 'package:moneytrace/core/services/user_profile_service.dart';
import 'package:moneytrace/features/analysis/presentation/analysis_screen.dart';
import 'package:moneytrace/features/assets_portfolio/presentation/assets_screen.dart';
import 'package:moneytrace/features/cashflow_projection/presentation/cashflow_screen.dart';
import 'package:moneytrace/features/dashboard/presentation/dashboard_screen.dart';
import 'package:moneytrace/features/family/presentation/family_screen.dart';
import 'package:moneytrace/features/goals/presentation/goals_screen.dart';
import 'package:moneytrace/features/navigation/main_navigation_scaffold.dart';
import 'package:moneytrace/features/notifications/presentation/notifications_sheet.dart';
import 'package:moneytrace/features/onboarding/presentation/onboarding_screen.dart';
import 'package:moneytrace/features/profile/presentation/profile_screen.dart';
import 'package:moneytrace/features/settings/presentation/licenses_screen.dart';
import 'package:moneytrace/features/settings/presentation/settings_screen.dart';

/// Test edilen pencere boyutları (dp): telefon, tablet dikey, tablet yatay.
const _sizes = <String, Size>{
  'telefon 360x800': Size(360, 800),
  'tablet dikey 600x960': Size(600, 960),
  'tablet yatay 1280x800': Size(1280, 800),
  'telefon yatay 800x360': Size(800, 360),
  'katlanabilir açık 884x1104': Size(884, 1104),
  'telefon yatay (ray) 900x400': Size(900, 400),
};

/// Her boyut 1.0 ve 1.6 yazı ölçeğiyle denenir.
const _scales = [1.0, 1.6];

// Uygulama teması GoogleFonts kullanır (testte ağdan font indirmeye çalışır); burada yalnız
// yerleşimi etkileyen parçalar taklit edilir: M3 + alt sayfa genişlik sınırı.
final _theme = ThemeData(
  useMaterial3: true,
  bottomSheetTheme: const BottomSheetThemeData(
    constraints: BoxConstraints(maxWidth: Breakpoints.sheet),
  ),
);

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  double scale,
  Widget home,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: _theme,
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
      ),
      child: child!,
    ),
    home: home,
  ));
  // İlk kare + ekranların (başarısız) veri yüklemesi sonrası kare
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Hata anında yakalanan ayrıntılar (taşan widget'ın kaynak satırı): başarısız testin mesajında.
final _errorLog = <String>[];

/// Çizimde hata yoksa geçer; varsa hangi widget'ın taştığını da mesaja koyar.
void _expectNoError(WidgetTester tester, {String? reason}) {
  final error = tester.takeException();
  if (error == null) return;
  final where = _errorLog
      .expand((s) => s.split('\n'))
      .where((l) => l.contains('overflowed') || l.contains('.dart:'))
      .toSet()
      .join('\n');
  fail('${reason ?? ''} $error\n$where');
}

/// Test gövdesini, çizim hatalarının ayrıntısını kaydederek çalıştırır.
Future<void> _withErrorLog(Future<void> Function() body) async {
  _errorLog.clear();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _errorLog.add(details.toString());
    previous?.call(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
}

/// [body]'yi tüm boyut × ölçek kombinasyonlarında çizer ve taşma olmadığını doğrular.
void _expectNoOverflow(
  String name,
  Widget Function() body, {
  Future<void> Function(WidgetTester tester, Size size)? extra,
}) {
  for (final entry in _sizes.entries) {
    for (final scale in _scales) {
      testWidgets('$name · ${entry.key} · yazı ×$scale taşmaz', (tester) async {
        await _withErrorLog(() async {
          await _pumpAt(tester, entry.value, scale, body());
          _expectNoError(tester);
          if (extra != null) {
            await extra(tester, entry.value);
            _expectNoError(tester);
          }
        });
        // Ekranların zamanlayıcıları / yarım kalan yüklemeleri test bitmeden kapansın
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(minutes: 5));
      });
    }
  }
}

FinancialGoal _goal(
        String id, String title, int target, int saved, int months) =>
    FinancialGoal(
      id: id,
      title: title,
      category: GoalCategory.values[id.hashCode % GoalCategory.values.length],
      targetAmountCents: target,
      currentSavedCents: saved,
      targetDate: DateTime.now().add(Duration(days: 30 * months)),
      createdAt: DateTime(2026, 1, 1),
    );

final _goals = [
  _goal('1', 'Yeni araba peşinatı için uzun bir hedef adı', 125000000, 43250075,
      18),
  _goal('2', 'Tatil', 8500000, 8500000, 3),
  _goal('3', 'Ev', 950000000, 12000000, 60),
  _goal('4', 'Telefon', 6000000, 1500000, 2),
  _goal('5', 'Düğün hediyesi', 2500000, 0, 1),
];

List<PayslipMonth> _payslipMonths() => [
      for (var y = 2023; y <= 2026; y++)
        for (var m = 1; m <= 12; m++)
          if (!(y == 2026 && m > 8) && !(y == 2024 && m == 5))
            PayslipMonth(
              year: y,
              month: m,
              netCents: 4500000 + y * 1000 + m * 12345,
              grossCents: 6200000 + y * 1500 + m * 15000,
              incomeTaxCents: 780000 + m * 1000,
              stampTaxCents: 47000,
              sgkCents: 868000,
              unemploymentCents: 62000,
              baseWageCents: y >= 2025 ? 6200000 : 5400000,
            ),
    ];

void main() {
  group('pencere boyutu sınıfları (M3)', () {
    test('kırılım noktaları', () {
      expect(WindowSizeClass.fromWidth(360), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(599.9), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(839), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1280), WindowSizeClass.large);
      expect(WindowSizeClass.fromWidth(1600), WindowSizeClass.extraLarge);
    });

    test('okunabilir dolgu yalnız geniş alanda eklenir', () {
      const base = EdgeInsets.symmetric(horizontal: 16);
      expect(readablePadding(360, base), base);
      final wide = readablePadding(1200, base, maxWidth: 720);
      expect(1200 - wide.horizontal, closeTo(720, 0.001));
      expect(wide.left, wide.right);
    });

    test('ızgara sütun sayısı genişliğe göre', () {
      expect(AdaptiveGrid.columnsFor(328, minItemWidth: 340), 1);
      expect(AdaptiveGrid.columnsFor(700, minItemWidth: 340), 2);
      expect(AdaptiveGrid.columnsFor(1080, minItemWidth: 340), 3);
      expect(
          AdaptiveGrid.columnsFor(3000, minItemWidth: 340, maxColumns: 3), 3);
    });
  });

  group('AdaptiveBody', () {
    testWidgets('geniş ekranda içeriği ortalar ve genişliği sınırlar',
        (tester) async {
      await _pumpAt(
        tester,
        const Size(1280, 800),
        1.0,
        const Scaffold(
          body: SingleChildScrollView(
            child: AdaptiveBody(
                child: SizedBox(
                    key: Key('c'), width: double.infinity, height: 50)),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(const Key('c')));
      expect(rect.width, Breakpoints.readable);
      expect(rect.center.dx, closeTo(640, 0.5));
    });

    testWidgets('telefonda tam genişlik', (tester) async {
      await _pumpAt(
        tester,
        const Size(360, 800),
        1.0,
        const Scaffold(
          body: SingleChildScrollView(
            child: AdaptiveBody(
                child: SizedBox(
                    key: Key('c'), width: double.infinity, height: 50)),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('c'))).width, 360);
    });
  });

  group('alt sayfa (bottom sheet)', () {
    testWidgets('tablette ortalanır ve en fazla 640 dp genişler',
        (tester) async {
      await _pumpAt(
        tester,
        const Size(1280, 800),
        1.0,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const SizedBox(
                      key: Key('sheet'), width: double.infinity, height: 200),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(const Key('sheet')));
      expect(rect.width, Breakpoints.sheet);
      expect(rect.center.dx, closeTo(640, 0.5));
    });
  });

  group('gezinme çubuğu', () {
    const items = [
      FloatingCapsuleNavItem(icon: Icons.home_rounded, label: 'Ana Sayfa'),
      FloatingCapsuleNavItem(
          icon: Icons.account_balance_wallet_rounded, label: 'Cüzdan'),
      FloatingCapsuleNavItem(icon: Icons.pie_chart_rounded, label: 'Analiz'),
      FloatingCapsuleNavItem(icon: Icons.flag_rounded, label: 'Hedefler'),
      FloatingCapsuleNavItem(
          icon: Icons.account_balance_wallet_rounded, label: 'Varlıklar'),
    ];
    _expectNoOverflow(
      'FloatingCapsuleNavBar',
      () => Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: FloatingCapsuleNavBar(
          currentIndex: 2,
          onTap: (_) {},
          items: items,
        ),
      ),
    );
  });

  group('ortak bileşenler', () {
    _expectNoOverflow(
      'MorphingSegmentedBar',
      () => Scaffold(
        body: Column(
          children: [
            MorphingSegmentedBar(
              segments: const [
                'Dağılım',
                'Aylık Trend',
                'Masraflar',
                'Maaş/Vergi'
              ],
              selectedIndex: 1,
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    );

    _expectNoOverflow(
      'Hedef özeti + kart ızgarası',
      () => Scaffold(
        body: SingleChildScrollView(
          child: AdaptiveBody(
            maxWidth: Breakpoints.wide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GoalSummaryHeader(
                    summary: GoalCalculatorService.calculateSummary(_goals)),
                AdaptiveGrid(
                  minItemWidth: 340,
                  spacing: 0,
                  runSpacing: 0,
                  children: [
                    for (final g in _goals)
                      GoalCardTile(
                          goal: g, onTap: () {}, onAddContribution: () {}),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    testWidgets('hedef kartları tablet yatayda 3 sütun', (tester) async {
      await _pumpAt(
        tester,
        const Size(1280, 800),
        1.0,
        Scaffold(
          body: SingleChildScrollView(
            child: AdaptiveBody(
              maxWidth: Breakpoints.wide,
              child: AdaptiveGrid(
                minItemWidth: 340,
                spacing: 0,
                runSpacing: 0,
                children: [for (final g in _goals) GoalCardTile(goal: g)],
              ),
            ),
          ),
        ),
      );
      final tops = find
          .byType(GoalCardTile)
          .evaluate()
          .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy)
          .toList();
      // İlk üç kart aynı satırda
      expect(tops[0], tops[1]);
      expect(tops[1], tops[2]);
      expect(tops[3], greaterThan(tops[0]));
    });
  });

  group('Maaş/Vergi (bordro) görünümü', () {
    _expectNoOverflow(
      'PayslipView',
      () => Scaffold(
        body: PayslipView(loadMonths: () async => _payslipMonths()),
      ),
      extra: (tester, size) async {
        // Yıllık görünüm ve kesinti kırılımı (yığılmış çubuk + lejant)
        // Önce ölçü (üst satır), sonra aylık/yıllık: ensureVisible listeyi kaydırır
        await tester.ensureVisible(find.text('Kesintiler'));
        await tester.tap(find.text('Kesintiler'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.ensureVisible(find.text('Yıllık'));
        await tester.tap(find.text('Yıllık'));
        await tester.pump(const Duration(milliseconds: 400));
      },
    );

    _expectNoOverflow(
      'PayslipView boş durum',
      () => Scaffold(body: PayslipView(loadMonths: () async => const [])),
    );
  });

  group('ekranlar', () {
    // Testte veritabanı/ağ eklentileri yok: ekranlar boş / veri yok durumunda çizilir.
    _expectNoOverflow('Açık kaynak lisansları', () => const LicensesScreen());
    _expectNoOverflow('Ana sayfa', () => const DashboardScreen());
    _expectNoOverflow('Cüzdan', () => const CashflowScreen());
    _expectNoOverflow('Hedefler', () => const GoalsScreen());
    _expectNoOverflow(
      'Analiz',
      () => const AnalysisScreen(),
      extra: (tester, size) async {
        for (final tab in [
          'Aylık Trend',
          'Masraflar',
          'Maaş/Vergi',
          'Dağılım'
        ]) {
          await tester.tap(find.text(tab).first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: tab);
        }
      },
    );
    _expectNoOverflow('Varlıklar', () => const AssetsScreen());
    _expectNoOverflow('Profil', () => const ProfileScreen());
    _expectNoOverflow('Ayarlar', () => const SettingsScreen());
    _expectNoOverflow('Aile', () => const FamilyScreen());
    _expectNoOverflow('Karşılama', () => OnboardingScreen(onCompleted: () {}));
    _expectNoOverflow('PIN kilidi', () => AppLockScreen(onUnlocked: () {}));
    _expectNoOverflow(
      'Bildirimler',
      () {
        UserProfileService.instance.notificationsNotifier.value = [
          InAppNotificationItem(
            id: 't1',
            title:
                "İzci'den bir not: harcama dağılımınız hazır, Analiz sekmesine göz atın",
            message:
                'İşlemleriniz kategorilerine göre sınıflandırıldı. Harcama dağılımınızı '
                'Analiz sekmesinde inceleyebilirsiniz.',
            date: DateTime(2026, 9, 25, 9, 5),
          ),
        ];
        return const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: NotificationsSheet(),
          ),
        );
      },
    );
  });

  group('ana gezinme', () {
    _expectNoOverflow(
      'MainNavigationScaffold',
      () => const MainNavigationScaffold(),
      extra: (tester, size) async {
        final wide = size.width >= Breakpoints.expanded;
        expect(
            find.byType(NavigationRail), wide ? findsOneWidget : findsNothing);
        expect(find.byType(FloatingCapsuleNavBar),
            wide ? findsNothing : findsOneWidget);
        // + düğmesi her iki düzende de var
        expect(find.byTooltip('Ekle'), findsOneWidget);
        // Tüm sekmeler gezilir
        final bar = wide
            ? find.byType(NavigationRail)
            : find.byType(FloatingCapsuleNavBar);
        for (final label in [
          'Cüzdan',
          'Analiz',
          'Hedefler',
          'Varlıklar',
          'Ana Sayfa'
        ]) {
          await tester.tap(find.descendant(of: bar, matching: find.text(label)),
              warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: label);
        }
      },
    );

    testWidgets(
        'döndürünce (alt çubuk → ray) seçili sekme ve ekran durumu korunur',
        (tester) async {
      await _pumpAt(
          tester, const Size(600, 960), 1.0, const MainNavigationScaffold());
      await tester.tap(find.descendant(
          of: find.byType(FloatingCapsuleNavBar),
          matching: find.text('Hedefler')));
      await tester.pump(const Duration(milliseconds: 400));
      final goalsState = tester.state(find.byType(GoalsScreen));

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(NavigationRail), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 3);
      expect(tester.state(find.byType(GoalsScreen)), same(goalsState));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 5));
    });
  });
}
