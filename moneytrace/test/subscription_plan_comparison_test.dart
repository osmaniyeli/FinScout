// test/subscription_plan_comparison_test.dart
//
// Görev 1 (plan karşılaştırma tablosu) ve Görev 2 (kupon → Play yönlendirmesi) için testler.
// Karşılaştırma tablosundaki rakamlar UserProfileService.checkUploadQuota ve
// SubscriptionService.availablePackages ile birebir aynı olmalı (bkz. subscription_plans_sheet.dart
// _buildPlanComparison). Kupon alanı kodu KENDİSİ doğrulamaz; yalnız Google Play'in resmi kod
// kullanma sayfasına doğru URL ile yönlendirir (bkz. AppLinks.redeemPromoCode).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneytrace/core/config/app_links.dart';
import 'package:moneytrace/features/subscription/presentation/subscription_plans_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLinks.redeemPromoCode — Play kod kullanma URL şeması', () {
    test('Basit kod için resmi Play redeem URL\'ini üretir', () {
      expect(
        AppLinks.redeemPromoCode('ABC123'),
        'https://play.google.com/redeem?code=ABC123',
      );
    });

    test('Özel karakterleri URL-encode eder (boşluk, +, /)', () {
      expect(
        AppLinks.redeemPromoCode('AB C+D/E'),
        'https://play.google.com/redeem?code=AB%20C%2BD%2FE',
      );
    });

    test('Baştaki/sondaki boşluğu kırpar', () {
      expect(
        AppLinks.redeemPromoCode('  XYZ  '),
        'https://play.google.com/redeem?code=XYZ',
      );
    });
  });

  group('SubscriptionPlansSheet — "Planlar arasında ne değişir?" tablosu', () {
    testWidgets('Ücretsiz/Bireysel/Aile için GERÇEK kota rakamlarını gösterir', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SubscriptionPlansSheet()),
      ));
      await tester.pump();

      expect(find.text('Planlar arasında ne değişir?'), findsOneWidget);

      // Ücretsiz: 1 kart + 1 hesap ekstresi (UserProfileService.checkUploadQuota — tier == free)
      expect(find.text('1 kart +\n1 hesap'), findsOneWidget);
      // Bireysel: aylık 3, yıllık 5 belge (aynı fonksiyon — isAnnual ? 5 : 3)
      expect(find.text('3-5 belge*'), findsOneWidget);
      // Aile: 12 belge = 5 kart + 5 hesap + 2 bordro
      expect(find.text('12 belge**'), findsOneWidget);
      expect(find.textContaining('5 kart + 5 hesap + 2 bordro'), findsOneWidget);

      // Hedefler ücretsizde kilitli, diğer planlarda açık
      expect(find.text('🔒 Kilitli'), findsOneWidget);
      expect(find.text('✓ Açık'), findsNWidgets(2));

      // Bordro ücretsizde hiç desteklenmiyor
      expect(find.text('✕'), findsOneWidget);
    });
  });

  group('SubscriptionPlansSheet — "Kuponun mu var?" alanı', () {
    testWidgets('Kod boşken "Uygula" pasif, kod girilince aktif olur; yanlış izlenim vermez',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SubscriptionPlansSheet()),
      ));
      await tester.pump();

      expect(find.text('Kuponun mu var?'), findsOneWidget);
      // Kodun uygulama içinde doğrulandığı YANLIŞ izlenimi verilmemeli — Play'e yönlendirildiği açık.
      expect(find.text('Kod, Google Play üzerinden uygulanır.'), findsOneWidget);

      final applyFinder = find.widgetWithText(OutlinedButton, 'Uygula');
      expect(applyFinder, findsOneWidget);
      expect(tester.widget<OutlinedButton>(applyFinder).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'TEST2026');
      await tester.pump();

      expect(tester.widget<OutlinedButton>(applyFinder).onPressed, isNotNull);
    });
  });
}
