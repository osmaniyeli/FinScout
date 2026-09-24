import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/features/cashflow_projection/services/wallet_history_service.dart';

void main() {
  group('allocateCardPayments (Cüzdan çift sayım)', () {
    test('iki farklı banka kartı: ödeme yalnız kendi bankasının kartına düşer', () {
      final r = allocateCardPayments(
        cards: [
          (accountId: 'yk', bankName: 'Yapı Kredi', periodEnd: '2026-09-01'),
          (accountId: 'gb', bankName: 'Garanti BBVA', periodEnd: '2026-09-01'),
        ],
        payments: [
          (date: '2026-09-10', description: 'Yapı Kredi kart ödemesi', amountCents: 100000),
        ],
      );
      expect(r['yk'], 100000);
      expect(r['gb'], 0);
    });

    test('banka adı yoksa ve birden çok kart varsa düşülmez', () {
      final r = allocateCardPayments(
        cards: [
          (accountId: 'yk', bankName: 'Yapı Kredi', periodEnd: '2026-09-01'),
          (accountId: 'gb', bankName: 'Garanti BBVA', periodEnd: '2026-09-01'),
        ],
        payments: [
          (date: '2026-09-10', description: 'KREDI KARTI ODEMESI', amountCents: 5000),
        ],
      );
      expect(r.values.fold<int>(0, (a, b) => a + b), 0);
    });

    test('tek kart: banka adı olmasa da o karta bir kez düşer', () {
      final r = allocateCardPayments(
        cards: [(accountId: 'yk', bankName: 'Yapı Kredi', periodEnd: '2026-09-01')],
        payments: [
          (date: '2026-09-10', description: 'KREDI KARTI ODEMESI', amountCents: 5000),
          (date: '2026-08-20', description: 'KREDI KARTI ODEMESI', amountCents: 7000),
        ],
      );
      expect(r['yk'], 5000); // ekstre öncesi ödeme sayılmaz
    });

    test('aynı bankanın iki kartı: ödeme toplamda bir kez sayılır', () {
      final r = allocateCardPayments(
        cards: [
          (accountId: 'yk1', bankName: 'Yapı Kredi', periodEnd: '2026-09-01'),
          (accountId: 'yk2', bankName: 'Yapı Kredi', periodEnd: '2026-09-05'),
        ],
        payments: [
          (date: '2026-09-10', description: 'Yapı Kredi kart ödemesi', amountCents: 2000),
        ],
      );
      expect(r.values.fold<int>(0, (a, b) => a + b), 2000);
    });
  });
}
