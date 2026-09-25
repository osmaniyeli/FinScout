// lib/core/services/user_profile_service.dart

import 'account_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../database/repositories/transaction_repository.dart';
import 'notification_service.dart';
import '../../features/assets_portfolio/repositories/assets_repository.dart';
import '../localization/app_strings.dart';
import '../../features/subscription/services/subscription_service.dart';

class DocumentQuotaResult {
  final bool canUpload;
  final String reason;
  final int usedThisMonth;
  final int maxThisMonth;
  final String planName;

  /// Sunucuya ulaşılamadığı için karar verilemedi (kota dolu değil; bağlantı sorunu)
  final bool isNetworkError;

  /// Sunucuda sayılan tüketimin kimliği (consume_upload → consumption_id). Kayıt başarısız olursa
  /// [UserProfileService.refundUpload] bununla iade ister. Kotaya sayılmayan yüklemede null.
  final String? consumptionId;

  const DocumentQuotaResult({
    required this.canUpload,
    required this.reason,
    required this.usedThisMonth,
    required this.maxThisMonth,
    required this.planName,
    this.isNetworkError = false,
    this.consumptionId,
  });
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String currency;
  final int monthlyBudgetCents;
  final DateTime joinedAt;

  UserProfile({
    required this.id,
    required this.name,
    this.email = '',
    this.currency = 'TRY',
    this.monthlyBudgetCents = 0,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'currency': currency,
        'monthlyBudgetCents': monthlyBudgetCents,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] ?? 'default_user',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        currency: map['currency'] ?? 'TRY',
        monthlyBudgetCents: map['monthlyBudgetCents'] ?? 0,
        joinedAt: map['joinedAt'] != null
            ? DateTime.parse(map['joinedAt'])
            : DateTime.now(),
      );
}

class InAppNotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime date;
  bool isRead;
  bool isDismissed;

  InAppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    this.isRead = false,
    this.isDismissed = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'date': date.toIso8601String(),
        'isRead': isRead,
        'isDismissed': isDismissed,
      };

  factory InAppNotificationItem.fromMap(Map<String, dynamic> map) =>
      InAppNotificationItem(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        message: map['message'] ?? '',
        date:
            map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
        isRead: map['isRead'] ?? false,
        isDismissed: map['isDismissed'] ?? false,
      );
}

class UserProfileService {
  static final UserProfileService instance = UserProfileService._internal();
  UserProfileService._internal();

  UserProfile? _profile;
  final Set<String> _dismissedNuanceIds = {};
  final List<InAppNotificationItem> _notifications = [];
  final Map<String, Map<String, int>> _monthlyUploads = {};
  bool _isLoaded = false;

  final ValueNotifier<UserProfile?> profileNotifier =
      ValueNotifier<UserProfile?>(null);
  final ValueNotifier<List<InAppNotificationItem>> notificationsNotifier =
      ValueNotifier([]);

  UserProfile? get profile => _profile;
  bool get hasProfile => _profile != null && _profile!.name.trim().isNotEmpty;

  List<InAppNotificationItem> get allNotifications =>
      List.unmodifiable(_notifications);

