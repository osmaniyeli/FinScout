import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum SubscriptionTier {
  free,
  individualPremium,
  familyPremium, // Maksimum 4 kişi
}

class SubscriptionPackage {
  final String
      identifier; // 'finscout_individual_monthly', 'finscout_individual_annual', 'finscout_family_annual_4p'
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
  static const String individualMonthlySku = 'finscout_individual_monthly';
  static const String individualAnnualSku = 'finscout_individual_annual';
  static const String familyAnnualSku =
      'finscout_family_annual_4p'; // Aile Paketi (4 Kişi)

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isInitialized = false;

  /// Mağaza doğrulaması sırasında aktif bir satın alma görüldü mü
  bool _sawActivePurchase = false;

  /// Google'ın bildirdiği şu an aktif abonelik satın alması (plan değişikliğinde eskisini değiştirmek için)
  PurchaseDetails? _activePurchase;
  Completer<void>? _restoreCompleter;

  SubscriptionTier _currentTier = SubscriptionTier.free;
  bool _isAnnual = false;
  String? lastError;

  SubscriptionTier get currentTier => _currentTier;
  bool get isAnnualPlan => _isAnnual;
  bool get isPremium => _currentTier != SubscriptionTier.free;
  bool get isFamilyPlan => _currentTier == SubscriptionTier.familyPremium;

  final ValueNotifier<SubscriptionTier> tierNotifier =
      ValueNotifier<SubscriptionTier>(SubscriptionTier.free);
  final ValueNotifier<bool> isPurchasingNotifier = ValueNotifier<bool>(false);
  final Map<String, ProductDetails> products = {};

  /// Kullanıcının uygun olduğu ücretsiz deneme teklifleri (ör. yıllık planda 7 gün).
  /// Play yalnızca uygun kullanıcıya döndürür; fiyat gösterimi yine ana plandan yapılır.
  final Map<String, ProductDetails> trialOffers = {};
  bool hasTrial(String sku) => trialOffers.containsKey(sku);

  final List<SubscriptionPackage> availablePackages = const [
    SubscriptionPackage(
      identifier: individualMonthlySku,
      title: 'Bireysel Aylık Premium',
      description: 'Ayda 3 belge: kart ekstresi, hesap ekstresi ve bordro',
      priceFormatted: '₺79,99 / Ay',
      tier: SubscriptionTier.individualPremium,
      maxFamilyMembers: 1,
    ),
    SubscriptionPackage(
      identifier: individualAnnualSku,
      title: 'Bireysel Yıllık Premium',
      description: 'Ayda 5 belge; aylık plana göre %37 daha uygun',
      priceFormatted: '₺599,99 / Yıl',
      tier: SubscriptionTier.individualPremium,
      maxFamilyMembers: 1,
    ),
    SubscriptionPackage(
      identifier: familyAnnualSku,
      title: 'Aile Boyu Üyelik Paketi',
      description:
          '4 Kişiye Kadar! Eşiniz ve çocuklarınızla ortak bütçe, ek kart eşleme ve aile hedefleri',
      priceFormatted: '₺899,99 / Yıl',
      tier: SubscriptionTier.familyPremium,
      maxFamilyMembers: 4,
    ),
  ];

  /// Uygulama başlangıcında çağrılacak Google Play Billing başlatıcısı
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Secure Storage'dan kayıtlı yetkiyi yükle
    try {
      final savedTierStr = await _storage.read(key: 'sub_tier');
      if (savedTierStr != null) {
        _currentTier = SubscriptionTier.values.firstWhere(
          (e) => e.toString() == savedTierStr,
          orElse: () => SubscriptionTier.free,
        );
        _isAnnual =
            (await _storage.read(key: 'sub_is_annual') ?? 'false') == 'true';
        tierNotifier.value = _currentTier;
      }
    } catch (e) {
      debugPrint('Kayıtlı abonelik yükleme hatası: $e');
    }

