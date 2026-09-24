import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../utils/currency_normalizer.dart';

/// Ödeme hatırlatıcıları (fatura/abonelik, kart son ödeme, ekstre talimatları). Tamamen cihaz içi zamanlanır.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tzdata.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {}
    }

    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_stat_finscout');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: settings);

    const androidChannel = AndroidNotificationChannel(
      'payment_reminders',
      'Ödeme Hatırlatıcıları',
      description: 'Fatura, abonelik ve kredi kartı son ödeme hatırlatıcıları',
      importance: Importance.high,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
    }

    _isInitialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  Future<void> scheduleOneShot({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (when.isBefore(DateTime.now())) {
      return;
    }

    await initialize();

    final tzDateTime = tz.TZDateTime.from(when, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'payment_reminders',
      'Ödeme Hatırlatıcıları',
      channelDescription:
          'Fatura, abonelik ve kredi kartı son ödeme hatırlatıcıları',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_finscout',
      color: Color(0xFF10B981),
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDateTime,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id: id);
  }

  /// Veriler silindiğinde kurulu tüm hatırlatmaları kaldırır.
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  static int stableId(String key) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < key.length; i++) {
      hash ^= key.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  Future<void> syncUpcomingPayments(List<Map<String, dynamic>> payments) async {
    await initialize();
    for (final item in payments) {
      try {
        final dueDateStr = item['due_date'] as String?;
        if (dueDateStr == null || dueDateStr.isEmpty) continue;

        final dueDate = DateTime.parse(dueDateStr);
        final description = (item['description'] as String?) ?? 'Ödeme';
        final amountCents = (item['amount_cents'] as num?)?.toInt() ?? 0;
        final minimumCents = (item['minimum_cents'] as num?)?.toInt();

        // Normalde son ödemeden 2 gün önce; o an geçtiyse (vadeye 2 günden az kaldıysa)
        // son ödeme günü sabahı hatırlat.
        var reminderDate =
            DateTime(dueDate.year, dueDate.month, dueDate.day - 2, 10, 0);
        if (reminderDate.isBefore(DateTime.now())) {
          reminderDate = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
        }
        final id = stableId('pay|$dueDateStr|$description');

        final dayStr = dueDate.day.toString().padLeft(2, '0');
        final monthStr = dueDate.month.toString().padLeft(2, '0');
        final yearStr = dueDate.year.toString();
        final formattedDate = '$dayStr.$monthStr.$yearStr';

        final formattedAmount = CurrencyNormalizer.formatCents(amountCents);

        String body = '$formattedAmount son ödeme $formattedDate';
        if (minimumCents != null && minimumCents > 0) {
          final formattedMin = CurrencyNormalizer.formatCents(minimumCents);
          body += ' (asgari $formattedMin)';
        }

        await scheduleOneShot(
          id: id,
          title: description,
          body: body,
          when: reminderDate,
        );
      } catch (_) {}
    }
  }
}
