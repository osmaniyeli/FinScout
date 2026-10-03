// test/audit_qa_payment_reminder_test.dart
//
// DENETİM (QA 3/5) — Ödeme hatırlatıcısı zamanlaması: NotificationService.syncUpcomingPayments.
// Kural (notification_service.dart): hatırlatma son ödemeden 2 gün önce saat 10:00'da kurulur;
// o an geçmişse son ödeme günü 09:00'a düşer; o da geçmişse hiç kurulmaz.
//
// Üretim kodu DEĞİŞTİRİLMEDEN test edilir: flutter_test'te defaultTargetPlatform = android olduğundan
// eklenti AndroidFlutterLocalNotificationsPlugin yolunu izler; bu sınıf kayıt edilip
// 'dexterous.com/flutter/local_notifications' MethodChannel'ı sahte bir işleyiciyle dinlenir ve
// zonedSchedule'a giden GERÇEK argümanlar (id, başlık, gövde, zaman + saat dilimi) yakalanır.
// flutter_timezone kanalı 'Europe/Istanbul' döndürür (cihazın gerçek dilimi gibi).
//
// Zaman karşılaştırmaları ANLIK (instant) üzerinden yapılır: "cihaz yerel saatiyle 10:00" kuralı,
// test makinesinin saat dilimi ne olursa olsun DateTime(y, m, d, 10) ile aynı anı göstermelidir.

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneytrace/core/services/notification_service.dart';

const _notifChannel =
    MethodChannel('dexterous.com/flutter/local_notifications');
const _tzChannel = MethodChannel('flutter_timezone');

final List<Map<String, Object?>> _scheduled = [];

String _day(DateTime d) => d.toIso8601String().split('T')[0];

Map<String, dynamic> _payment(DateTime due,
        {String description = 'Yapı Kredi kart borcu',
        int amount = 250000,
        int? minimum}) =>
    {
      'due_date': _day(due),
      'description': description,
      'amount_cents': amount,
      'minimum_cents': minimum,
      'kind': 'CARD_DUE',
    };

