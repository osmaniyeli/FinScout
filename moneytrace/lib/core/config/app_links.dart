import 'package:url_launcher/url_launcher.dart';

/// Uygulama içinden açılan dış bağlantılar (Play abonelik politikası ve kullanıcı verileri politikası
/// bu bağlantıların uygulama içinde bulunmasını istiyor).
class AppLinks {
  AppLinks._();

  static const String packageName = 'com.moneytrace.app';
  static const String privacyPolicy = 'https://github.com/osmaniyeli/FinScout/blob/main/PRIVACY_POLICY.md';
  static const String dataDeletion = 'https://github.com/osmaniyeli/FinScout/blob/main/DATA_DELETION.md';

  /// Play Store'daki abonelik yönetimi (iptal, ödeme yöntemi). SKU verilirse doğrudan o aboneliği açar.
  static String manageSubscriptions([String? sku]) => sku == null
      ? 'https://play.google.com/store/account/subscriptions?package=$packageName'
      : 'https://play.google.com/store/account/subscriptions?sku=$sku&package=$packageName';

  static Future<bool> open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
