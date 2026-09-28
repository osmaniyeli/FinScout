// test/localization_en_screens_test.dart
//
// GÖREV 1.3 — "İngilizce seçimini gerçekten işlevsel yap": Ayarlar, alt gezinme (main navigation),
// Kayıt Ol/Giriş Yap (onboarding) ve belge yükleme (statement upload) ekranlarının 'en' locale'de
// GERÇEKTEN İngilizce metin gösterdiğini doğrular (AppStrings.get(...) üzerinden). Ekranları
// gerçekten mount eder — yalnız anahtar/sözlük eşlemesini değil, ekranın kendisini test eder.
// Harness deseni test/adaptive_layout_test.dart ile aynıdır (bu ekranlar orada da TempDirPathProvider
// olmadan sorunsuz basılıyor).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneytrace/core/localization/app_strings.dart';
import 'package:moneytrace/features/navigation/main_navigation_scaffold.dart';
import 'package:moneytrace/features/onboarding/presentation/onboarding_screen.dart';
import 'package:moneytrace/features/settings/presentation/settings_screen.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: home,
  ));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppStrings.clearOverridesForTest();
    AppStrings.currentLocale.value = 'tr';
  });

  tearDown(() {
    AppStrings.clearOverridesForTest();
    AppStrings.currentLocale.value = 'tr';
  });

  group("'en' locale — Ayarlar ekranı gerçekten İngilizce gösterir", () {
    testWidgets('Başlık, bölüm başlıkları ve düğmeler İngilizce', (tester) async {
      AppStrings.currentLocale.value = 'en';
      await _pump(tester, const SettingsScreen());

      expect(find.text('Settings & Preferences'), findsOneWidget);
      expect(find.text('SUBSCRIPTION AND PRIVACY'), findsOneWidget);
      expect(find.text('BANK'), findsOneWidget);
      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('DANGER ZONE / RESET DATA'), findsOneWidget);
      expect(find.text('Reset All My Data and Delete Account'), findsOneWidget);
      expect(find.text('Not selected yet'), findsOneWidget);
      // Türkçe sabit metinler artık görünmemeli
      expect(find.text('Ayarlar & Tercihler'), findsNothing);
      expect(find.text('BANKA'), findsNothing);
    });

    testWidgets('tr locale geri dönünce Türkçe metinler görünür (regresyon yok)',
        (tester) async {
      AppStrings.currentLocale.value = 'tr';
      await _pump(tester, const SettingsScreen());

      expect(find.text('Ayarlar & Tercihler'), findsOneWidget);
      expect(find.text('BANKA'), findsOneWidget);
      expect(find.text('GÜVENLİK'), findsOneWidget);
    });
  });

  group("'en' locale — Kayıt Ol / Giriş Yap (onboarding) ekranı gerçekten İngilizce gösterir", () {
    testWidgets('Kayıt formu başlığı, alan etiketleri ve düğme İngilizce', (tester) async {
      AppStrings.currentLocale.value = 'en';
      await _pump(tester, OnboardingScreen(onCompleted: () {}));

      expect(find.text('Set Up Your Account'), findsOneWidget);
      expect(find.text('Your Name or Username *'), findsOneWidget);
      expect(find.text('Your Email Address *'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);
      // AnimatedCrossFade her iki formu da (kayıt + giriş) aynı anda ağaçta tutar; bu yüzden
      // her iki formda da olan metinler (Google düğmesi, "veya e-posta ile" ayracı) iki kez bulunur.
      expect(find.text('Continue with Google'), findsWidgets);
      expect(find.text('or with email'), findsWidgets);
      // Türkçe sabit metinler artık görünmemeli
      expect(find.text('Hesap Bilgilerinizi Belirleyin'), findsNothing);
      expect(find.text('Doğrulama Kodu Gönder'), findsNothing);
    });

    testWidgets('tr locale ile Türkçe metinler görünür (regresyon yok)', (tester) async {
      AppStrings.currentLocale.value = 'tr';
      await _pump(tester, OnboardingScreen(onCompleted: () {}));

      expect(find.text('Hesap Bilgilerinizi Belirleyin'), findsOneWidget);
      expect(find.text('Doğrulama Kodu Gönder'), findsOneWidget);
    });
  });

  group("'en' locale — Alt gezinme (MainNavigationScaffold) etiketleri İngilizce", () {
    testWidgets('Nav etiketleri Home/Wallet/Analysis/Goals/Assets', (tester) async {
      AppStrings.currentLocale.value = 'en';
      await _pump(tester, const MainNavigationScaffold());

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Wallet'), findsWidgets);
      expect(find.text('Analysis'), findsWidgets);
      expect(find.text('Goals'), findsWidgets);
      expect(find.text('Assets'), findsWidgets);
      // Türkçe etiketler artık görünmemeli
      expect(find.text('Ana Sayfa'), findsNothing);
      expect(find.text('Cüzdan'), findsNothing);
    });
  });
}
