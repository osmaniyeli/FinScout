// test/onboarding_tour_test.dart
//
// Yeni hesap tanıtım turu: TourStep/overlay widget'larının doğru render olduğunu, "Atla"nın
// çalıştığını ve MediaQuery.accessibleNavigation açıkken Stil C'nin (AccessibleTourCard) devreye
// girdiğini doğrular. OnboardingTourController testleri gerçek Dashboard/MainNavigationScaffold
// ekranlarını kurmaz (ağır bağımlılıklar: DB, RemoteConfigService, SubscriptionService...);
// bunun yerine kendi hafif sahte hedeflerini (GlobalKey) kullanır — gerçek ekranlara bağlama
// (OnboardingTourAnchors + main_navigation_scaffold.dart / dashboard_screen.dart) ayrıca
// `flutter analyze` ve `flutter build apk --debug` ile doğrulanmıştır.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:moneytrace/core/services/user_profile_service.dart';
import 'package:moneytrace/core/widgets/onboarding_tour/accessible_tour_card.dart';
import 'package:moneytrace/core/widgets/onboarding_tour/balloon_tour_overlay.dart';
import 'package:moneytrace/core/widgets/onboarding_tour/onboarding_tour_controller.dart';
import 'package:moneytrace/core/widgets/onboarding_tour/spotlight_tour_overlay.dart';
import 'package:moneytrace/core/widgets/onboarding_tour/tour_step.dart';

class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Bir hedefi test amacıyla kurar: gerçek boyutu/konumu olan, ağaçta bulunabilen bir kutu.
Widget _target(GlobalKey key, {double size = 40}) => Container(
      key: key,
      width: size,
      height: size,
      color: Colors.blue,
    );

/// SpotlightTourOverlay/BalloonTourOverlay hedefin RenderBox'ını build() SIRASINDA okur
/// (`_targetRect()` → `localToGlobal`/`size`). Hedef İLK karede overlay'le AYNI ağaca eklenirse
/// henüz layout almamış olur (build fazı layout fazından önce biter) — bu yüzden önce yalnız
/// hedef basılır (bir kare layout alır), SONRA aynı GlobalKey korunarak overlay eklenen ikinci bir
/// ağaç basılır; Flutter GlobalKey ile hedefin Element'ini (ve son layout'unu) yeniden kullanır.
Future<void> _pumpTargetThenOverlay(
  WidgetTester tester, {
  required GlobalKey targetKey,
  required WidgetBuilder overlayBuilder,
  double targetTop = 100,
  double targetLeft = 50,
}) async {
  Widget tree({required bool withOverlay}) => MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: targetTop,
                left: targetLeft,
                child: _target(targetKey),
              ),
              if (withOverlay) Builder(builder: overlayBuilder),
            ],
          ),
        ),
      );

  await tester.pumpWidget(tree(withOverlay: false));
  await tester.pump();
  await tester.pumpWidget(tree(withOverlay: true));
  await tester.pump();
}

/// OnboardingTourController testleri için sahte ana ekran: gerçek MainNavigationScaffold'daki
/// gibi tetiklemeyi initState'te (postFrame) TEK SEFERLİK yapar — her build()'de değil.
class _TourHost extends StatefulWidget {
  final List<GlobalKey> targetKeys;
  const _TourHost({required this.targetKeys});

  @override
  State<_TourHost> createState() => _TourHostState();
}

