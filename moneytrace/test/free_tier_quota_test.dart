// test/free_tier_quota_test.dart
//
// Yeni ücretsiz plan modeli: ayda 1 kredi kartı + 1 hesap ekstresi (tür bazlı, aile paketindeki
// desenin küçültülmüş hali); bordro ücretsiz planda hiç desteklenmez. Bu test yalnız istemcideki
// ÖN KONTROLÜ (UserProfileService.checkUploadQuota) hedefler — asıl atomik düşüm sunucuda
// (consume_upload RPC) yapılır ve bu testin kapsamı dışındadır (bkz. supabase/migrations/
// 20260928120000_free_tier_type_quota.sql).

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/services/user_profile_service.dart';
import 'package:moneytrace/features/subscription/services/subscription_service.dart';

void main() {
  final now = DateTime.now();
  final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  setUp(() {
    // SubscriptionService.instance._currentTier varsayılanı zaten 'free'; testte değiştirilmiyor.
    SubscriptionService.instance.serverPeriod = monthKey;
    SubscriptionService.instance.serverUsage = const {};
  });

  group('UserProfileService.checkUploadQuota — ücretsiz plan (1 kredi kartı + 1 hesap ekstresi)', () {
    test('Hiç yükleme yokken hem kart hem hesap ekstresi yüklenebilir', () {
      expect(
        UserProfileService.instance.checkUploadQuota(documentTypeHint: 'CREDIT_CARD').canUpload,
        isTrue,
      );
      expect(
        UserProfileService.instance.checkUploadQuota(documentTypeHint: 'CHECKING').canUpload,
        isTrue,
      );
    });

    test('1 kredi kartı kullanıldıktan sonra ikinci kart reddedilir, hesap ekstresi hâlâ serbest', () {
      SubscriptionService.instance.serverUsage = const {'credit_card': 1};

      final card = UserProfileService.instance.checkUploadQuota(documentTypeHint: 'CREDIT_CARD');
      expect(card.canUpload, isFalse);

      final checking = UserProfileService.instance.checkUploadQuota(documentTypeHint: 'CHECKING');
      expect(checking.canUpload, isTrue);
    });

    test('1 kart + 1 ekstre kullanıldıktan sonra üçüncü belge (tür farketmeksizin) reddedilir', () {
      SubscriptionService.instance.serverUsage = const {'credit_card': 1, 'checking': 1};

      expect(
        UserProfileService.instance.checkUploadQuota(documentTypeHint: 'CREDIT_CARD').canUpload,
        isFalse,
      );
      expect(
        UserProfileService.instance.checkUploadQuota(documentTypeHint: 'CHECKING').canUpload,
        isFalse,
      );
    });

    test('Bordro ücretsiz planda kota boşken bile her zaman reddedilir', () {
      final result = UserProfileService.instance.checkUploadQuota(documentTypeHint: 'PAYSLIP');
      expect(result.canUpload, isFalse);
      expect(result.reason, contains('Bordro ücretsiz planda desteklenmiyor'));
    });
  });
}
