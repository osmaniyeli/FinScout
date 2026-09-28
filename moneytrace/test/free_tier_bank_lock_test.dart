// test/free_tier_bank_lock_test.dart
//
// Ücretsiz planda tek banka kilidi: statement_upload_sheet._prepareDocument, orkestratörden dönen
// docResult HEMEN SONRA UserProfileService.checkFreeTierBankLock'u çağırır. Gerçek bir PDF/FilePicker
// akışına girmeden bu kontrolü doğrudan test eder (StatementDocumentResult.institution ile aynı
// sözleşmeyi paylaşan düz string'ler kullanılır — bkz. statement_orchestrator._displayName:
// 'Yapı Kredi' / 'Garanti BBVA' / 'Enpara').

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:moneytrace/core/services/user_profile_service.dart';
import 'package:moneytrace/features/subscription/services/subscription_service.dart';

class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finscout_bank_lock_test_');
    PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
    SubscriptionService.instance.serverPeriod = null;
    SubscriptionService.instance.serverUsage = const {};
    await UserProfileService.instance.saveProfile(UserProfile(
      id: 'test_user',
      name: 'Test User',
      joinedAt: DateTime.now(),
    ));
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Windows'ta dosya tanıtıcısı hemen serbest kalmayabilir; testi bozmasın.
    }
  });

  group('UserProfileService.checkFreeTierBankLock — ücretsiz plan tek banka kilidi', () {
    test('Banka hiç seçilmemişken ilk belge sessizce o bankaya kilitler', () async {
      final error = await UserProfileService.instance.checkFreeTierBankLock('Yapı Kredi');
      expect(error, isNull);
      expect(UserProfileService.instance.profile?.lockedInstitution, 'Yapı Kredi');
    });

    test('Kilitli bankayla aynı kurumdan gelen belge kabul edilir (hata yok)', () async {
      await UserProfileService.instance.setLockedInstitution('Garanti BBVA');

      final error = await UserProfileService.instance.checkFreeTierBankLock('Garanti BBVA');

      expect(error, isNull);
      expect(UserProfileService.instance.profile?.lockedInstitution, 'Garanti BBVA');
    });

    test('Kilitli bankadan FARKLI kurumdan gelen belge reddedilir, kilit değişmez', () async {
      await UserProfileService.instance.setLockedInstitution('Yapı Kredi');

      final error = await UserProfileService.instance.checkFreeTierBankLock('Enpara');

      expect(error, isNotNull);
      expect(error, contains('Yapı Kredi'));
      // Kilit hâlâ ilk bankada: uyuşmayan belge kilidi DEĞİŞTİRMEZ, yalnız reddedilir.
      expect(UserProfileService.instance.profile?.lockedInstitution, 'Yapı Kredi');
    });
  });
}
