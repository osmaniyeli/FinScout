import 'package:url_launcher/url_launcher.dart';

/// Uygulama içinden açılan dış bağlantılar (Play abonelik politikası ve kullanıcı verileri politikası
/// bu bağlantıların uygulama içinde bulunmasını istiyor).
class AppLinks {
  AppLinks._();

  static const String packageName = 'com.moneytrace.app';
  static const String privacyPolicy = 'https://github.com/osmaniyeli/FinScout/blob/main/PRIVACY_POLICY.md';
  static const String dataDeletion = 'https://github.com/osmaniyeli/FinScout/blob/main/DATA_DELETION.md';
  static const String termsOfService = 'https://osmaniyeli.github.io/FinScout/kullanim-sartlari.html';

  /// Play Store'daki abonelik yönetimi (iptal, ödeme yöntemi). SKU verilirse doğrudan o aboneliği açar.
  static String manageSubscriptions([String? sku]) => sku == null
      ? 'https://play.google.com/store/account/subscriptions?package=$packageName'
      : 'https://play.google.com/store/account/subscriptions?sku=$sku&package=$packageName';

  /// Google Play'in resmi promosyon kodu kullanma sayfası. Abonelik indirimleri Play Billing
  /// politikası gereği yalnız Play Console üzerinden (promosyon kodu / tanıtım fiyatı) yönetilebilir;
  /// FinScout kodu KENDİSİ doğrulamaz, kullanıcıyı Play'e yönlendirir — doğrulama orada yapılır.
  /// bkz. https://support.google.com/googleplay/answer/2649487 (promosyon kodu kullanma bağlantısı).
  static String redeemPromoCode(String code) =>
      'https://play.google.com/redeem?code=${Uri.encodeComponent(code.trim())}';

  static Future<bool> open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
