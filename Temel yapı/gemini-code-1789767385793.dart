// DOSYA ADI: 11_SUBSCRIPTION_quota_enforcer.dart
// HEDEF DİZİN: lib/features/subscription_manager/services/11_SUBSCRIPTION_quota_enforcer.dart

class QuotaExceededException implements Exception {
  final String message;
  final int currentMonthUploads;
  final int maxAllowedUploads;

  QuotaExceededException({
    required this.message,
    required this.currentMonthUploads,
    required this.maxAllowedUploads,
  });

  @override
  String toString() => message;
}

class QuotaEnforcer {
  static const int freeTierMonthlyLimit = 1;

  /// Kullanıcının yeni bir ekstre veya bordro yükleme yetkisini doğrular.
  static void verifyUploadEligibility({
    required bool isProUser,
    required int uploadsThisMonth,
  }) {
    if (isProUser) {
      return; // Pro kullanıcılar sınırsız yükleme hakkına sahiptir
    }

    if (uploadsThisMonth >= freeTierMonthlyLimit) {
      throw QuotaExceededException(
        message: 'Bu ayki 1 adet ücretsiz ekstre analiz hakkını kullandın. '
                 'Sınırsız analiz ve vergi takibi için Paraİz Pro\'ya geç.',
        currentMonthUploads: uploadsThisMonth,
        maxAllowedUploads: freeTierMonthlyLimit,
      );
    }
  }
}