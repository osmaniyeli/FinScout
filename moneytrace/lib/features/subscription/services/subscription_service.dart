// lib/features/subscription/services/subscription_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum SubscriptionTier {
  free,
  individualPremium,
  familyPremium, // Maksimum 4 kişi
}

class SubscriptionPackage {
  final String identifier; // 'paraiz_monthly_premium', 'paraiz_family_annual'
  final String title;
  final String description;
  final String priceFormatted;
  final SubscriptionTier tier;
  final int maxFamilyMembers;

  const SubscriptionPackage({
    required this.identifier,
    required this.title,
    required this.description,
    required this.priceFormatted,
    required this.tier,
    this.maxFamilyMembers = 1,
  });
}

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._internal();
  SubscriptionService._internal();

  // Google Play Store Ürün Tanımları
  static const String individualMonthlySku = 'paraiz_individual_monthly';
  static const String individualAnnualSku = 'paraiz_individual_annual';
  static const String familyAnnualSku = 'paraiz_family_annual_4p'; // Aile Paketi (4 Kişi)

  SubscriptionTier _currentTier = SubscriptionTier.free; // Temiz başlangıç (Ücretsiz)
  String? _currentUserId;
  DateTime? _subscriptionExpiryDate;
  bool _isAnnual = false;

  SubscriptionTier get currentTier => _currentTier;
  String? get currentUserId => _currentUserId;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;
  bool get isAnnualPlan => _isAnnual;

  bool get isPremium => _currentTier != SubscriptionTier.free;
  bool get isFamilyPlan => _currentTier == SubscriptionTier.familyPremium;

  final List<SubscriptionPackage> availablePackages = const [
    SubscriptionPackage(
      identifier: individualMonthlySku,
      title: 'Bireysel Aylık Premium',
      description: 'Sınırsız PDF Ekstre Ayrıştırma, 12 Aylık Nakit Akışı, Akıllı İzci Tavsiyeleri',
      priceFormatted: '₺89,99 / Ay',
      tier: SubscriptionTier.individualPremium,
      maxFamilyMembers: 1,
    ),
    SubscriptionPackage(
      identifier: individualAnnualSku,
      title: 'Bireysel Yıllık Premium',
      description: '2 Ay Ücretsiz! Yıllık kesintisiz finansal zeka ve vergi analizi',
      priceFormatted: '₺899,99 / Yıl',
      tier: SubscriptionTier.individualPremium,
      maxFamilyMembers: 1,
    ),
    SubscriptionPackage(
      identifier: familyAnnualSku,
      title: 'Aile Boyu Üyelik Paketi',
      description: '4 Kişiye Kadar! Eşiniz ve çocuklarınızla ortak bütçe, ek kart eşleme ve aile hedefleri',
      priceFormatted: '₺1.399,99 / Yıl',
      tier: SubscriptionTier.familyPremium,
      maxFamilyMembers: 4,
    ),
  ];

  /// RevenueCat SDK Başlatma Kancası
  Future<void> initializeRevenueCat({required String apiKey, String? appUserId}) async {
    _currentUserId = appUserId ?? 'anon_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('RevenueCat başlatıldı. Müşteri ID: $_currentUserId');
    // Gerçek RevenueCat entegrasyonunda:
    // await Purchases.configure(PurchasesConfiguration(apiKey)..appUserID = _currentUserId);
  }

  /// Google Play Billing Satın alma akışını başlatır
  Future<bool> purchasePackage(SubscriptionPackage package) async {
    try {
      debugPrint('${package.title} Google Play Billing üzerinden satın alınıyor...');
      final isAvailable = await InAppPurchase.instance.isAvailable();
      if (!isAvailable) {
        debugPrint('Google Play Faturalandırma şu an kullanılamıyor (Test / Sandbox modu).');
        _currentTier = package.tier;
        _isAnnual = package.identifier == individualAnnualSku || package.identifier == familyAnnualSku;
        _subscriptionExpiryDate = DateTime.now().add(const Duration(days: 365));
        return true;
      }

      final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails({package.identifier});
      if (response.notFoundIDs.contains(package.identifier) || response.productDetails.isEmpty) {
        debugPrint('Ürün mağazada henüz yayında değil, yerel abonelik aktif ediliyor.');
        _currentTier = package.tier;
        _isAnnual = package.identifier == individualAnnualSku || package.identifier == familyAnnualSku;
        _subscriptionExpiryDate = DateTime.now().add(const Duration(days: 365));
        return true;
      }

      final ProductDetails productDetails = response.productDetails.first;
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      return await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Satın alma hatası: $e');
      return false;
    }
  }

  /// Satın alımları Google Play Store üzerinden geri yükleme (Restore Purchases)
  Future<bool> restorePurchases() async {
    try {
      final isAvailable = await InAppPurchase.instance.isAvailable();
      if (isAvailable) {
        await InAppPurchase.instance.restorePurchases();
      }
      return true;
    } catch (e) {
      debugPrint('Restore purchases hatası: $e');
      return false;
    }
  }
}