  DocumentQuotaResult checkUploadQuota({required String documentTypeHint}) {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    // Sunucudaki sayaç esas; yoksa (çevrimdışı) cihazdaki son bilinen değer. Kesin kontrol consumeUpload'da.
    final sub = SubscriptionService.instance;
    final monthData = sub.serverPeriod == monthKey
        ? sub.serverUsage
        : (_monthlyUploads[monthKey] ?? const <String, int>{});

    final tier = SubscriptionService.instance.currentTier;
    final normalizedType = _normalizeDocType(documentTypeHint);

    int totalMonthUsed = 0;
    monthData.forEach((_, v) => totalMonthUsed += v);
    final typeUsed = monthData[normalizedType] ?? 0;

    if (tier == SubscriptionTier.free) {
      if (totalMonthUsed >= 1) {
        return DocumentQuotaResult(
          canUpload: false,
          reason:
              'Ücretsiz deneme kotanız (ayda 1 ekstre) dolmuştur. Kesintisiz yükleme için Premium plana geçebilirsiniz.',
          usedThisMonth: totalMonthUsed,
          maxThisMonth: 1,
          planName: 'Ücretsiz Başlangıç',
        );
      }
      return DocumentQuotaResult(
        canUpload: true,
        reason: '1 adet ücretsiz deneme belgesi hakkınız bulunmaktadır.',
        usedThisMonth: totalMonthUsed,
        maxThisMonth: 1,
        planName: 'Ücretsiz Başlangıç',
      );
    }

    if (tier == SubscriptionTier.familyPremium) {
      // Aile: ayda 5 kart + 5 hesap ekstresi + 2 bordro = 12
      const limits = {'credit_card': 5, 'checking': 5, 'payroll': 2};
      final typeLimit = limits[normalizedType]!;
      if (typeUsed >= typeLimit) {
        return DocumentQuotaResult(
          canUpload: false,
          reason:
              'Aile paketinde bu ay ${_getDocTypeName(normalizedType)} hakkın ($typeLimit) doldu. '
              'Aylık kota: 5 kart ekstresi, 5 hesap ekstresi, 2 bordro.',
          usedThisMonth: totalMonthUsed,
          maxThisMonth: 12,
          planName: 'Aile Paketi',
        );
      }
      return DocumentQuotaResult(
        canUpload: true,
        reason:
            'Bu ay ${typeLimit - typeUsed} ${_getDocTypeName(normalizedType)} hakkın var.',
        usedThisMonth: totalMonthUsed,
        maxThisMonth: 12,
        planName: 'Aile Paketi',
      );
    }

    // Bireysel: aylık planda ayda 3, yıllık planda ayda 5 belge (tür fark etmez; iki kartı olan da yükleyebilir)
    final isAnnual = SubscriptionService.instance.isAnnualPlan;
    final maxLimit = isAnnual ? 5 : 3;
    final planName = isAnnual ? 'Bireysel Yıllık Premium' : 'Bireysel Aylık Premium';
    if (totalMonthUsed >= maxLimit) {
      return DocumentQuotaResult(
        canUpload: false,
        reason: '$planName planının bu ayki $maxLimit belge hakkı doldu.',
        usedThisMonth: totalMonthUsed,
        maxThisMonth: maxLimit,
        planName: planName,
      );
    }
    return DocumentQuotaResult(
      canUpload: true,
      reason: 'Bu ay ${maxLimit - totalMonthUsed} belge hakkın var.',
      usedThisMonth: totalMonthUsed,
      maxThisMonth: maxLimit,
      planName: planName,
    );
  }

  String _normalizeDocType(String hint) {
    final lower = hint.toLowerCase();
    if (lower.contains('pay') || lower.contains('bordro')) return 'payroll';
    if (lower.contains('card') || lower.contains('kart')) return 'credit_card';
    return 'checking';
  }

  String _getDocTypeName(String norm) {
    if (norm == 'payroll') return 'Maaş Bordrosu';
    if (norm == 'credit_card') return 'Kredi Kartı Ekstresi';
    return 'Banka Hesap Ekstresi';
  }

  /// Kotaya sayılmayan yükleme: hesabın ilk 30 gününde, içinde bulunulan aydan önceki bir döneme ait
  /// belge (geçmiş ekstreleri toplu yükleyip başlangıç yapabilmek için).
  bool isFreeBackfill(DateTime periodEnd) {
    final now = DateTime.now();
    return inBackfillWindow && periodEnd.isBefore(DateTime(now.year, now.month));
  }

  /// Hesabın ilk 30 günü: kota dolu olsa da geçmiş dönem belgesi seçilebilir (kayıtta tekrar kontrol edilir).
  bool get inBackfillWindow {
    // Sunucu hesabın açılış tarihini bilir; yerel tarih yalnız sunucu yanıtı yokken kullanılır
    final serverUntil = SubscriptionService.instance.backfillUntil;
    if (serverUntil != null) return DateTime.now().isBefore(serverUntil);
    final joined = _profile?.joinedAt;
    return joined != null && DateTime.now().difference(joined).inDays < 30;
  }

  /// Bu ayın kullanımını ve paketi sunucudan tazeler (ağ yoksa son bilinen değer kalır).
  Future<void> refreshUploadUsage() =>
      SubscriptionService.instance.refreshEntitlement();

