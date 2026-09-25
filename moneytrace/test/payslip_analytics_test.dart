// test/payslip_analytics_test.dart
//
// Bordro analizi: aylık seri, yıllık toplamlar, efektif oran, zam tespiti (tek seferlik ödeme elemesi),
// eksik ay ve boş veri. Tüm tutarlar UYDURMA örnek sayılardır (gerçek bordro değildir).

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/features/analysis/services/payslip_analytics_service.dart';

/// Ayın son günü tarihli bordro satırı (parser'ın yazdığı biçim). Tutarlar TL, kuruşa çevrilir.
/// [wageCents]: bordrodaki birim ücret ("Ücreti" satırı), kuruş.
Map<String, Object?> _salary(int y, int m, int netTl, {int? grossTl, int? wageCents}) => {
      'transaction_date': DateTime(y, m + 1, 0).toIso8601String().split('T')[0],
      'billing_amount_cents': netTl * 100,
      'original_amount_cents': grossTl == null ? null : grossTl * 100,
      'base_wage_cents': wageCents,
    };

/// Yasal kesintisi olan (SGK okunmuş) ay.
List<Map<String, Object?>> _sgk(Iterable<(int, int)> months) => [
      for (final (y, m) in months) ..._taxes(y, m, sgk: 1000),
    ];

List<Map<String, Object?>> _taxes(int y, int m, {int? income, int? stamp, int? sgk, int? unemp}) {
  final date = DateTime(y, m + 1, 0).toIso8601String().split('T')[0];
  return [
    if (income != null) {'transaction_date': date, 'tax_type': 'INCOME_TAX', 'amount_cents': income * 100},
    if (stamp != null) {'transaction_date': date, 'tax_type': 'STAMP_TAX', 'amount_cents': stamp * 100},
    if (sgk != null) {'transaction_date': date, 'tax_type': 'SGK_WORKER', 'amount_cents': sgk * 100},
    if (unemp != null) {'transaction_date': date, 'tax_type': 'UNEMPLOYMENT', 'amount_cents': unemp * 100},
  ];
}

