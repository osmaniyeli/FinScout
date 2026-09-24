import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/account_service.dart';

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

/// Abonelik ve paket hakkı.
///
/// Premium hakkı YALNIZ sunucudan gelir: satın alma makbuzu `verify-purchase` Edge Function'ında
/// Google Play Developer API ile doğrulanır; etkin paket `entitlement` RPC'sinden okunur
/// (kendi aboneliği ya da üyesi olunan ailenin sahibinin aile aboneliği). Cihazdaki önbellek
/// yalnızca çevrimdışı gösterim içindir ve dönem sonunda kendiliğinden düşer; belge kotası
/// her durumda sunucuda uygulanır.
class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._internal();
  SubscriptionService._internal();

  // Google Play Store Ürün Tanımları
  static const String individualMonthlySku = 'finscout_individual_monthly';
  static const String individualAnnualSku = 'finscout_individual_annual';
  static const String familyAnnualSku =
      'finscout_family_annual_4p'; // Aile Paketi (4 Kişi)

  static const String _cacheKey = 'entitlement_cache_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isInitialized = false;

  /// Google'ın bildirdiği şu an aktif abonelik satın alması (plan değişikliğinde eskisini değiştirmek için)
  PurchaseDetails? _activePurchase;
  Completer<void>? _restoreCompleter;
  final List<Future<bool>> _pendingVerifications = [];

  SubscriptionTier _currentTier = SubscriptionTier.free;
  bool _isAnnual = false;
  String _source = 'none'; // own | family | none
  String? _productId;
  DateTime? _expiry;
  String? lastError;

  /// Sunucudan gelen bu ayın belge kullanımı (kota ekranı ön kontrolü için; asıl kontrol sunucuda)
  Map<String, int> serverUsage = const {};
  String? serverPeriod;
  DateTime? backfillUntil;

  SubscriptionTier get currentTier => _currentTier;
  bool get isAnnualPlan => _isAnnual;
  bool get isPremium => _currentTier != SubscriptionTier.free;
  bool get isFamilyPlan => _currentTier == SubscriptionTier.familyPremium;

  /// Premium hakkı başka birinin aile paketinden mi geliyor
  bool get isFamilyMemberEntitlement => _source == 'family';

  /// Kullanıcının KENDİ aktif aboneliğinin ürün kimliği (aile üyeliğinde null)
  String? get ownProductId => _source == 'own' ? _productId : null;
  DateTime? get entitlementExpiry => _expiry;

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
      title: 'Aile Paketi',
      description:
          'Premium hakkını en fazla 4 kişiyle paylaşır (sen dahil). Her üyenin kendi aylık kotası: '
          '5 kart ekstresi, 5 hesap ekstresi, 2 bordro. Herkesin ekstre ve işlemleri kendi '
          'telefonunda kalır; kimse diğerinin verisini görmez.',
      priceFormatted: '₺899,99 / Yıl',
      tier: SubscriptionTier.familyPremium,
      maxFamilyMembers: 4,
    ),
  ];

  /// Uygulama başlangıcında çağrılacak Google Play Billing başlatıcısı
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Son sunucu yanıtı (yalnız çevrimdışı gösterim; süresi geçmişse yok sayılır)
    await _loadCache();

    // 2. Purchase Stream'i dinlemeye başla
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        lastError = error.toString();
        isPurchasingNotifier.value = false;
      },
    );

    // 3. Hesap değişince paket hakkını sunucudan yeniden al
    _authSubscription = AccountService.instance.authChanges?.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.userUpdated:
          unawaited(refreshEntitlement());
          break;
        case AuthChangeEvent.signedOut:
          unawaited(_applyEntitlement(null));
          break;
        default:
          break;
      }
    });

    // 4. Ürün detaylarını ve fiyatlarını mağazadan yükle
    await loadProducts();

    // 5. Play'deki satın almaları sunucuda doğrula, ardından paketi sunucudan al
    try {
      await restorePurchases();
    } catch (e) {
      debugPrint('Açılış otomatik restore hatası: $e');
      await refreshEntitlement();
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

      // Makbuz hesaba bağlanır (Google'a obfuscatedAccountId olarak gider; sunucu eşleşmeyi denetler)
      final userId = AccountService.instance.currentUser?.id;
      if (userId == null) {
        lastError = 'Abonelik almak için önce hesabına giriş yap.';
        isPurchasingNotifier.value = false;
        return false;
      }

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
                  applicationUserName: userId,
                  changeSubscriptionParam: active is GooglePlayPurchaseDetails
                      ? ChangeSubscriptionParam(
                          oldPurchaseDetails: active,
                          replacementMode: ReplacementMode.withTimeProration,
                        )
                      : null,
                )
              : PurchaseParam(
                  productDetails: productDetails, applicationUserName: userId);
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

  /// Play'deki satın almaları geri yükler, her birini sunucuda doğrular ve paketi sunucudan tazeler.
  /// Dönüş: sunucuya göre premium hakkı varsa true (aile üyeliği dahil).
  Future<bool> restorePurchases() async {
    try {
      lastError = null;
      isPurchasingNotifier.value = true;
      final bool isAvailable = await InAppPurchase.instance.isAvailable();
      if (isAvailable) {
        _restoreCompleter = Completer<void>();
        await InAppPurchase.instance.restorePurchases(
            applicationUserName: AccountService.instance.currentUser?.id);
        // Sahip olunan ürün yoksa Play hiç olay göndermez; bu yüzden süreli bekleme
        await Future.any([
          _restoreCompleter!.future,
          Future<void>.delayed(const Duration(seconds: 8))
        ]);
        if (_pendingVerifications.isNotEmpty) {
          await Future.wait(List.of(_pendingVerifications));
        }
      } else {
        lastError = 'Google Play kullanılabilir değil';
      }
      final refreshed = await refreshEntitlement();
      if (!refreshed && lastError == null) {
        lastError =
            'Abonelik durumu sunucudan alınamadı. İnternet bağlantını kontrol edip tekrar dene.';
      }
      return isPremium;
    } catch (e) {
      lastError = e.toString();
      return false;
    } finally {
      _restoreCompleter = null;
      isPurchasingNotifier.value = false;
    }
  }

  /// Etkin paketi sunucudan okur. Oturum yoksa ücretsiz pakete düşer.
  /// Dönüş: sunucuya ulaşıldıysa true (hata durumunda son bilinen paket korunur).
  Future<bool> refreshEntitlement() async {
    final client = AccountService.instance.signedInClient;
    if (client == null) {
      await _applyEntitlement(null);
      return true;
    }
    try {
      final data = await client.rpc('entitlement');
      if (data is Map) {
        await _applyEntitlement(Map<String, dynamic>.from(data));
        return true;
      }
    } catch (e) {
      debugPrint('Paket hakkı alınamadı: $e');
    }
    return false;
  }

  Future<void> _applyEntitlement(Map<String, dynamic>? e,
      {bool persist = true}) async {
    final plan = e?['plan'] as String? ?? 'free';
    _source = e?['source'] as String? ?? 'none';
    _productId = e?['product_id'] as String?;
    _expiry = DateTime.tryParse(e?['expiry_time']?.toString() ?? '');
    _isAnnual = plan == 'annual' || plan == 'family';
    _currentTier = switch (plan) {
      'family' => SubscriptionTier.familyPremium,
      'annual' || 'monthly' => SubscriptionTier.individualPremium,
      _ => SubscriptionTier.free,
    };
    final usage = e?['usage'];
    serverUsage = usage is Map
        ? usage.map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
        : const {};
    serverPeriod = e?['period'] as String?;
    backfillUntil = DateTime.tryParse(e?['backfill_until']?.toString() ?? '');
    tierNotifier.value = _currentTier;

    if (!persist) return;
    try {
      if (e == null) {
        await _storage.delete(key: _cacheKey);
      } else {
        await _storage.write(key: _cacheKey, value: jsonEncode(e));
      }
    } catch (err) {
      debugPrint('Paket önbelleği yazılamadı: $err');
    }
  }

  /// Kota kullanımını sunucu yanıtıyla günceller (consume_upload sonrası)
  void updateUsageFromServer(Map<String, dynamic> res) {
    final usage = res['usage'];
    if (usage is Map) {
      serverUsage =
          usage.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    serverPeriod = res['period'] as String? ?? serverPeriod;
  }

  Future<void> _loadCache() async {
    try {
      // Eski sürümlerin yerel "premium" bayrakları artık kullanılmıyor
      for (final key in const [
        'sub_tier',
        'sub_sku',
        'sub_is_annual',
        'sub_purchase_id'
      ]) {
        await _storage.delete(key: key);
      }
      if (!AccountService.instance.isSignedIn) return;
      final raw = await _storage.read(key: _cacheKey);
      if (raw == null) return;
      final cached = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final expiry = DateTime.tryParse(cached['expiry_time']?.toString() ?? '');
      if (expiry != null && expiry.isAfter(DateTime.now())) {
        await _applyEntitlement(cached, persist: false);
      }
    } catch (e) {
      debugPrint('Paket önbelleği okunamadı: $e');
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

  /// Makbuzu sunucuda (Google Play Developer API) doğrular. Başarılıysa paket hakkı güncellenir.
  Future<bool> _verifyWithServer(PurchaseDetails purchase) async {
    final client = AccountService.instance.signedInClient;
    if (client == null) {
      lastError = 'Aboneliği etkinleştirmek için hesabına giriş yap.';
      return false;
    }
    try {
      final res = await client.functions.invoke(
        'verify-purchase',
        body: {
          'productId': purchase.productID,
          'purchaseToken': purchase.verificationData.serverVerificationData,
        },
      );
      final data = res.data;
      if (data is Map && data['entitlement'] is Map) {
        await _applyEntitlement(
            Map<String, dynamic>.from(data['entitlement'] as Map));
      } else {
        await refreshEntitlement();
      }
      return true;
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['error']?.toString() : null;
      debugPrint('Satın alma doğrulanamadı: ${e.status} $code');
      lastError = switch (code) {
        'token_in_use' =>
          'Bu abonelik başka bir FinScout hesabına bağlı. Satın aldığın hesapla giriş yap.',
        'invalid_token' || 'product_mismatch' || 'bad_request' =>
          'Satın alma makbuzu Google Play tarafından doğrulanamadı.',
        'unauthorized' => 'Oturumun sona ermiş. Yeniden giriş yapıp tekrar dene.',
        _ =>
          'Satın alma şu an doğrulanamadı. Ödemen güvende; biraz sonra "Satın alımları geri yükle" ile tekrar dene.',
      };
      return false;
    } catch (e) {
      debugPrint('Satın alma doğrulama hatası: $e');
      lastError =
          'Satın alma doğrulanamadı: internet bağlantını kontrol et. Ödemen güvende; bağlantı gelince tekrar dene.';
      return false;
    }
  }

  /// Satın alma güncellemelerini asenkron olarak işler
  Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final knownSku = purchase.productID == individualMonthlySku ||
            purchase.productID == individualAnnualSku ||
            purchase.productID == familyAnnualSku;
        if (!knownSku) continue;

        _activePurchase = purchase;
        final verification = _verifyWithServer(purchase);
        _pendingVerifications.add(verification);
        if (_restoreCompleter?.isCompleted == false) {
          _restoreCompleter!.complete();
        }
        final verified = await verification;
        _pendingVerifications.remove(verification);

        // Onay (acknowledge) yalnız sunucu doğrulamasından sonra: doğrulanamayan satın alma
        // onaylanmaz, Play bir sonraki açılışta yeniden bildirir; 3 gün içinde hiç doğrulanamazsa
        // Google ödemeyi otomatik iade eder (kullanıcı hak almadan ücret ödemez).
        if (verified && purchase.pendingCompletePurchase) {
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
    _authSubscription?.cancel();
    tierNotifier.dispose();
    isPurchasingNotifier.dispose();
  }
}