  /// Belge kotasını SUNUCUDA atomik olarak düşer; kayıttan ÖNCE çağrılır.
  /// [documentTypeHint]: belgeden ALGILANAN tür (CREDIT_CARD / CHECKING / PAYSLIP), kullanıcının seçtiği çip değil.
  /// [isBackfill]: belge geçmiş döneme ait; sunucu yalnız hesabın ilk 30 gününde kotasız sayar.
  /// Sunucuya ulaşılamazsa yükleme yapılmaz (isNetworkError): kota bir ödeme hakkı olduğu için
  /// cihazdaki sayaca güvenilmez; belge telefonda kalır, bağlantı gelince yeniden denenebilir.
  Future<DocumentQuotaResult> consumeUpload(String documentTypeHint,
      {required bool isBackfill}) async {
    final normalizedType = _normalizeDocType(documentTypeHint);
    final client = AccountService.instance.signedInClient;
    if (client == null) {
      return const DocumentQuotaResult(
        canUpload: false,
        reason: 'Belge yüklemek için hesabına giriş yapmalısın.',
        usedThisMonth: 0,
        maxThisMonth: 0,
        planName: '',
        isNetworkError: true,
      );
    }
    final Map<String, dynamic> res;
    try {
      final data = await client.rpc('consume_upload', params: {
        'p_doc_type': normalizedType,
        'p_is_backfill': isBackfill,
      });
      res = Map<String, dynamic>.from(data as Map);
    } catch (e) {
      debugPrint('Kota sunucuda düşülemedi: $e');
      return const DocumentQuotaResult(
        canUpload: false,
        reason:
            'Belge hakkın kontrol edilemedi. İnternet bağlantını kontrol edip tekrar dene; belge kaydedilmedi.',
        usedThisMonth: 0,
        maxThisMonth: 0,
        planName: '',
        isNetworkError: true,
      );
    }

    final sub = SubscriptionService.instance;
    sub.updateUsageFromServer(res);
    final period = res['period'] as String?;
    final usage = sub.serverUsage;
    if (period != null) {
      _monthlyUploads[period] = Map<String, int>.from(usage);
      await _persist();
    }

    final used = usage.values.fold<int>(0, (a, b) => a + b);
    final totalLimit = (res['total_limit'] as num?)?.toInt() ?? 0;
    final planName = _planDisplayName(res['plan'] as String? ?? 'free');
    if (res['allowed'] == true) {
      return DocumentQuotaResult(
        canUpload: true,
        reason: res['counted'] == true
            ? 'Bu ay $used / $totalLimit belge hakkı kullanıldı.'
            : 'Geçmiş dönem belgesi: ilk 30 gün kotaya sayılmaz.',
        usedThisMonth: used,
        maxThisMonth: totalLimit,
        planName: planName,
        consumptionId: res['consumption_id'] as String?,
      );
    }
    final typeLimit = (res['type_limit'] as num?)?.toInt();
    return DocumentQuotaResult(
      canUpload: false,
      reason: typeLimit != null && (usage[normalizedType] ?? 0) >= typeLimit
          ? '$planName: bu ay ${_getDocTypeName(normalizedType)} hakkın ($typeLimit) doldu. '
              'Aylık kota: 5 kart ekstresi, 5 hesap ekstresi, 2 bordro.'
          : '$planName planının bu ayki $totalLimit belge hakkı doldu.',
      usedThisMonth: used,
      maxThisMonth: totalLimit,
      planName: planName,
    );
  }

  /// Kota düşüldükten sonra cihazdaki kayıt başarısız olduysa o tek tüketimi sunucuda geri alır
  /// (refund_upload: yalnız kendi, 15 dk içindeki, iade edilmemiş tüketim; ayda en fazla 3 iade).
  /// Hata fırlatmaz: iade olmazsa yalnız loglanır, kullanıcıya gösterilen kayıt hatası değişmez.
  Future<bool> refundUpload(String consumptionId) async {
    final client = AccountService.instance.signedInClient;
    if (client == null) {
      debugPrint('Kota iadesi yapılamadı: oturum yok');
      return false;
    }
    try {
      final data = await client.rpc('refund_upload', params: {'p_consumption_id': consumptionId});
      final res = Map<String, dynamic>.from(data as Map);
      final sub = SubscriptionService.instance;
      sub.updateUsageFromServer(res);
      final period = res['period'] as String?;
      if (period != null) {
        _monthlyUploads[period] = Map<String, int>.from(sub.serverUsage);
        await _persist();
      }
      return res['refunded'] == true;
    } catch (e) {
      debugPrint('Kota iadesi yapılamadı: $e');
      return false;
    }
  }

