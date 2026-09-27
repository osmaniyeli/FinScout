// test/pin_system_keyboard_test.dart
//
// PIN ekranlarının artık uygulamaya özel dairesel tuş takımı yerine telefonun sistem
// klavyesini (TextField) kullandığını doğrular (2026-09-28). Gerçek kullanıcı PIN'i
// yerine yalnız bu testte kullanılan sahte/test bir PIN ('1234') ile
// SecurityAuthService.instance.setPin(...) çağrılır — üretim/servis mantığına
// (verifyPin, isLockedOut, failedAttempts) dokunulmaz, aynen kullanılır.
//
// compute() ile PBKDF2 hash'i gerçek bir isolate'te hesaplandığı için testler
// tester.runAsync(...) içinde çalıştırılır (Flutter'ın önerdiği desen: compute/gerçek
// async kullanan kodu widget test içinde beklemek için).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/services/security_auth_service.dart';
import 'package:moneytrace/core/widgets/fintech/app_lock_screen.dart';
import 'package:moneytrace/core/widgets/fintech/security_auth_sheet.dart';

const _testPin = '1234';

/// verifyPin()/setPin() içindeki compute() (gerçek isolate) tamamlanana kadar
/// kısa aralıklarla pump'lar; sabit bir gecikmeye güvenmek yerine koşul
/// gerçekleşince hemen döner (yavaş makinelerde flaky olmasın diye).
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition() && stopwatch.elapsed < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockScreen (sistem klavyesi)', () {
    testWidgets('yalnız bir TextField var; eski dairesel tuş takımı yok', (tester) async {
      await tester.runAsync(() async {
        await SecurityAuthService.instance.setPin(_testPin);
      });

      await tester.pumpWidget(MaterialApp(
        home: AppLockScreen(onUnlocked: () {}),
      ));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('4 hane doğru PIN girilince onUnlocked tetiklenir', (tester) async {
      var unlocked = false;

      await tester.runAsync(() async {
        await SecurityAuthService.instance.setPin(_testPin);

        await tester.pumpWidget(MaterialApp(
          home: AppLockScreen(onUnlocked: () => unlocked = true),
        ));
        await tester.pump();

        final field = find.byType(TextField);
        await tester.tap(field);
        await tester.pump();
        await tester.enterText(field, _testPin);
        await tester.pump();
        // verifyPin() compute() isolate'inin dönmesini bekle
        await _pumpUntil(tester, () => unlocked);
      });

      expect(unlocked, isTrue);
    });

    testWidgets('4 hane yanlış PIN girilince alan temizlenir ve hata metni gösterilir', (tester) async {
      await tester.runAsync(() async {
        await SecurityAuthService.instance.setPin(_testPin);

        await tester.pumpWidget(MaterialApp(
          home: AppLockScreen(onUnlocked: () {}),
        ));
        await tester.pump();

        final field = find.byType(TextField);
        await tester.tap(field);
        await tester.pump();
        await tester.enterText(field, '0000');
        await tester.pump();
        await _pumpUntil(tester, () => field.evaluate().isNotEmpty &&
            tester.widget<TextField>(field).controller!.text.isEmpty);
      });

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
      expect(find.textContaining('Hatalı PIN kodu'), findsOneWidget);
    });
  });

  group('SecurityAuthSheet (sistem klavyesi)', () {
    testWidgets('yalnız bir TextField var; eski dairesel tuş takımı yok', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SecurityAuthSheet(
            onPinEntered: (_) {},
            onSuccess: () {},
          ),
        ),
      ));
      await tester.pump();

      // Eski tasarımda her rakam InkWell tabanlı özel bir tuştu (12 tuş).
      // Şimdi tek bir TextField var; kalan InkWell yalnız "İptal" TextButton'ının
      // Material altyapısından gelir (Material widget'larının doğal parçası).
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(InkWell), findsWidgets);
      expect(find.byType(InkWell).evaluate().length, lessThanOrEqualTo(1));
    });

    testWidgets('yeni PIN belirlerken 4 hane girilince onPinEntered ve onSuccess tetiklenir', (tester) async {
      String? capturedPin;
      var succeeded = false;

      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SecurityAuthSheet(
              isSettingNewPin: true,
              onPinEntered: (p) => capturedPin = p,
              onSuccess: () => succeeded = true,
            ),
          ),
        ));
        await tester.pump();

        final field = find.byType(TextField);
        await tester.tap(field);
        await tester.pump();
        await tester.enterText(field, '5678');
        await tester.pump();
        await _pumpUntil(tester, () => succeeded);
      });

      expect(capturedPin, '5678');
      expect(succeeded, isTrue);
    });

    testWidgets('mevcut PIN doğrulamasında yanlış PIN girilince alan temizlenir', (tester) async {
      await tester.runAsync(() async {
        await SecurityAuthService.instance.setPin(_testPin);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SecurityAuthSheet(
              onPinEntered: (_) {},
              onSuccess: () {},
            ),
          ),
        ));
        await tester.pump();

        final field = find.byType(TextField);
        await tester.tap(field);
        await tester.pump();
        await tester.enterText(field, '0000');
        await tester.pump();
        await _pumpUntil(tester, () => field.evaluate().isNotEmpty &&
            tester.widget<TextField>(field).controller!.text.isEmpty);
      });

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
      expect(find.textContaining('Hatalı PIN kodu'), findsOneWidget);
    });
  });
}