void main() {
  group('buildMonths / aylık seri', () {
    test('net, brüt ve kesinti kalemleri aya göre birleşir', () {
      final months = PayslipAnalyticsService.buildMonths(
        [_salary(2025, 1, 10000, grossTl: 14000), _salary(2025, 2, 10000, grossTl: 14000)],
        [..._taxes(2025, 1, income: 1500, stamp: 100, sgk: 1960, unemp: 140), ..._taxes(2025, 2, income: 1500)],
      );
      expect(months.length, 2);
      final jan = months.first;
      expect((jan.year, jan.month), (2025, 1));
      expect(jan.netCents, 1000000);
      expect(jan.grossCents, 1400000);
      expect(jan.taxCents, 160000);
      expect(jan.socialCents, 210000);
      expect(jan.legalCents, 370000);
      expect(jan.valueOf(PayslipMetric.deductions), 370000);
      // Şubat: yalnız gelir vergisi okunmuş; SGK uydurulmaz
      expect(months[1].socialCents, isNull);
      expect(months[1].legalCents, 150000);
      expect(months[1].hasRateData, isFalse);
    });

    test('brüt okunamayan bordroda brüt null kalır (0 değil)', () {
      final months = PayslipAnalyticsService.buildMonths([_salary(2025, 3, 9000)], const []);
      expect(months.single.netCents, 900000);
      expect(months.single.grossCents, isNull);
      expect(months.single.taxCents, isNull);
    });

    test('eksik ay grafikte boş slot olur, değer uydurulmaz', () {
      final months = PayslipAnalyticsService.buildMonths(
        [_salary(2025, 1, 10000), _salary(2025, 4, 11000)],
        const [],
      );
      final slots = PayslipAnalyticsService.monthlySlots(months);
      expect(slots.length, 4); // Ocak..Nisan
      expect(slots.map((s) => s.monthOfYear), [1, 2, 3, 4]);
      expect(slots[1].month, isNull);
      expect(slots[2].month, isNull);
      expect(slots[3].month!.netCents, 1100000);
    });

    test('yıl filtresi seçilmemiş aradaki yılı atlar', () {
      final months = PayslipAnalyticsService.buildMonths(
        [_salary(2023, 12, 8000), _salary(2024, 6, 9000), _salary(2025, 1, 10000)],
        const [],
      );
      final slots = PayslipAnalyticsService.monthlySlots(months, years: {2023, 2025});
      expect(slots.every((s) => s.year != 2024), isTrue);
      expect(slots.length, 2); // Ara 2023 + Oca 2025
      expect(PayslipAnalyticsService.filterYears(months, {2024}).single.year, 2024);
      expect(PayslipAnalyticsService.yearsOf(months), [2023, 2024, 2025]);
    });
  });

  group('tek seferlik ödemeler', () {
    test('aynı aya düşen iki bordro kaydı (ör. fark bordrosu) toplanır', () {
      final months = PayslipAnalyticsService.buildMonths(
        [_salary(2025, 6, 10000, grossTl: 14000), _salary(2025, 6, 2000, grossTl: 3000)],
        const [],
      );
      expect(months.single.netCents, 1200000);
      expect(months.single.grossCents, 1700000);
    });

    test('ikramiyeli aydaki brüt sıçraması zam sayılmaz (sonraki ay eski seviye)', () {
      final months = PayslipAnalyticsService.buildMonths([
        _salary(2025, 5, 10000, grossTl: 14000),
        _salary(2025, 6, 18000, grossTl: 26000), // tek seferlik ikramiye brütü
        _salary(2025, 7, 10000, grossTl: 14000),
        _salary(2025, 8, 10000, grossTl: 14000),
      ], const []);
      expect(PayslipAnalyticsService.detectRaises(months), isEmpty);
    });
  });

  group('zam tespiti (bordrodaki ücret)', () {
    const ym = [(2025, 1), (2025, 2), (2025, 3), (2025, 4)];

    test('ücretin artması zamdır; oran ücret değişimidir', () {
      final months = PayslipAnalyticsService.buildMonths([
        _salary(2025, 1, 10000, grossTl: 14000, wageCents: 5000),
        _salary(2025, 2, 13000, grossTl: 19000, wageCents: 5000), // fazla mesai: ücret aynı
        _salary(2025, 3, 11000, grossTl: 15400, wageCents: 5600), // %12 zam
        _salary(2025, 4, 10900, grossTl: 15400, wageCents: 5600),
      ], _sgk(ym));
      expect(months.map((m) => m.baseWageCents), [5000, 5000, 5600, 5600]);
      final r = PayslipAnalyticsService.detectRaises(months).single;
      expect((r.year, r.month), (2025, 3));
      expect((r.fromYear, r.fromMonth), (2025, 2));
      expect(r.pct, closeTo(0.12, 1e-9));
      expect((r.fromWageCents, r.toWageCents), (5000, 5600));
      expect(r.basis, 'ücret');
      expect(r.confirmed, isTrue);
    });

    test('ücret yoksa brüt/net sıçraması zam sayılmaz (tahmin yok)', () {
      final months = PayslipAnalyticsService.buildMonths([
        _salary(2025, 1, 10000, grossTl: 14000),
        _salary(2025, 2, 10000, grossTl: 14000),
        _salary(2025, 3, 11000, grossTl: 15400),
        _salary(2025, 4, 11000, grossTl: 15400),
      ], _sgk(ym));
      expect(PayslipAnalyticsService.detectRaises(months), isEmpty);
      expect(PayslipAnalyticsService.hasWageData(months), isFalse);
    });

    test('ücreti okunmayan ay çifti için zam üretilmez', () {
      final months = PayslipAnalyticsService.buildMonths([
        _salary(2025, 1, 10000, wageCents: 5000),
        _salary(2025, 2, 10000), // ücret satırı okunamadı
        _salary(2025, 3, 11000, wageCents: 5600),
        _salary(2025, 4, 11000, wageCents: 5600),
      ], _sgk(ym));
      expect(PayslipAnalyticsService.detectRaises(months), isEmpty);
      expect(PayslipAnalyticsService.hasWageData(months), isTrue);
    });

    test('kuruş düzeyi oynama eşik altıdır; ücret düşüşü zam değildir', () {
      final months = PayslipAnalyticsService.buildMonths([
        _salary(2025, 1, 10000, wageCents: 10000),
        _salary(2025, 2, 10000, wageCents: 10020), // %0,2
        _salary(2025, 3, 10000, wageCents: 9000),
        _salary(2025, 4, 10000, wageCents: 9000),
      ], _sgk(ym));
      expect(PayslipAnalyticsService.detectRaises(months), isEmpty);
    });

    test('kesintisiz ilk aylar dışlanır; kesintili ilk aydaki fark zam değildir', () {
      final months = PayslipAnalyticsService.buildMonths([
        _salary(2024, 8, 3000, wageCents: 7000), // kesintisiz (ayrı kayıt)
        _salary(2024, 9, 3000, wageCents: 7000), // kesintisiz
        _salary(2024, 10, 9000, wageCents: 5000), // kesintili ilk ay: başlangıç
        _salary(2024, 11, 9000, wageCents: 5000),
        _salary(2025, 1, 9500, wageCents: 5500), // gerçek zam
      ], [
        ..._taxes(2024, 8, income: 10, sgk: 0),
        ..._sgk([(2024, 10), (2024, 11), (2025, 1)]),
      ]);
      final raises = PayslipAnalyticsService.detectRaises(months);
      expect(raises.map((r) => (r.year, r.month)), [(2025, 1)]);
      expect((raises.single.fromYear, raises.single.fromMonth), (2024, 11));
    });

    test('yıl-yıl karşılaştırmada kesintisiz aylar ortalamaya girmez', () {
      final months = PayslipAnalyticsService.buildMonths([
        _salary(2024, 8, 1000, grossTl: 1000), // kesintisiz
        _salary(2024, 10, 8000, grossTl: 10000),
        _salary(2025, 1, 9000, grossTl: 12000),
      ], _sgk([(2024, 10), (2025, 1)]));
      final g = PayslipAnalyticsService.yearOverYear(months).single;
      expect(g.grossPct, closeTo(0.20, 1e-9));
      expect(g.netPct, closeTo(0.125, 1e-9));
    });
  });

  group('yıllık toplamlar ve oranlar', () {
    final months = PayslipAnalyticsService.buildMonths(
      [
        _salary(2024, 11, 8000, grossTl: 10000),
        _salary(2024, 12, 8000, grossTl: 10000),
        _salary(2025, 1, 9000, grossTl: 12000),
        _salary(2025, 2, 9000, grossTl: 12000),
        _salary(2025, 3, 9000, grossTl: 12000),
      ],
      [
        ..._taxes(2024, 11, income: 1000, stamp: 50, sgk: 1400, unemp: 100),
        ..._taxes(2024, 12, income: 1000, stamp: 50, sgk: 1400, unemp: 100),
        ..._taxes(2025, 1, income: 1200, stamp: 60, sgk: 1680, unemp: 120),
        ..._taxes(2025, 2, income: 1200, stamp: 60, sgk: 1680, unemp: 120),
        ..._taxes(2025, 3, income: 1200, stamp: 60, sgk: 1680, unemp: 120),
      ],
    );

    test('yıllık toplam yalnız bordrosu olan ayları toplar', () {
      final years = PayslipAnalyticsService.yearlyTotals(months);
      expect(years.map((y) => y.year), [2024, 2025]);
      expect(years[0].monthsCovered, 2);
      expect(years[0].netCents, 1600000);
      expect(years[0].grossCents, 2000000);
      expect(years[0].taxCents, 210000);
      expect(years[1].legalCents, 3 * 306000);
      expect(years[1].avgMonthlyGrossCents, 1200000);
    });

    test('efektif kesinti oranı = yasal kesinti / brüt', () {
      expect(PayslipAnalyticsService.effectiveRate(months), closeTo((2 * 2550 + 3 * 3060) / (2 * 10000 + 3 * 12000), 1e-9));
      expect(PayslipAnalyticsService.totalTax(months), (2 * 1050 + 3 * 1260) * 100);
      expect(PayslipAnalyticsService.totalSocial(months), (2 * 1500 + 3 * 1800) * 100);
    });

    test('yıl-yıl artış aylık ortalamadan (kısmi yıl yanıltmasın)', () {
      final g = PayslipAnalyticsService.yearOverYear(months).single;
      expect((g.fromYear, g.toYear), (2024, 2025));
      expect(g.grossPct, closeTo(0.20, 1e-9));
      expect(g.netPct, closeTo(0.125, 1e-9));
    });

    test('en yüksek ay seçili ölçüye göre', () {
      final peak = PayslipAnalyticsService.peakMonth(months, PayslipMetric.tax)!;
      expect(peak.year, 2025);
      expect(PayslipAnalyticsService.peakMonth(months, PayslipMetric.net)!.year, 2025);
    });
  });

  group('boş / eksik veri', () {
    test('bordro yoksa her şey boş veya null', () {
      final months = PayslipAnalyticsService.buildMonths(const [], const []);
      expect(months, isEmpty);
      expect(PayslipAnalyticsService.monthlySlots(months), isEmpty);
      expect(PayslipAnalyticsService.yearlyTotals(months), isEmpty);
      expect(PayslipAnalyticsService.effectiveRate(months), isNull);
      expect(PayslipAnalyticsService.detectRaises(months), isEmpty);
      expect(PayslipAnalyticsService.totalTax(months), isNull);
      expect(PayslipAnalyticsService.peakMonth(months, PayslipMetric.net), isNull);
      expect(PayslipAnalyticsService.yearOverYear(const []), isEmpty);
    });

    test('brüt veya ana kesinti eksikse efektif oran üretilmez', () {
      final months = PayslipAnalyticsService.buildMonths(
        [_salary(2025, 1, 10000), _salary(2025, 2, 10000, grossTl: 14000)],
        [..._taxes(2025, 1, income: 1500, sgk: 1960), ..._taxes(2025, 2, income: 1500)],
      );
      expect(PayslipAnalyticsService.effectiveRate(months), isNull);
      final y = PayslipAnalyticsService.yearlyTotals(months).single;
      expect(y.effectiveRate, isNull);
      expect(y.grossCents, 1400000); // yalnız okunan ay
    });

    test('geçersiz tarih/tutar satırları atlanır', () {
      final months = PayslipAnalyticsService.buildMonths(
        [
          {'transaction_date': null, 'billing_amount_cents': 100},
          {'transaction_date': '2025-05-31', 'billing_amount_cents': null},
        ],
        const [],
      );
      expect(months, isEmpty);
    });
  });
}