  static String _planDisplayName(String plan) => switch (plan) {
        'family' => 'Aile Paketi',
        'annual' => 'Bireysel Yıllık Premium',
        'monthly' => 'Bireysel Aylık Premium',
        _ => 'Ücretsiz Başlangıç',
      };

  Future<File> _getStorageFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/paraiz_user_profile.json');
  }

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        if (data['profile'] != null) {
          _profile = UserProfile.fromMap(data['profile']);
          profileNotifier.value = _profile;
        }

        if (data['dismissed_nuances'] != null) {
          _dismissedNuanceIds
              .addAll((data['dismissed_nuances'] as List).cast<String>());
        }

        if (data['notifications'] != null) {
          _notifications.clear();
          for (final n in data['notifications'] as List) {
            _notifications.add(InAppNotificationItem.fromMap(n));
          }
          notificationsNotifier.value = List.from(_notifications);
        }

        if (data['language'] != null) {
          AppStrings.setLocale('tr');
        }

        if (data['monthly_uploads'] != null) {
          _monthlyUploads.clear();
          final uploadsMap = data['monthly_uploads'] as Map<String, dynamic>;
          uploadsMap.forEach((mKey, v) {
            if (v is Map) {
              _monthlyUploads[mKey] = v.map(
                  (k, val) => MapEntry(k.toString(), (val as num).toInt()));
            }
          });
        }
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('UserProfileService yükleme hatası: $e');
      _isLoaded = true;
    }
  }

  Future<void> saveProfile(UserProfile newProfile) async {
    _profile = newProfile;
    profileNotifier.value = _profile;
    await _persist();
  }

  Future<void> updateLanguage(String lang) async {
    AppStrings.setLocale(lang);
    await _persist();
  }

  bool isNuanceDismissed(String nuanceId) {
    return _dismissedNuanceIds.contains(nuanceId);
  }

  Future<void> dismissNuance(String nuanceId,
      {String? title, String? message}) async {
    _dismissedNuanceIds.add(nuanceId);

    // Bildirimler listesine arşiv olarak ekle
    if (title != null && message != null) {
      final existingIndex = _notifications.indexWhere((n) => n.id == nuanceId);
      if (existingIndex >= 0) {
        _notifications[existingIndex].isDismissed = true;
      } else {
        _notifications.insert(
          0,
          InAppNotificationItem(
            id: nuanceId,
            title: title,
            message: message,
            date: DateTime.now(),
            isDismissed: true,
          ),
        );
      }
      notificationsNotifier.value = List.from(_notifications);
    }

    await _persist();
  }

  Future<void> markNotificationAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx].isRead = true;
      notificationsNotifier.value = List.from(_notifications);
      await _persist();
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notificationsNotifier.value = List.from(_notifications);
    await _persist();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notificationsNotifier.value = List.from(_notifications);
    await _persist();
  }

  Future<void> clearAllNotifications() async {
    _notifications.clear();
    notificationsNotifier.value = [];
    await _persist();
  }

  Future<void> addNotification({
    required String id,
    required String title,
    required String message,
  }) async {
    if (_notifications.any((n) => n.id == id)) return;
    _notifications.insert(
      0,
      InAppNotificationItem(
        id: id,
        title: title,
        message: message,
        date: DateTime.now(),
      ),
    );
    notificationsNotifier.value = List.from(_notifications);
    await _persist();
  }

