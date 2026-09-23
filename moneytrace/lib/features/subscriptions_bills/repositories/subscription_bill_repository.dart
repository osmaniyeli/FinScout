// lib/features/subscriptions_bills/repositories/subscription_bill_repository.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../models/subscription_bill_item.dart';

class SubscriptionBillRepository {
  static final SubscriptionBillRepository instance =
      SubscriptionBillRepository._internal();
  SubscriptionBillRepository._internal();

  List<SubscriptionBillItem> _items = [];
  bool _isLoaded = false;
  final ValueNotifier<List<SubscriptionBillItem>> itemsNotifier =
      ValueNotifier([]);

  List<SubscriptionBillItem> get items => List.unmodifiable(_items);

  int get totalActiveMonthlyCents {
    return _items
        .where((item) => item.isActive)
        .fold<int>(0, (sum, item) => sum + item.monthlyAmountCents);
  }

  Future<File> _getFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/paraiz_subscriptions_bills.json');
  }

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = jsonDecode(content);
          _items = list
              .map((item) =>
                  SubscriptionBillItem.fromMap(Map<String, dynamic>.from(item)))
              .toList();
        }
      }
    } catch (_) {
      _items = [];
    }
    _isLoaded = true;
    itemsNotifier.value = List.unmodifiable(_items);
    await _syncNotifications();
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      final data = _items.map((e) => e.toMap()).toList();
      await file.writeAsString(jsonEncode(data));
      itemsNotifier.value = List.unmodifiable(_items);
    } catch (_) {}
  }

  DateTime _calculateNextBillingDate(int billingDay) {
    final now = DateTime.now();

    int lastDayThisMonth = DateTime(now.year, now.month + 1, 0).day;
    int dayThisMonth = billingDay.clamp(1, lastDayThisMonth);
    DateTime candidate = DateTime(now.year, now.month, dayThisMonth);

    DateTime reminder =
        DateTime(candidate.year, candidate.month, candidate.day - 2, 10, 0);

    if (reminder.isAfter(now)) {
      return candidate;
    }

    int nextMonth = now.month == 12 ? 1 : now.month + 1;
    int nextYear = now.month == 12 ? now.year + 1 : now.year;
    int lastDayNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    int dayNextMonth = billingDay.clamp(1, lastDayNextMonth);
    return DateTime(nextYear, nextMonth, dayNextMonth);
  }

  /// Hatırlatıcı kurulamasa bile (izin yok, platform desteği yok) fatura kaydı etkilenmez.
  Future<void> _scheduleNotificationForItem(SubscriptionBillItem item) async {
    try {
      await _scheduleNotificationForItemUnsafe(item);
    } catch (e) {
      debugPrint('Fatura hatırlatıcısı kurulamadı: $e');
    }
  }

  Future<void> _scheduleNotificationForItemUnsafe(
      SubscriptionBillItem item) async {
    final notifId = NotificationService.stableId('bill|${item.id}');
    if (!item.isActive) {
      await NotificationService.instance.cancel(notifId);
      return;
    }

    final nextBillingDate = _calculateNextBillingDate(item.billingDayOfMonth);
    final reminderDate = DateTime(
      nextBillingDate.year,
      nextBillingDate.month,
      nextBillingDate.day - 2,
      10,
      0,
    );

    final dayStr = nextBillingDate.day.toString().padLeft(2, '0');
    final monthStr = nextBillingDate.month.toString().padLeft(2, '0');
    final yearStr = nextBillingDate.year.toString();
    final formattedDate = '$dayStr.$monthStr.$yearStr';
    final formattedAmount =
        CurrencyNormalizer.formatCents(item.monthlyAmountCents);

    await NotificationService.instance.scheduleOneShot(
      id: notifId,
      title: item.title,
      body: '$formattedAmount son ödeme $formattedDate',
      when: reminderDate,
    );
  }

  Future<void> _syncNotifications() async {
    for (final item in _items) {
      await _scheduleNotificationForItem(item);
    }
  }

  Future<void> addBill(SubscriptionBillItem item) async {
    await load();
    // İlk hatırlatıcıdan önce Android 13+ bildirim iznini iste
    try {
      await NotificationService.instance.requestPermission();
    } catch (_) {}
    _items.removeWhere((x) => x.id == item.id);
    _items.add(item);
    await _save();
    await _scheduleNotificationForItem(item);
  }

  Future<void> toggleActive(String id) async {
    await load();
    final index = _items.indexWhere((x) => x.id == id);
    if (index != -1) {
      final current = _items[index];
      final updated = current.copyWith(isActive: !current.isActive);
      _items[index] = updated;
      await _save();
      await _scheduleNotificationForItem(updated);
    }
  }

  Future<void> deleteBill(String id) async {
    await load();
    _items.removeWhere((x) => x.id == id);
    await _save();
    try {
      await NotificationService.instance
          .cancel(NotificationService.stableId('bill|$id'));
    } catch (_) {}
  }

  Future<void> clearAll() async {
    for (final item in _items) {
      try {
        await NotificationService.instance
            .cancel(NotificationService.stableId('bill|${item.id}'));
      } catch (_) {}
    }
    _items.clear();
    await _save();
  }
}
