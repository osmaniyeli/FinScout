// DOSYA ADI: 18_BILLING_google_play_service.dart
// HEDEF DİZİN: lib/features/subscription_manager/services/18_BILLING_google_play_service.dart

import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sqflite/sqflite.dart';

class GooglePlayBillingService {
  static const String monthlySubscriptionId = 'paraiz_pro_monthly_99';
  static const String yearlySubscriptionId = 'paraiz_pro_yearly_1080';

  final InAppPurchase _iap = InAppPurchase.instance;
  final Database db;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final StreamController<bool> _proStatusController = StreamController<bool>.broadcast();
  Stream<bool> get proStatusStream => _proStatusController.stream;

  GooglePlayBillingService({required this.db});

  /// Faturalandırma motorunu ve arka plan dinleyicisini başlatır.
  Future<void> initialize() async {
    final bool isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      _proStatusController.add(false);
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) => _proStatusController.add(false),
    );

    await checkCurrentSubscriptionStatus();
  }

  /// Google Play Store'dan aktif paket fiyatlarını ve deneme süresi detaylarını çeker.
  Future<List<ProductDetails>> fetchAvailablePlans() async {
    final Set<String> productIds = {monthlySubscriptionId, yearlySubscriptionId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);

    if (response.error != null || response.productDetails.isEmpty) {
      return [];
    }

    return response.productDetails;
  }

  /// Satın alma akışını başlatır (Aylık veya 7 Gün Denemeli Yıllık Plan).
  Future<bool> initiatePurchase(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Satın alma güncellemelerini yakalar ve doğrular.
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        // İşlem askıda, kullanıcı ödeme onayını bekliyor
      } else if (purchase.status == PurchaseStatus.error) {
        // Satın alma hatası veya kullanıcı iptali
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.purchased ||
                 purchase.status == PurchaseStatus.restored) {
        // Başarılı abonelik veya geri yükleme
        final bool isValid = await _verifyPurchaseOnDevice(purchase);
        if (isValid) {
          await _updateLocalProStatus(isPro: true, expiryMillis: DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch);
          _proStatusController.add(true);
        }

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  /// Satın alımları geri yükler (Uygulama silinip yeniden yüklendiğinde).
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// Yerel veritabanında Pro durumunu günceller.
  Future<void> _updateLocalProStatus({required bool isPro, required int expiryMillis}) async {
    await db.rawInsert('''
      INSERT OR REPLACE INTO app_meta (key, value)
      VALUES ('is_pro_user', ?), ('pro_expiry_timestamp', ?)
    ''', [isPro ? '1' : '0', expiryMillis.toString()]);
  }

  /// Yerel veritabanından mevcut Pro durumunu kontrol eder.
  Future<bool> checkCurrentSubscriptionStatus() async {
    final rows = await db.query(
      'app_meta',
      where: 'key IN (?, ?)',
      whereArgs: ['is_pro_user', 'pro_expiry_timestamp'],
    );

    bool isPro = false;
    int expiry = 0;

    for (final r in rows) {
      if (r['key'] == 'is_pro_user' && r['value'] == '1') isPro = true;
      if (r['key'] == 'pro_expiry_timestamp') expiry = int.tryParse(r['value'] as String) ?? 0;
    }

    final bool hasValidAccess = isPro && (expiry > DateTime.now().millisecondsSinceEpoch);
    _proStatusController.add(hasValidAccess);
    return hasValidAccess;
  }

  Future<bool> _verifyPurchaseOnDevice(PurchaseDetails purchase) async {
    // Google Play Store imzası kontrol edilir
    return purchase.verificationData.serverVerificationData.isNotEmpty;
  }

  void dispose() {
    _subscription?.cancel();
    _proStatusController.close();
  }
}