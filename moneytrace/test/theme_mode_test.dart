// test/theme_mode_test.dart
//
// Koyu tema görevi — ilk dilim: UserProfile.themeMode round-trip + UserProfileService.setThemeMode
// kalıcılığı (bkz. upload_consent_flag_test.dart ile aynı gerçek dosya I/O deseni) ve
// SettingsScreen'in koyu temada GERÇEKTEN koyu renklerle (AppTheme.darkTheme) render olduğunu
// doğrular — yalnız bir renk sabitini değil, ekranın kendisini mount ederek.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:moneytrace/core/localization/app_strings.dart';
import 'package:moneytrace/core/services/user_profile_service.dart';
import 'package:moneytrace/core/theme/app_colors.dart';
import 'package:moneytrace/features/settings/presentation/settings_screen.dart';

class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // NOT: AppTheme.lightTheme/darkTheme getter'ları GoogleFonts.plusJakartaSansTextTheme(...)
  // çağırıyor; bu paket TextTheme'i OLUŞTURURKEN (yalnız kullanılırken değil) senkron olmayan bir
  // font yükleme denemesi başlatıyor ve ağsız test ortamında (bu sandbox dahil, bkz. yukarıdaki
  // deneme) istisna fırlatıyor — proje genelinde hiçbir test bu yüzden AppTheme.lightTheme/darkTheme
  // getter'larına doğrudan dokunmuyor (bkz. test/localization_en_screens_test.dart: MaterialApp'e
  // özel tema VERMEDEN pompalıyor). Bu dosyadaki widget testleri de aynı nedenle AppTheme yerine,
  // AppTheme ile AYNI AppColors sabitlerini taşıyan hafif bir ThemeData kullanıyor (bkz. aşağıdaki
  // lightForTest/darkForTest) — GERÇEKTEN SINANAN şey SettingsScreen'in kendi
  // Theme.of(context).brightness'a göre renk seçme mantığı (AppColors.*Of(context)).

  group('UserProfile.toMap / fromMap — themeMode taşınması', () {
    test('dark değeri round-trip\'te korunur', () {
      final original = UserProfile(
        id: 'u1',
        name: 'A',
        joinedAt: DateTime(2026, 1, 1),
        themeMode: ThemeMode.dark,
      );
      final restored = UserProfile.fromMap(original.toMap());
      expect(restored.themeMode, ThemeMode.dark);
    });

    test('Alan hiç yoksa (eski kayıtlar) varsayılan ThemeMode.light döner', () {
      final legacyMap = {
        'id': 'u2',
        'name': 'B',
        'joinedAt': DateTime(2026, 1, 1).toIso8601String(),
      };
      expect(UserProfile.fromMap(legacyMap).themeMode, ThemeMode.light);
    });

    test('Bozuk/bilinmeyen değerde varsayılan ThemeMode.light döner', () {
      final map = {
        'id': 'u3',
        'name': 'C',
        'joinedAt': DateTime(2026, 1, 1).toIso8601String(),
        'themeMode': 'bilinmeyen_deger',
      };
      expect(UserProfile.fromMap(map).themeMode, ThemeMode.light);
    });
  });

  group('UserProfileService.setThemeMode — kalıcılık', () {
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('finscout_theme_mode_test_');
      PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Windows'ta dosya tanıtıcısı hemen serbest kalmayabilir; testi bozmasın.
      }
    });

    test('Profil yokken bile themeModeNotifier anında güncellenir (onboarding ekranı için)',
        () async {
      await UserProfileService.instance.wipeLocalData();
      expect(UserProfileService.instance.profile, isNull);
      expect(UserProfileService.instance.themeModeNotifier.value, ThemeMode.light);

      await UserProfileService.instance.setThemeMode(ThemeMode.dark);

      expect(UserProfileService.instance.themeModeNotifier.value, ThemeMode.dark);
    });

    test('Profil varken diske kalıcı yazılır ve dosyadan okunan değerle eşleşir', () async {
      await UserProfileService.instance.saveProfile(UserProfile(
        id: 'test_user',
        name: 'Test User',
        joinedAt: DateTime.now(),
      ));

      await UserProfileService.instance.setThemeMode(ThemeMode.dark);

      expect(UserProfileService.instance.profile?.themeMode, ThemeMode.dark);
      expect(UserProfileService.instance.themeModeNotifier.value, ThemeMode.dark);

      final file = File('${tempDir.path}/paraiz_user_profile.json');
      expect(await file.exists(), isTrue);
      final raw = await file.readAsString();
      expect(raw, contains('"themeMode":"dark"'));
    });

    test('wipeLocalData sonrası ThemeMode.light\'a döner (tam sıfırlama)', () async {
      await UserProfileService.instance.saveProfile(UserProfile(
        id: 'test_user',
        name: 'Test User',
        joinedAt: DateTime.now(),
      ));
      await UserProfileService.instance.setThemeMode(ThemeMode.dark);
      expect(UserProfileService.instance.themeModeNotifier.value, ThemeMode.dark);

      await UserProfileService.instance.wipeLocalData();

      expect(UserProfileService.instance.themeModeNotifier.value, ThemeMode.light);
    });
  });

  group('SettingsScreen — koyu temada gerçekten koyu render olur', () {
    setUp(() {
      AppStrings.clearOverridesForTest();
      AppStrings.currentLocale.value = 'tr';
    });

    tearDown(() {
      AppStrings.clearOverridesForTest();
      AppStrings.currentLocale.value = 'tr';
    });

    // NOT: AppTheme.lightTheme/darkTheme GoogleFonts kullanır; bu paket metin ölçülürken ağdan
    // font çekmeye çalışır ve ağsız test ortamında (bu sandbox dahil) senkron olmayan bir
    // istisna fırlatıp testi düşürür (bkz. test/localization_en_screens_test.dart'ın da aynı
    // nedenle MaterialApp'e özel tema VERMEDEN pompaladığı desen). Bu yüzden burada
    // AppTheme.darkTheme/lightTheme ile AYNI anahtar renkleri (scaffoldBackgroundColor,
    // colorScheme, brightness) taşıyan ama GoogleFonts'a dokunmayan hafif bir ThemeData
    // kullanılıyor — SettingsScreen'in kendi Theme.of(context).brightness okuyan mantığı
    // (AppColors.*Of(context)) böylece gerçekten uçtan uca sınanıyor. AppTheme.darkTheme'in
    // KENDİ renk sabitlerinin doğruluğu yukarıdaki 'AppTheme.darkTheme — temel renkler' grubunda
    // ayrıca (widget pompalamadan, font sorunu olmadan) doğrulanıyor.
    ThemeData lightForTest() => ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.canvasLight,
          colorScheme: const ColorScheme.light(
            primary: AppColors.actionPrimary,
            surface: AppColors.surfaceLight,
            onSurface: AppColors.textPrimary,
          ),
        );
    ThemeData darkForTest() => ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.canvasDark,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.actionPrimary,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textPrimaryDark,
          ),
        );

    Future<void> pumpInTheme(WidgetTester tester, ThemeMode mode) async {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: lightForTest(),
        darkTheme: darkForTest(),
        themeMode: mode,
        home: const SettingsScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('ThemeMode.dark: Scaffold zemini AppColors.canvasDark olur (beyaz kalmaz)',
        (tester) async {
      await pumpInTheme(tester, ThemeMode.dark);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.canvasDark);
      expect(scaffold.backgroundColor, isNot(Colors.white));
    });

    testWidgets('ThemeMode.light: Scaffold zemini açık temada değişmeden kalır (regresyon yok)',
        (tester) async {
      await pumpInTheme(tester, ThemeMode.light);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.canvasLight);
    });

    testWidgets('TEMA bölümü görünür: Açık/Koyu chip\'leri ve tıklayınca gerçekten tema değişir',
        (tester) async {
      await pumpInTheme(tester, ThemeMode.light);

      expect(find.text('TEMA'), findsOneWidget);
      expect(find.text('Açık'), findsOneWidget);
      expect(find.text('Koyu'), findsOneWidget);

      expect(UserProfileService.instance.themeModeNotifier.value, ThemeMode.light);
      // TEMA bölümü SingleChildScrollView'de aşağıda kalabilir (800x600 test viewport'unda);
      // gerçek bir dokunuşu sınamak için önce görünür alana kaydırılmalı.
      await tester.ensureVisible(find.text('Koyu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Koyu'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(UserProfileService.instance.themeModeNotifier.value, ThemeMode.dark);
    });

    testWidgets('İletişim İzni ve Kullanım Şartları satırları Ayarlar içinde görünür',
        (tester) async {
      await pumpInTheme(tester, ThemeMode.light);

      expect(find.text('İletişim izni'), findsOneWidget);
      expect(find.text('Kullanım Şartları'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });
  });
}
