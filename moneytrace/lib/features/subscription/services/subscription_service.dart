// lib/features/subscription/services/subscription_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

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

  // RevenueCat / App Store Ürün Tanımları
  static const String individualMonthlySku = 'paraiz_individual_monthly';
  static const String individualAnnualSku = 'paraiz_individual_annual';
  static const String familyAnnualSku = 'paraiz_family_annual_4p'; // Aile Paketi (4 Kişi)

  SubscriptionTier _currentTier = SubscriptionTier.individualPremium; // Demo amaçlı aktif
  String? _currentUserId = 'usr_ahmet_aydin';
  DateTime? _subscriptionExpiryDate = DateTime.now().add(const Duration(days: 300));

  SubscriptionTier get currentTier => _currentTier;
  String? get currentUserId => _currentUserId;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;

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

  /// Satın alma akışını simüle eder / başlatır
  Future<bool> purchasePackage(SubscriptionPackage package) async {
    try {
      debugPrint('${package.title} satın alınıyor...');
      // Başarılı satın alma sonrası yerel durumu güncelle
      _currentTier = package.tier;
      _subscriptionExpiryDate = DateTime.now().add(const Duration(days: 365));
      return true;
    } catch (e) {
      debugPrint('Satın alma hatası: $e');
      return false;
    }
  }

  /// Satın alımları geri yükleme (Restore Purchases)
  Future<bool> restorePurchases() async {
    debugPrint('Satın alımlar mağazadan kontrol ediliyor...');
    return true;
  }
}