Future<void> checkAssetTargetAlert({
    required String assetId,
    required String assetName,
    required double currentPrice,
    required double targetPrice,
  }) async {
    if (targetPrice <= 0 || currentPrice < targetPrice) return;
    final now = DateTime.now();
    final alertId =
        'target_${assetId}_${targetPrice.toInt()}_${now.year}_${now.month}';
    await addNotification(
      id: alertId,
      title: '🎯 Hedef Fiyata Ulaşıldı: $assetName',
      message:
          '$assetName hedeflediğiniz ₺${targetPrice.toStringAsFixed(2)} seviyesine ulaştı (Güncel: ₺${currentPrice.toStringAsFixed(2)}). Portföyünüzü değerlendirebilirsiniz.',
    );
  }

  Future<void> logOut() async {
    await AccountService.instance.signOut();
    _profile = null;
    profileNotifier.value = null;
    await _persist();
  }

  // ---- Cihazda tek hesap: telefondaki finansal veri hangi hesaba ait?
  // Çıkışta silinmez (aynı hesap geri gelince verisini bulur); farklı hesapla girişte sorulur.
  Future<File> _dataOwnerFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/paraiz_data_owner.json');
  }

  Future<String?> localDataOwnerId() async {
    try {
      final f = await _dataOwnerFile();
      if (await f.exists()) {
        return (jsonDecode(await f.readAsString()) as Map)['user_id'] as String?;
      }
    } catch (e) {
      debugPrint('Veri sahibi okunamadı: $e');
    }
    return _profile?.id;
  }

  Future<void> setLocalDataOwner(String userId) async {
    final f = await _dataOwnerFile();
    await f.writeAsString(jsonEncode({'user_id': userId}));
  }

  /// Telefonda ekstre/işlem/hedef gibi finansal kayıt var mı?
  Future<bool> hasLocalFinancialData() async {
    try {
      final db = await AppDatabase.instance.database;
      for (final t in const ['transactions', 'accounts', 'goals']) {
        final r = await db.rawQuery('SELECT 1 FROM $t LIMIT 1');
        if (r.isNotEmpty) return true;
      }
    } catch (_) {}
    return false;
  }

  /// Tüm veritabanı tablolarını ve yerel profili kalıcı olarak siler
  Future<void> resetAllUserData() async {
    await wipeLocalData();
    await AccountService.instance.signOut();
  }

  /// Telefondaki tüm finansal veriyi, profili ve ayarları siler; oturuma dokunmaz.
  Future<void> wipeLocalData() async {
    // 1. Veritabanını sıfırla
    try {
      await TransactionRepository().clearAllUserData();
      final db = await AppDatabase.instance.database;
      await db.execute('DELETE FROM goal_contributions');
      await db.execute('DELETE FROM goals');
      await db.execute('DELETE FROM merchant_rules');
    } catch (e) {
      debugPrint('Veritabanı sıfırlama hatası: $e');
    }

    // 2. Telefondaki diğer veri dosyaları ve kurulu hatırlatmalar
    try {
      await AssetsRepository.instance.clearAll();
final dir = await getApplicationDocumentsDirectory();
      for (final name in const [
        'paraiz_wallets.json',
        'paraiz_family_members.json',
        'paraiz_subscriptions_bills.json',
        'paraiz_market_cache.json',
        'custom_bank_templates.json',
      ]) {
        final f = File('${dir.path}/$name');
        if (await f.exists()) await f.delete();
      }
      await NotificationService.instance.cancelAll();
    } catch (e) {
      debugPrint('Yerel dosyalar silinemedi: $e');
    }

    // 3. Yerel profil ve ayarlar
    _profile = null;
    _dismissedNuanceIds.clear();
    _notifications.clear();
    _monthlyUploads.clear();
    profileNotifier.value = null;
    notificationsNotifier.value = [];

    final file = await _getStorageFile();
    if (await file.exists()) {
      await file.delete();
    }
    final owner = await _dataOwnerFile();
    if (await owner.exists()) await owner.delete();
  }

  Future<void> _persist() async {
    try {
      final file = await _getStorageFile();
      final map = {
        'profile': _profile?.toMap(),
        'dismissed_nuances': _dismissedNuanceIds.toList(),
        'notifications': _notifications.map((n) => n.toMap()).toList(),
        'language': AppStrings.currentLocale.value,
        'monthly_uploads': _monthlyUploads,
      };
      await file.writeAsString(jsonEncode(map));
    } catch (e) {
      debugPrint('UserProfileService kaydetme hatası: $e');
    }
  }
}
