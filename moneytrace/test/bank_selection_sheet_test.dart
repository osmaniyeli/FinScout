// test/bank_selection_sheet_test.dart
//
// BankSelectionSheet: aktif bankalardan (Yapı Kredi / Garanti BBVA / Enpara) birine dokununca
// UserProfileService.setLockedInstitution çağrılıp sheet kapanır; pasif İş Bankası satırına
// dokununca seçilmez, yalnız bir SnackBar gösterilir ve sheet açık kalır.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:moneytrace/core/services/user_profile_service.dart';
import 'package:moneytrace/core/widgets/fintech/bank_selection_sheet.dart';

class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// setLockedInstitution gerçek dosya I/O'su (_persist) yapar; bu widget testinde sahte saat değil
/// gerçek zaman geçmesi gerekir (bkz. test/pin_system_keyboard_test.dart _pumpUntil ile aynı desen).
/// Sabit bir gecikmeye güvenmek yerine koşul gerçekleşince hemen döner.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition() && stopwatch.elapsed < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump();
  }
}

Future<void> _openSheet(WidgetTester tester, {bool allowSkip = true}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => BankSelectionSheet.show(context, allowSkip: allowSkip),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finscout_bank_sheet_test_');
    PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
    await UserProfileService.instance.saveProfile(UserProfile(
      id: 'test_user',
      name: 'Test User',
      joinedAt: DateTime.now(),
    ));
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('İş Bankası satırına dokununca seçilmez, "yakında hazır değil" SnackBar\'ı çıkar',
      (tester) async {
    await _openSheet(tester);

    expect(find.text('İş Bankası'), findsOneWidget);
    await tester.tap(find.text('İş Bankası'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('İş Bankası okuyucusu henüz hazır değil'), findsOneWidget);
    // Kilitlenmedi, sheet hâlâ açık.
    expect(UserProfileService.instance.profile?.lockedInstitution, isNull);
    expect(find.byType(BankSelectionSheet), findsOneWidget);
  });

  testWidgets('Aktif bir bankaya (Yapı Kredi) dokununca kilitlenir ve sheet kapanır', (tester) async {
    await _openSheet(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Yapı Kredi'));
      await tester.pump();
      // _profile alanı setLockedInstitution içinde _persist() (gerçek dosya I/O) ÖNCESİNDE
      // güncellenir; kilit değeri değil, Navigator.pop sonrası sheet'in kalkmasını bekle.
      await _pumpUntil(tester, () => find.byType(BankSelectionSheet).evaluate().isEmpty);
    });
    await tester.pumpAndSettle();

    expect(UserProfileService.instance.profile?.lockedInstitution, 'Yapı Kredi');
    expect(find.byType(BankSelectionSheet), findsNothing);
  });

  testWidgets('allowSkip=true iken "Şimdi değil" kilitlemeden sheet\'i kapatır', (tester) async {
    await _openSheet(tester, allowSkip: true);

    expect(find.text('Şimdi değil'), findsOneWidget);
    await tester.tap(find.text('Şimdi değil'));
    await tester.pumpAndSettle();

    expect(UserProfileService.instance.profile?.lockedInstitution, isNull);
    expect(find.byType(BankSelectionSheet), findsNothing);
  });

  testWidgets('allowSkip=false iken "Şimdi değil" butonu gösterilmez (Ayarlar akışı)', (tester) async {
    await _openSheet(tester, allowSkip: false);

    expect(find.text('Şimdi değil'), findsNothing);
  });
}