class _TourHostState extends State<_TourHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final steps = [
        TourStep(
          targetKey: widget.targetKeys[0],
          title: 'Adım 1',
          description: 'Açıklama 1',
          style: TourStyle.spotlight,
        ),
        TourStep(
          targetKey: widget.targetKeys[1],
          title: 'Adım 2',
          description: 'Açıklama 2',
          style: TourStyle.balloon,
        ),
      ];
      OnboardingTourController.instance.maybeStart(context, steps);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final k in widget.targetKeys) _target(k),
        ],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('finscout_tour_test_');
    PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
    await UserProfileService.instance.saveProfile(UserProfile(
      id: 'tour_test_user',
      name: 'Tour Test User',
      joinedAt: DateTime.now(),
    ));
    OnboardingTourController.instance.resetForTesting();
  });

  tearDown(() async {
    OnboardingTourController.instance.resetForTesting();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Windows'ta dosya tanıtıcısı hemen serbest kalmayabilir; testi bozmasın.
    }
  });

  group('TourStep', () {
    test('varsayılan highlightPadding 8', () {
      final key = GlobalKey();
      final step = TourStep(
        targetKey: key,
        title: 'Başlık',
        description: 'Açıklama',
        style: TourStyle.spotlight,
      );
      expect(step.highlightPadding, 8);
      expect(step.style, TourStyle.spotlight);
    });
  });

  group('SpotlightTourOverlay (Stil A)', () {
    testWidgets('başlık/açıklama/adım sayacını gösterir, İleri onNext çağırır',
        (tester) async {
      final targetKey = GlobalKey();
      var nextTapped = false;
      var skipTapped = false;

      await _pumpTargetThenOverlay(
        tester,
        targetKey: targetKey,
        overlayBuilder: (context) => SpotlightTourOverlay(
          step: TourStep(
            targetKey: targetKey,
            title: 'Ekstreni yükle',
            description: 'Ekstreni buradan yükle.',
            style: TourStyle.spotlight,
          ),
          stepNumber: 1,
          totalSteps: 5,
          onNext: () => nextTapped = true,
          onSkip: () => skipTapped = true,
        ),
      );

      expect(find.text('Ekstreni yükle'), findsOneWidget);
      expect(find.text('Ekstreni buradan yükle.'), findsOneWidget);
      expect(find.text('1/5'), findsOneWidget);
      expect(find.text('İleri'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tour_next_button')));
      await tester.pump();
      expect(nextTapped, isTrue);
      expect(skipTapped, isFalse);
    });

    testWidgets('son adımda "Anladım" gösterir', (tester) async {
      final targetKey = GlobalKey();
      await _pumpTargetThenOverlay(
        tester,
        targetKey: targetKey,
        overlayBuilder: (context) => SpotlightTourOverlay(
          step: TourStep(
            targetKey: targetKey,
            title: 'Son adım',
            description: 'Açıklama',
            style: TourStyle.spotlight,
          ),
          stepNumber: 5,
          totalSteps: 5,
          onNext: () {},
          onSkip: () {},
        ),
      );
      expect(find.text('Anladım'), findsOneWidget);
      expect(find.text('İleri'), findsNothing);
    });

    testWidgets('"Atla" onSkip çağırır', (tester) async {
      final targetKey = GlobalKey();
      var skipTapped = false;
      await _pumpTargetThenOverlay(
        tester,
        targetKey: targetKey,
        overlayBuilder: (context) => SpotlightTourOverlay(
          step: TourStep(
            targetKey: targetKey,
            title: 'Başlık',
            description: 'Açıklama',
            style: TourStyle.spotlight,
          ),
          stepNumber: 1,
          totalSteps: 3,
          onNext: () {},
          onSkip: () => skipTapped = true,
        ),
      );

      await tester.tap(find.byKey(const Key('tour_skip_button')));
      await tester.pump();
      expect(skipTapped, isTrue);
    });

    testWidgets('hedef ağaçta yokken (currentContext null) patlamaz, balon gösterilmez',
        (tester) async {
      // targetKey hiçbir yere takılmadı: SpotlightTourOverlay yine de hatasız render olmalı
      // (rect null -> yalnız tam ekran karartma, balon yok).
      final orphanKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpotlightTourOverlay(
            step: TourStep(
              targetKey: orphanKey,
              title: 'Görünmeyen hedef',
              description: 'Açıklama',
              style: TourStyle.spotlight,
            ),
            stepNumber: 1,
            totalSteps: 1,
            onNext: () {},
            onSkip: () {},
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Görünmeyen hedef'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('BalloonTourOverlay (Stil B)', () {
    testWidgets('başlık/açıklama gösterir, tam ekran karartma yok, Atla çalışır',
        (tester) async {
      final targetKey = GlobalKey();
      var skipTapped = false;

      await _pumpTargetThenOverlay(
        tester,
        targetKey: targetKey,
        targetTop: 400,
        overlayBuilder: (context) => BalloonTourOverlay(
          step: TourStep(
            targetKey: targetKey,
            title: 'Cüzdan',
            description: 'Kart borçlarını burada takip et.',
            style: TourStyle.balloon,
          ),
          stepNumber: 3,
          totalSteps: 5,
          onNext: () {},
          onSkip: () => skipTapped = true,
        ),
      );

      expect(find.text('Cüzdan'), findsOneWidget);
      expect(find.text('Kart borçlarını burada takip et.'), findsOneWidget);
      // Balon stilinde tam ekran karartma (spotlight'a özgü CustomPaint) YOK.
      expect(find.byType(SpotlightTourOverlay), findsNothing);

      await tester.tap(find.byKey(const Key('tour_skip_button')));
      await tester.pump();
      expect(skipTapped, isTrue);
    });
  });

  group('AccessibleTourCard (Stil C)', () {
    testWidgets('tüm adımları listeler, Anladım kapatır', (tester) async {
      var closed = false;
      final steps = [
        TourStep(
          targetKey: GlobalKey(),
          title: 'Ekstreni yükle',
          description: 'Açıklama 1',
          style: TourStyle.spotlight,
        ),
        TourStep(
          targetKey: GlobalKey(),
          title: 'Cüzdan',
          description: 'Açıklama 2',
          style: TourStyle.balloon,
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: AccessibleTourCard(steps: steps, onClose: () => closed = true),
      ));
      await tester.pump();

      expect(find.text('Ekstreni yükle'), findsOneWidget);
      expect(find.text('Açıklama 1'), findsOneWidget);
      expect(find.text('Cüzdan'), findsOneWidget);
      expect(find.text('Açıklama 2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tour_finish_button')));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('üstteki kapat düğmesi de turu kapatır', (tester) async {
      var closed = false;
      await tester.pumpWidget(MaterialApp(
        home: AccessibleTourCard(
          steps: [
            TourStep(
              targetKey: GlobalKey(),
              title: 'Tek adım',
              description: 'Açıklama',
              style: TourStyle.spotlight,
            ),
          ],
          onClose: () => closed = true,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('tour_skip_button')));
      await tester.pump();
      expect(closed, isTrue);
    });
  });

  group('OnboardingTourController — orkestrasyon', () {
    Widget hostWidget({
      required List<GlobalKey> targetKeys,
      bool accessibleNavigation = false,
    }) {
      // Gerçek kullanımda olduğu gibi (bkz. main_navigation_scaffold.dart) tetikleme initState'te,
      // TEK SEFERLİK yapılır — Builder.build() içine koymak her yeniden çizimde (ör. "İleri"
      // tıklanınca overlay eklenmesiyle tetiklenen rebuild'de) maybeStart'ı tekrar tekrar
      // çağırırdı. Ekran boyutu sabit tutulur (800x600, flutter_test'in varsayılan yüzeyi):
      // MediaQueryData()'nın varsayılan size'ı Size.zero'dur, bu da SpotlightTourOverlay'in
      // balon konumlandırma hesabını (bkz. spotlight_tour_overlay.dart _buildBubble) bozardı.
      return MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          accessibleNavigation: accessibleNavigation,
        ),
        child: MaterialApp(
          home: Scaffold(
            body: _TourHost(targetKeys: targetKeys),
          ),
        ),
      );
    }

    testWidgets(
        'accessibleNavigation KAPALI: spotlight overlay gösterir (Stil A ilk adım)',
        (tester) async {
      OnboardingTourController.instance.scheduleForNewAccount();
      final keys = [GlobalKey(), GlobalKey()];

      await tester.pumpWidget(hostWidget(targetKeys: keys));
      await tester.pumpAndSettle();

      expect(find.text('Adım 1'), findsOneWidget);
      expect(find.byType(SpotlightTourOverlay), findsOneWidget);
      expect(find.byType(AccessibleTourCard), findsNothing);
    });

    testWidgets('"Atla" turu tamamen kapatır (kalan adımlar gösterilmez)',
        (tester) async {
      OnboardingTourController.instance.scheduleForNewAccount();
      final keys = [GlobalKey(), GlobalKey()];

      await tester.pumpWidget(hostWidget(targetKeys: keys));
      await tester.pumpAndSettle();
      expect(find.text('Adım 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tour_skip_button')));
      await tester.pumpAndSettle();

      expect(find.text('Adım 1'), findsNothing);
      expect(find.text('Adım 2'), findsNothing);
    });

    testWidgets('İleri ile bir sonraki adıma (balon) geçer', (tester) async {
      OnboardingTourController.instance.scheduleForNewAccount();
      final keys = [GlobalKey(), GlobalKey()];

      await tester.pumpWidget(hostWidget(targetKeys: keys));
      await tester.pumpAndSettle();
      expect(find.text('Adım 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tour_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Adım 1'), findsNothing);
      expect(find.text('Adım 2'), findsOneWidget);
      expect(find.byType(BalloonTourOverlay), findsOneWidget);
    });

    testWidgets(
        'accessibleNavigation AÇIK: spotlight/balon yerine erişilebilir kart (Stil C)',
        (tester) async {
      OnboardingTourController.instance.scheduleForNewAccount();
      final keys = [GlobalKey(), GlobalKey()];

      await tester.pumpWidget(
          hostWidget(targetKeys: keys, accessibleNavigation: true));
      await tester.pumpAndSettle();

      expect(find.byType(AccessibleTourCard), findsOneWidget);
      expect(find.byType(SpotlightTourOverlay), findsNothing);
      expect(find.byType(BalloonTourOverlay), findsNothing);
      // Erişilebilir kartta TÜM adımlar aynı anda listelenir.
      expect(find.text('Adım 1'), findsOneWidget);
      expect(find.text('Adım 2'), findsOneWidget);
    });

    testWidgets('scheduleForNewAccount çağrılmadıysa tur hiç başlamaz',
        (tester) async {
      final keys = [GlobalKey(), GlobalKey()];
      await tester.pumpWidget(hostWidget(targetKeys: keys));
      await tester.pumpAndSettle();

      expect(find.byType(SpotlightTourOverlay), findsNothing);
      expect(find.byType(AccessibleTourCard), findsNothing);
    });

    testWidgets(
        'hasSeenOnboardingTour zaten true ise (önceki oturumdan) tur tekrar başlamaz',
        (tester) async {
      // Doğrudan await edilen gerçek dosya I/O'su (markOnboardingTourSeen -> _persist), henüz hiç
      // pump() çağrılmamışken flutter_test'in kare zamanlama zone'u içinde tıkanabiliyor; bilinen
      // "real async work" kaçış yolu tester.runAsync() ile gerçek olay döngüsünde çalıştırılır.
      await tester.runAsync(
          () => UserProfileService.instance.markOnboardingTourSeen());
      expect(UserProfileService.instance.profile?.hasSeenOnboardingTour, isTrue);

      OnboardingTourController.instance.scheduleForNewAccount();
      final keys = [GlobalKey(), GlobalKey()];
      await tester.pumpWidget(hostWidget(targetKeys: keys));
      await tester.pumpAndSettle();

      expect(find.byType(SpotlightTourOverlay), findsNothing);
    });

    testWidgets('tur başlayınca hasSeenOnboardingTour kalıcı olarak işaretlenir',
        (tester) async {
      expect(UserProfileService.instance.profile?.hasSeenOnboardingTour, isFalse);
      OnboardingTourController.instance.scheduleForNewAccount();
      final keys = [GlobalKey(), GlobalKey()];

      await tester.pumpWidget(hostWidget(targetKeys: keys));
      await tester.pumpAndSettle();

      expect(UserProfileService.instance.profile?.hasSeenOnboardingTour, isTrue);
    });
  });
}
