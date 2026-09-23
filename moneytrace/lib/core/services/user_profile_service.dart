// lib/core/services/user_profile_service.dart

import 'account_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../localization/app_strings.dart';
import '../../features/subscription/services/subscription_service.dart';

class DocumentQuotaResult {
  final bool canUpload;
  final String reason;
  final int usedThisMonth;
  final int maxThisMonth;
  final String planName;

  const DocumentQuotaResult({
    required this.canUpload,
    required this.reason,
    required this.usedThisMonth,
    required this.maxThisMonth,
    required this.planName,
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
    final monthData = _monthlyUploads[monthKey] ?? {};

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
      const maxLimit = 12; // 4 kişi için toplam 12 belge
      if (totalMonthUsed >= maxLimit) {
        return DocumentQuotaResult(
          canUpload: false,
          reason:
              'Aile Paketi aylık yükleme kotanız ($maxLimit belge) dolmuştur.',
          usedThisMonth: totalMonthUsed,
          maxThisMonth: maxLimit,
          planName: 'Aile Paketi',
        );
      }
      return DocumentQuotaResult(
        canUpload: true,
        reason:
            'Aile Paketi kapsamında bu ay ${maxLimit - totalMonthUsed} belge yükleme hakkınız var.',
        usedThisMonth: totalMonthUsed,
        maxThisMonth: maxLimit,
        planName: 'Aile Paketi',
      );
    }

    // Bireysel Plan: Aylık veya Yıllık
    final isAnnual = SubscriptionService.instance.isAnnualPlan;
    if (isAnnual) {
      const maxLimit = 5;
      if (totalMonthUsed >= maxLimit) {
        return DocumentQuotaResult(
          canUpload: false,
          reason: 'Bireysel Yıllık planınızın aylık 5 belge kotası dolmuştur.',
          usedThisMonth: totalMonthUsed,
          maxThisMonth: maxLimit,
          planName: 'Bireysel Yıllık Premium',
        );
      }
      return DocumentQuotaResult(
        canUpload: true,
        reason:
            'Bireysel Yıllık planınızda bu ay ${maxLimit - totalMonthUsed} belge yükleme hakkınız var.',
        usedThisMonth: totalMonthUsed,
        maxThisMonth: maxLimit,
        planName: 'Bireysel Yıllık Premium',
      );
    } else {
      // Bireysel Aylık: 1 bordro, 1 hesap ekstresi, 1 kredi kartı ekstresi (toplam 3)
      if (typeUsed >= 1) {
        final typeName = _getDocTypeName(normalizedType);
        return DocumentQuotaResult(
          canUpload: false,
          reason:
              'Bireysel Aylık paketinizde bu ay 1 adet $typeName hakkınız dolmuştur. (Aylık kota: 1 bordro, 1 hesap ekstresi, 1 kredi kartı)',
          usedThisMonth: totalMonthUsed,
          maxThisMonth: 3,
          planName: 'Bireysel Aylık Premium',
        );
      }
      if (totalMonthUsed >= 3) {
        return DocumentQuotaResult(
          canUpload: false,
          reason: 'Bireysel Aylık paketinizin aylık 3 belge kotası dolmuştur.',
          usedThisMonth: totalMonthUsed,
          maxThisMonth: 3,
          planName: 'Bireysel Aylık Premium',
        );
      }
      return DocumentQuotaResult(
        canUpload: true,
        reason:
            'Bireysel Aylık planınızda bu ay ${3 - totalMonthUsed} belge hakkınız var.',
        usedThisMonth: totalMonthUsed,
        maxThisMonth: 3,
        planName: 'Bireysel Aylık Premium',
      );
    }
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

  Future<void> recordDocumentUpload(String documentTypeHint) async {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final normalizedType = _normalizeDocType(documentTypeHint);

    _monthlyUploads.putIfAbsent(monthKey, () => {});
    final current = _monthlyUploads[monthKey]![normalizedType] ?? 0;
    _monthlyUploads[monthKey]![normalizedType] = current + 1;
    await _persist();
  }

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
          AppStrings.setLocale(data['language']);
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

  Future<void> checkScheduledReminders({int salaryDay = 15}) async {
    final now = DateTime.now();
    final monthKey = '${now.year}_${now.month}';

    // 1. Maaş Günü Hatırlatması
    if (now.day == salaryDay) {
      await addNotification(
        id: 'salary_reminder_$monthKey',
        title: 'Maaş Günü Hatırlatması',
        message:
            'Bugün beklenen maaş / hakediş gününüz. Hesabınızı kontrol ederek güncel bakiyenizi teyit edebilirsiniz.',
      );
    }

    // 2. Ekstre ve Son Ödeme Günü Hatırlatması
    if (now.day == 20 || now.day == 1) {
      await addNotification(
        id: 'statement_cutoff_${monthKey}_${now.day}',
        title: 'Kart Ekstresi & Ödeme Hatırlatması',
        message:
            'Kredi kartı hesap özetiniz oluşturuldu. Son ödeme tarihini kaçırmamak için borç ödemenizi kontrol edin.',
      );
    }
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

  /// Tüm veritabanı tablolarını ve yerel profili kalıcı olarak siler
  Future<void> resetAllUserData() async {
    // 1. Veritabanını sıfırla
    try {
      final db = await AppDatabase.instance.database;
      await db.execute('DELETE FROM transactions');
      await db.execute('DELETE FROM statements');
      await db.execute('DELETE FROM accounts');
      await db.execute('DELETE FROM installments');
      await db.execute('DELETE FROM tax_deductions');
      await db.execute('DELETE FROM goals');
      await db.execute('DELETE FROM goal_contributions');
      await db.execute('DELETE FROM merchant_rules');
    } catch (e) {
      debugPrint('Veritabanı sıfırlama hatası: $e');
    }

    // 2. Hesap oturumunu kapat, yerel profili ve ayarları sıfırla
    await AccountService.instance.signOut();
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