    // 2. Purchase Stream'i dinlemeye başla
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        lastError = error.toString();
        isPurchasingNotifier.value = false;
      },
    );

    // 3. Ürün detaylarını ve fiyatlarını mağazadan yükle
    await loadProducts();

    // 4. Kayıtlı yetkiyi mağazayla doğrula (iptal / süresi dolan abonelik premium'u kapatır)
    try {
      await restorePurchases();
    } catch (e) {
      debugPrint('Açılış otomatik restore hatası: $e');
    }
  }

  /// Mağazadan güncel ürünleri ve fiyatları çeker
  Future<void> loadProducts() async {
    try {
      final bool isAvailable = await InAppPurchase.instance.isAvailable();
      if (!isAvailable) return;

      final Set<String> ids = {
        individualMonthlySku,
        individualAnnualSku,
        familyAnnualSku
      };
      final ProductDetailsResponse response =
          await InAppPurchase.instance.queryProductDetails(ids);

      if (response.error != null) {
        lastError = response.error!.message;
      }

      // Android'de her abonelik teklifi (ana plan, deneme, indirim) ayrı ProductDetails olarak gelir.
      // Fiyat ve satın alma için ana plan (offerId == null) seçilir; ana plan yoksa ilk teklif kullanılır.
      trialOffers.clear();
      for (final prod in response.productDetails) {
        if (_hasFreeTrialPhase(prod)) trialOffers[prod.id] = prod;
        final existing = products[prod.id];
        if (existing == null || (!_isBasePlan(existing) && _isBasePlan(prod))) {
          products[prod.id] = prod;
        }
      }
    } catch (e) {
      lastError = e.toString();
    }
  }

  /// Google Play Billing satın alma akışını başlatır
  Future<bool> purchasePackage(SubscriptionPackage package) async {
    try {
      lastError = null;
      isPurchasingNotifier.value = true;

      final bool isAvailable = await InAppPurchase.instance.isAvailable();
      if (!isAvailable) {
        lastError = 'Google Play şu an kullanılamıyor';
        isPurchasingNotifier.value = false;
        return false;
      }

      if (products.isEmpty) {
        await loadProducts();
      }

      final ProductDetails? productDetails =
          trialOffers[package.identifier] ?? products[package.identifier];
      if (productDetails == null) {
        lastError = 'Ürün mağazada bulunamadı';
        isPurchasingNotifier.value = false;
        return false;
      }

      final active = _activePurchase;
      if (active != null && active.productID == package.identifier) {
        lastError = 'Bu plan zaten aktif.';
        isPurchasingNotifier.value = false;
        return false;
      }

      // Başka bir plan aktifse yeni abonelik açmak yerine Google'ın plan değiştirme akışı kullanılır;
      // aksi halde kullanıcı iki aboneliği birden öder. Kalan süre yeni plana orantılı aktarılır.
      final PurchaseParam purchaseParam =
          productDetails is GooglePlayProductDetails
              ? GooglePlayPurchaseParam(
                  productDetails: productDetails,
                  changeSubscriptionParam: active is GooglePlayPurchaseDetails
                      ? ChangeSubscriptionParam(
                          oldPurchaseDetails: active,
                          replacementMode: ReplacementMode.withTimeProration,
                        )
                      : null,
                )
              : PurchaseParam(productDetails: productDetails);
      final bool success = await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: purchaseParam);
      if (!success) {
        isPurchasingNotifier.value = false;
      }
      return success;
    } catch (e) {
      lastError = e.toString();
      isPurchasingNotifier.value = false;
      return false;
    }
  }

  /// Satın alımları Google Play üzerinden geri yükler ve kayıtlı yetkiyi doğrular.
  /// Mağazaya ulaşılır ama aktif abonelik gelmezse premium kapatılır; mağaza yoksa (çevrimdışı) kayıtlı yetki korunur.
  /// Dönüş: aktif abonelik bulunduysa true.
  Future<bool> restorePurchases() async {
    try {
      lastError = null;
      isPurchasingNotifier.value = true;
      final bool isAvailable = await InAppPurchase.instance.isAvailable();
      if (!isAvailable) {
        lastError = 'Google Play kullanılabilir değil';
        return false;
      }
      _sawActivePurchase = false;
      _restoreCompleter = Completer<void>();
      await InAppPurchase.instance.restorePurchases();
      // Sahip olunan ürün yoksa Play hiç olay göndermez; bu yüzden süreli bekleme
      await Future.any([
        _restoreCompleter!.future,
        Future<void>.delayed(const Duration(seconds: 8))
      ]);
      if (!_sawActivePurchase && _currentTier != SubscriptionTier.free) {
        await _revokeEntitlement();
      }
      return _sawActivePurchase;
    } catch (e) {
      lastError = e.toString();
      return false;
    } finally {
      _restoreCompleter = null;
      isPurchasingNotifier.value = false;
    }
  }

  static bool _hasFreeTrialPhase(ProductDetails details) {
    if (details is! GooglePlayProductDetails) return false;
    final index = details.subscriptionIndex;
    final offers = details.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return false;
    final offer = offers[index];
    return offer.offerId != null &&
        offer.pricingPhases.any((ph) => ph.priceAmountMicros == 0);
  }

  static bool _isBasePlan(ProductDetails details) {
    if (details is! GooglePlayProductDetails) return true;
    final index = details.subscriptionIndex;
    final offers = details.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return true;
    return offers[index].offerId == null;
  }

  Future<void> _revokeEntitlement() async {
    _activePurchase = null;
    _currentTier = SubscriptionTier.free;
    _isAnnual = false;
    tierNotifier.value = SubscriptionTier.free;
    for (final key in [
      'sub_tier',
      'sub_sku',
      'sub_is_annual',
      'sub_purchase_id'
    ]) {
      await _storage.delete(key: key);
    }
  }

  /// Satın alma güncellemelerini asenkron olarak işler
  Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final String sku = purchase.productID;
        SubscriptionTier newTier = SubscriptionTier.free;

        if (sku == individualMonthlySku || sku == individualAnnualSku) {
          newTier = SubscriptionTier.individualPremium;
          _isAnnual = sku == individualAnnualSku;
        } else if (sku == familyAnnualSku) {
          newTier = SubscriptionTier.familyPremium;
          _isAnnual = true;
        }

        if (newTier != SubscriptionTier.free) {
          _sawActivePurchase = true;
          _activePurchase = purchase;
          if (_restoreCompleter?.isCompleted == false)
            _restoreCompleter!.complete();
          _currentTier = newTier;
          tierNotifier.value = newTier;

          // Yetki bilgilerini güvenli depolamaya kaydet
          await _storage.write(key: 'sub_tier', value: newTier.toString());
          await _storage.write(key: 'sub_sku', value: sku);
          await _storage.write(
              key: 'sub_is_annual', value: _isAnnual.toString());
          await _storage.write(
              key: 'sub_purchase_id', value: purchase.purchaseID ?? '');
        }

        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
        isPurchasingNotifier.value = false;
      } else if (purchase.status == PurchaseStatus.error) {
        lastError = purchase.error?.message ??
            'Satın alma işlemi sırasında bir hata oluştu';
        isPurchasingNotifier.value = false;
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        isPurchasingNotifier.value = false;
      } else if (purchase.status == PurchaseStatus.pending) {
        isPurchasingNotifier.value = true;
      }
    }
  }

  /// Kaynakları temizle
  void dispose() {
    _subscription?.cancel();
    tierNotifier.dispose();
    isPurchasingNotifier.dispose();
  }
}
