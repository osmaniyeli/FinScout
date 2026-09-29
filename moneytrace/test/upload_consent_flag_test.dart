// test/upload_consent_flag_test.dart
//
// Görev 3 — ilk yüklemede tek seferlik onay: StatementUploadSheet._ensureUploadConsent yalnız
// UserProfileService.hasAcceptedUploadConsent false iken diyaloğu gösterir; onaylanınca bayrak
// UserProfile.toMap/fromMap ile aynı dosyaya kalıcı yazılır (bkz. UserProfileService._persist) ve
// bir daha sorulmaz. Bu test gerçek dosya I/O ile "uygulama yeniden başlasa bile sorulmaz"
// davranışını doğrudan doğrular (bkz. free_tier_bank_lock_test.dart ile aynı desen).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:moneytrace/core/services/user_profile_service.dart';

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
    tempDir = await Directory.systemTemp.createTemp('finscout_upload_consent_test_');
    PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Windows'ta dosya tanıtıcısı hemen serbest kalmayabilir; testi bozmasın.
    }
  });

  group('UserProfileService.hasAcceptedUploadConsent — ilk yükleme onay bayrağı', () {
    test('Yeni profilde varsayılan false: ilk yüklemede onay gösterilmeli', () async {
      await UserProfileService.instance.saveProfile(UserProfile(
        id: 'test_user',
        name: 'Test User',
        joinedAt: DateTime.now(),
      ));

      expect(UserProfileService.instance.hasAcceptedUploadConsent, isFalse);
    });

    test('markUploadConsentAccepted sonrası true olur ve diske kalıcı yazılır', () async {
      await UserProfileService.instance.saveProfile(UserProfile(
        id: 'test_user',
        name: 'Test User',
        joinedAt: DateTime.now(),
      ));
      expect(UserProfileService.instance.hasAcceptedUploadConsent, isFalse);

      await UserProfileService.instance.markUploadConsentAccepted();

      expect(UserProfileService.instance.hasAcceptedUploadConsent, isTrue);

      // "Uygulama yeniden başlasa bile bir daha sorulmaz": bayrağın gerçekten diskte kalıcı
      // olduğunu, bellekteki alanı değil, dosyanın kendisini okuyarak doğrula.
      final file = File('${tempDir.path}/paraiz_user_profile.json');
      expect(await file.exists(), isTrue);
      final raw = await file.readAsString();
      expect(raw, contains('"hasAcceptedUploadConsent":true'));
    });

    test('setLockedInstitution gibi diğer alanları güncellerken onay bayrağını bozmaz', () async {
      await UserProfileService.instance.saveProfile(UserProfile(
        id: 'test_user',
        name: 'Test User',
        joinedAt: DateTime.now(),
      ));
      await UserProfileService.instance.markUploadConsentAccepted();
      expect(UserProfileService.instance.hasAcceptedUploadConsent, isTrue);

      await UserProfileService.instance.setLockedInstitution('Yapı Kredi');

      expect(UserProfileService.instance.hasAcceptedUploadConsent, isTrue);
      expect(UserProfileService.instance.profile?.lockedInstitution, 'Yapı Kredi');
    });
  });

  group('UserProfile.toMap / fromMap — hasAcceptedUploadConsent taşınması', () {
    test('true değeri round-trip\'te korunur', () {
      final original = UserProfile(
        id: 'u1',
        name: 'A',
        joinedAt: DateTime(2026, 1, 1),
        hasAcceptedUploadConsent: true,
      );
      final restored = UserProfile.fromMap(original.toMap());
      expect(restored.hasAcceptedUploadConsent, isTrue);
    });

    test('Alan hiç yoksa (eski kayıtlar) varsayılan false döner', () {
      final legacyMap = {
        'id': 'u2',
        'name': 'B',
        'joinedAt': DateTime(2026, 1, 1).toIso8601String(),
      };
      expect(UserProfile.fromMap(legacyMap).hasAcceptedUploadConsent, isFalse);
    });
  });
}