/// Yakalanan zonedSchedule çağrısının ANI (UTC). scheduledDateTimeISO8601 ofset içerir.
DateTime _instantOf(Map<String, Object?> call) =>
    DateTime.parse(call['scheduledDateTimeISO8601'] as String).toUtc();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_notifChannel, (call) async {
      if (call.method == 'zonedSchedule') {
        _scheduled.add(Map<String, Object?>.from(call.arguments as Map));
      }
      if (call.method == 'initialize') return true;
      return null;
    });
    messenger.setMockMethodCallHandler(_tzChannel, (call) async {
      if (call.method == 'getLocalTimezone') return 'Europe/Istanbul';
      return null;
    });
  });

  setUp(_scheduled.clear);

  test(
      'vadeye 10 gün var: hatırlatma son ödemeden 2 gün önce 10:00 (cihaz yerel saati)',
      () async {
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day + 10);
    await NotificationService.instance.syncUpcomingPayments([_payment(due)]);

    expect(_scheduled, hasLength(1));
    final call = _scheduled.single;
    expect(_instantOf(call),
        DateTime(due.year, due.month, due.day - 2, 10).toUtc());
    expect(call['timeZoneName'], 'Europe/Istanbul');
    expect(call['title'], 'Yapı Kredi kart borcu');
    final dd = due.day.toString().padLeft(2, '0');
    final mm = due.month.toString().padLeft(2, '0');
    expect(call['body'], '₺2.500,00 son ödeme $dd.$mm.${due.year}');
  });

  test('asgari ödeme varsa gövdeye eklenir, 0 ise eklenmez', () async {
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day + 15);
    await NotificationService.instance.syncUpcomingPayments([
      _payment(due,
          description: 'A kart borcu', amount: 123456, minimum: 24691),
      _payment(due, description: 'B kart borcu', amount: 100, minimum: 0),
    ]);
    expect(_scheduled, hasLength(2));
    expect(_scheduled[0]['body'] as String, endsWith('(asgari ₺246,91)'));
    expect((_scheduled[0]['body'] as String).startsWith('₺1.234,56 son ödeme'),
        isTrue);
    expect(_scheduled[1]['body'] as String, isNot(contains('asgari')));
  });

  test('vadeye 1 gün var (2 gün öncesi geçmiş): son ödeme günü 09:00',
      () async {
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day + 1);
    await NotificationService.instance.syncUpcomingPayments([_payment(due)]);
    expect(_scheduled, hasLength(1));
    expect(_instantOf(_scheduled.single),
        DateTime(due.year, due.month, due.day, 9).toUtc());
  });

  test('vade bugün: 09:00 henüz gelmediyse 09:00, geçtiyse hiç kurulmaz',
      () async {
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day);
    await NotificationService.instance.syncUpcomingPayments([_payment(due)]);
    final nineToday = DateTime(now.year, now.month, now.day, 9);
    if (DateTime.now().isBefore(nineToday)) {
      expect(_scheduled, hasLength(1));
      expect(_instantOf(_scheduled.single), nineToday.toUtc());
    } else {
      expect(_scheduled, isEmpty,
          reason: 'Geçmiş bir ana hatırlatma kurulmamalı');
    }
  });

  test(
      'geçmiş vade: hatırlatma kurulmaz (eklenti "geçmiş tarih" hatası da fırlatılmaz)',
      () async {
    final now = DateTime.now();
    await NotificationService.instance.syncUpcomingPayments([
      _payment(DateTime(now.year, now.month, now.day - 1)),
      _payment(DateTime(now.year, now.month - 2, 15)),
    ]);
    expect(_scheduled, isEmpty);
  });

  test(
      'ay/yıl sınırı: 1 Mart → 27 Şubat (artık olmayan yıl), 1 Mart 2028 → 28 Şubat (artık), 1 Ocak → 30 Aralık',
      () async {
    final y = DateTime.now().year + 1; // her zaman gelecekte
    final nonLeap =
        y % 4 == 0 ? y + 1 : y; // 4'e bölünmeyen (bu aralıkta artık değil)
    final leap = y +
        (4 - y % 4) %
            4; // >= y olan ilk artık yıl (2100 kuralı bu aralıkta devreye girmez)
    await NotificationService.instance.syncUpcomingPayments([
      _payment(DateTime(nonLeap, 3, 1), description: 'mart-normal'),
      _payment(DateTime(leap, 3, 1), description: 'mart-artik'),
      _payment(DateTime(y, 1, 1), description: 'ocak'),
      _payment(DateTime(y, 5, 31), description: 'mayis-son'),
    ]);
    expect(_scheduled, hasLength(4));
    final byTitle = {for (final c in _scheduled) c['title']: _instantOf(c)};
    expect(byTitle['mart-normal'], DateTime(nonLeap, 2, 27, 10).toUtc());
    expect(byTitle['mart-artik'], DateTime(leap, 2, 28, 10).toUtc());
    expect(byTitle['ocak'], DateTime(y - 1, 12, 30, 10).toUtc());
    expect(byTitle['mayis-son'], DateTime(y, 5, 29, 10).toUtc());
  });

  test('bozuk/eksik due_date tek satırı atlar, diğerleri yine kurulur',
      () async {
    final now = DateTime.now();
    final good = DateTime(now.year, now.month, now.day + 20);
    await NotificationService.instance.syncUpcomingPayments([
      {'due_date': null, 'description': 'yok', 'amount_cents': 1},
      {'due_date': '', 'description': 'bos', 'amount_cents': 1},
      {'due_date': '31.12.2099', 'description': 'tr-bicim', 'amount_cents': 1},
      _payment(good, description: 'iyi'),
    ]);
    expect(_scheduled.map((c) => c['title']), ['iyi']);
  });

  test(
      'aynı ödeme tekrar senkronlanınca aynı kimlik (stableId) kullanılır — çift bildirim olmaz',
      () async {
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day + 12);
    await NotificationService.instance.syncUpcomingPayments([_payment(due)]);
    await NotificationService.instance.syncUpcomingPayments([_payment(due)]);
    expect(_scheduled, hasLength(2));
    expect(_scheduled[0]['id'], _scheduled[1]['id']);
    expect(
        NotificationService.stableId('x'), NotificationService.stableId('x'));
    expect(NotificationService.stableId('x'), greaterThanOrEqualTo(0));
    expect(NotificationService.stableId('x'), lessThanOrEqualTo(0x7FFFFFFF));
  });

  test(
    'aynı bankanın İKİ FARKLI kartı aynı gün son ödemeli: iki ayrı hatırlatma kimliği olmalı',
    () async {
      // getUpcomingPayments açıklamayı `institution_name || ' kart borcu'` olarak üretir; iki YK kartı
      // aynı açıklamayı taşır. Kimlik yalnız 'pay|tarih|açıklama' olduğundan ikinci kart birincinin
      // bildirimini EZER (aynı id ile zonedSchedule = güncelleme) ve kullanıcı tek hatırlatma alır.
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, now.day + 9);
      await NotificationService.instance.syncUpcomingPayments([
        _payment(due, amount: 500000),
        _payment(due, amount: 120000),
      ]);
      expect(_scheduled, hasLength(2));
      expect(_scheduled[0]['id'], isNot(_scheduled[1]['id']),
          reason: 'İki farklı kartın borcu tek bildirime çökmemeli');
    },
    skip:
        'BULGU QA-P3-01: NotificationService.syncUpcomingPayments kimliği stableId("pay|due_date|description") '
        '— aynı bankanın iki kartı aynı son ödeme gününde aynı kimliği alır, ikinci bildirim birinciyi ezer. '
        'Kimliğe hesap/kart (account_id) ya da tutar eklenmeli. Bkz. docs/audit/test-results.md',
  );
}
