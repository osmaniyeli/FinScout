// lib/features/analysis/services/payslip_analytics_service.dart
//
// Bordro geçmişinden maaş/vergi analizi. Veritabanı yalnız TransactionRepository üzerinden okunur;
// tüm hesaplar saf statik fonksiyonlardır (birim testlenebilir).
//
// Kural: veri yoksa değer null döner. Eksik ay tahmin edilmez, varsayılan sayı üretilmez; grafik o
// ayı boş bırakır.

import '../../../core/database/repositories/transaction_repository.dart';

/// Grafikte seçilebilen ölçü.
enum PayslipMetric {
  net('Net', 'Net maaş'),
  gross('Brüt', 'Brüt ücret'),
  tax('Vergi', 'Gelir + damga vergisi'),
  deductions('Kesintiler', 'Toplam yasal kesinti');

  const PayslipMetric(this.label, this.title);
  final String label;
  final String title;
}

/// Bir takvim ayının bordro verisi (kuruş). Bordroda okunamayan kalem null'dır.
class PayslipMonth {
  const PayslipMonth({
    required this.year,
    required this.month,
    this.netCents,
    this.grossCents,
    this.incomeTaxCents,
    this.stampTaxCents,
    this.sgkCents,
    this.unemploymentCents,
    this.baseWageCents,
  });

  final int year;
  final int month;

  /// Net ödenen (bordronun "Net Ödenen"i).
  final int? netCents;

  /// Brüt ücret (bordronun "Toplam Brüt"ü; o ay ödenen ikramiyenin brütünü içerebilir).
  final int? grossCents;
  final int? incomeTaxCents;
  final int? stampTaxCents;
  final int? sgkCents;
  final int? unemploymentCents;

  /// Bordrodaki birim ücret (saatlik/aylık "Ücreti" satırı); okunamadıysa null.
  final int? baseWageCents;

  int get key => year * 12 + (month - 1);

  static int? _sumKnown(List<int?> values) {
    final known = values.whereType<int>();
    return known.isEmpty ? null : known.fold<int>(0, (a, b) => a + b);
  }

  /// Gelir vergisi + damga vergisi.
  int? get taxCents => _sumKnown([incomeTaxCents, stampTaxCents]);

  /// SGK işçi payı + işsizlik sigortası.
  int? get socialCents => _sumKnown([sgkCents, unemploymentCents]);

  /// Bordrodan okunan yasal kesintilerin toplamı.
  int? get legalCents => _sumKnown([incomeTaxCents, stampTaxCents, sgkCents, unemploymentCents]);

  /// Efektif oran hesabına girecek kadar veri var mı (brüt + ana kesintiler okunmuş).
  bool get hasRateData => grossCents != null && incomeTaxCents != null && sgkCents != null;

  /// SGK kesintisi okunmuş (sıfırdan büyük) ay. Kesintisiz aylar (ör. işe giriş öncesi/staj dönemi
  /// ödemeleri) farklı bir kayıttır; zam ve yıl-yıl karşılaştırmasına girmez.
  bool get hasLegalDeductions => (sgkCents ?? 0) > 0;

  int? valueOf(PayslipMetric metric) => switch (metric) {
        PayslipMetric.net => netCents,
        PayslipMetric.gross => grossCents,
        PayslipMetric.tax => taxCents,
        PayslipMetric.deductions => legalCents,
      };
}

/// Grafikte bir ay: [month] null ise o ayın bordrosu yüklenmemiştir (boşluk).
class PayslipSlot {
  const PayslipSlot(this.year, this.monthOfYear, this.month);
  final int year;
  final int monthOfYear;
  final PayslipMonth? month;
}

/// Yıllık toplamlar. Yalnız bordrosu olan aylar toplanır; [monthsCovered] kaç ay olduğunu söyler.
class PayslipYear {
  const PayslipYear({
    required this.year,
    required this.monthsCovered,
    this.netCents,
    this.grossCents,
    this.taxCents,
    this.socialCents,
    this.legalCents,
    this.avgMonthlyNetCents,
    this.avgMonthlyGrossCents,
    this.effectiveRate,
  });

  final int year;
  final int monthsCovered;
  final int? netCents;
  final int? grossCents;
  final int? taxCents;
  final int? socialCents;
  final int? legalCents;
  final int? avgMonthlyNetCents;
  final int? avgMonthlyGrossCents;
  final double? effectiveRate;

  int? valueOf(PayslipMetric metric) => switch (metric) {
        PayslipMetric.net => netCents,
        PayslipMetric.gross => grossCents,
        PayslipMetric.tax => taxCents,
        PayslipMetric.deductions => legalCents,
      };
}

/// Zam: bordrodaki birim ücretin bir önceki bordroya göre artması.
class PayslipRaise {
  const PayslipRaise({
    required this.year,
    required this.month,
    required this.fromYear,
    required this.fromMonth,
    required this.pct,
    required this.fromWageCents,
    required this.toWageCents,
    this.basis = basisWage,
    this.confirmed = true,
  });

  static const String basisWage = 'ücret';

  final int year;
  final int month;
  final int fromYear;
  final int fromMonth;

  /// Ücret değişim oranı (0.12 = %12).
  final double pct;

  /// Önceki ve yeni birim ücret (kuruş).
  final int fromWageCents;
  final int toWageCents;

  /// Tespitin dayanağı; yalnız bordrodaki ücret satırı ('ücret').
  final String basis;

  /// Ücret bordroya basılı olduğundan tespit kesindir.
  final bool confirmed;
}

/// İki yıl arasında aylık ortalama değişimi (kısmi yıllar karşılaştırılabilsin diye ortalama).
class PayslipYearGrowth {
  const PayslipYearGrowth({required this.fromYear, required this.toYear, this.grossPct, this.netPct});
  final int fromYear;
  final int toYear;
  final double? grossPct;
  final double? netPct;
}

class PayslipAnalyticsService {
  PayslipAnalyticsService({TransactionRepository? repository}) : _repository = repository ?? TransactionRepository();

  final TransactionRepository _repository;

  /// Zam sayılacak en küçük birim ücret artışı (önceki bordroya göre; kuruş yuvarlamasını eler).
  static const double minRaisePct = 0.005;

  Future<List<PayslipMonth>> loadMonths() async {
    final rows = await _repository.getPayslipRows();
    return buildMonths(rows.incomes, rows.taxes);
  }

  // ---------------------------------------------------------------------------
  // Saf hesaplar
  // ---------------------------------------------------------------------------

  static (int, int)? _yearMonth(Object? isoDate) {
    if (isoDate is! String || isoDate.length < 7) return null;
    final y = int.tryParse(isoDate.substring(0, 4));
    final m = int.tryParse(isoDate.substring(5, 7));
    if (y == null || m == null || m < 1 || m > 12) return null;
    return (y, m);
  }

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  /// Veritabanı satırlarından aylık bordro kayıtları (tarihe göre sıralı).
  /// [incomes]: transaction_date, billing_amount_cents, original_amount_cents.
  /// [taxes]: transaction_date, tax_type, amount_cents.
  static List<PayslipMonth> buildMonths(List<Map<String, Object?>> incomes, List<Map<String, Object?>> taxes) {
    final net = <int, int>{};
    final gross = <int, int>{};
    final grossMissing = <int>{};
    final wage = <int, int>{};
    final byType = <String, Map<int, int>>{};
    final keys = <int>{};

    int keyOf((int, int) ym) => ym.$1 * 12 + (ym.$2 - 1);

    for (final r in incomes) {
      final ym = _yearMonth(r['transaction_date']);
      final amount = _int(r['billing_amount_cents']);
      if (ym == null || amount == null) continue;
      final k = keyOf(ym);
      keys.add(k);
      net[k] = (net[k] ?? 0) + amount;
      final g = _int(r['original_amount_cents']);
      if (g == null || g <= 0) {
        grossMissing.add(k); // bir bordronun brütü yoksa o ayın brüt toplamı eksik kalırdı: hiç gösterme
      } else {
        gross[k] = (gross[k] ?? 0) + g;
      }
      // Aynı aya iki bordro düşerse (fark bordrosu) birim ücret toplanmaz; yüksek olan geçerlidir
      final w = _int(r['base_wage_cents']);
      if (w != null && w > 0 && w > (wage[k] ?? 0)) wage[k] = w;
    }

    for (final r in taxes) {
      final ym = _yearMonth(r['transaction_date']);
      final amount = _int(r['amount_cents']);
      final type = r['tax_type'];
      if (ym == null || amount == null || type is! String) continue;
      final k = keyOf(ym);
      keys.add(k);
      final m = byType.putIfAbsent(type, () => <int, int>{});
      m[k] = (m[k] ?? 0) + amount;
    }

    final sorted = keys.toList()..sort();
    return [
      for (final k in sorted)
        PayslipMonth(
          year: k ~/ 12,
          month: k % 12 + 1,
          netCents: net[k],
          grossCents: grossMissing.contains(k) ? null : gross[k],
          incomeTaxCents: byType['INCOME_TAX']?[k],
          stampTaxCents: byType['STAMP_TAX']?[k],
          sgkCents: byType['SGK_WORKER']?[k],
          unemploymentCents: byType['UNEMPLOYMENT']?[k],
          baseWageCents: wage[k],
        ),
    ];
  }

  /// Bordrosu olan yıllar (artan).
  static List<int> yearsOf(List<PayslipMonth> months) => (months.map((m) => m.year).toSet().toList()..sort());

  /// Seçili yıllar ([years] boşsa tümü).
  static List<PayslipMonth> filterYears(List<PayslipMonth> months, Set<int> years) =>
      years.isEmpty ? List.of(months) : months.where((m) => years.contains(m.year)).toList();

  /// İlk ve son bordro arasındaki her takvim ayı; bordrosu olmayan ay boş slot olarak döner.
  /// [years] verilirse yalnız o yılların ayları (aradaki seçilmemiş yıllar atlanır).
  static List<PayslipSlot> monthlySlots(List<PayslipMonth> months, {Set<int> years = const {}}) {
    final picked = filterYears(months, years);
    if (picked.isEmpty) return const [];
    final byKey = {for (final m in picked) m.key: m};
    final first = picked.map((m) => m.key).reduce((a, b) => a < b ? a : b);
    final last = picked.map((m) => m.key).reduce((a, b) => a > b ? a : b);
    return [
      for (var k = first; k <= last; k++)
        if (years.isEmpty || years.contains(k ~/ 12)) PayslipSlot(k ~/ 12, k % 12 + 1, byKey[k]),
    ];
  }

  static int? _sum(Iterable<int?> values) {
    final known = values.whereType<int>();
    return known.isEmpty ? null : known.fold<int>(0, (a, b) => a + b);
  }

  static int? _avg(Iterable<int?> values) {
    final known = values.whereType<int>().toList();
    return known.isEmpty ? null : (known.fold<int>(0, (a, b) => a + b) / known.length).round();
  }

  /// Yasal kesinti / brüt; yalnız brütü ve ana kesintileri (gelir vergisi + SGK) okunmuş aylardan.
  static double? effectiveRate(List<PayslipMonth> months) {
    final usable = months.where((m) => m.hasRateData).toList();
    if (usable.isEmpty) return null;
    final gross = usable.fold<int>(0, (a, m) => a + m.grossCents!);
    if (gross <= 0) return null;
    final legal = usable.fold<int>(0, (a, m) => a + (m.legalCents ?? 0));
    return legal / gross;
  }

  static List<PayslipYear> yearlyTotals(List<PayslipMonth> months) {
    final byYear = <int, List<PayslipMonth>>{};
    for (final m in months) {
      byYear.putIfAbsent(m.year, () => []).add(m);
    }
    final years = byYear.keys.toList()..sort();
    return [
      for (final y in years)
        PayslipYear(
          year: y,
          monthsCovered: byYear[y]!.length,
          netCents: _sum(byYear[y]!.map((m) => m.netCents)),
          grossCents: _sum(byYear[y]!.map((m) => m.grossCents)),
          taxCents: _sum(byYear[y]!.map((m) => m.taxCents)),
          socialCents: _sum(byYear[y]!.map((m) => m.socialCents)),
          legalCents: _sum(byYear[y]!.map((m) => m.legalCents)),
          avgMonthlyNetCents: _avg(byYear[y]!.map((m) => m.netCents)),
          avgMonthlyGrossCents: _avg(byYear[y]!.map((m) => m.grossCents)),
          effectiveRate: effectiveRate(byYear[y]!),
        ),
    ];
  }

  static double? _pct(int? from, int? to) => (from == null || to == null || from <= 0) ? null : (to - from) / from;

  /// Ardışık yıllar arası aylık ortalama değişim (yıl-yıl artış). Yasal kesintisi olmayan aylar
  /// (ayrı kayıt/başlangıç dönemi) ortalamaya girmez.
  static List<PayslipYearGrowth> yearOverYear(List<PayslipMonth> months) {
    final years = yearlyTotals(months.where((m) => m.hasLegalDeductions).toList());
    return [
      for (var i = 1; i < years.length; i++)
        PayslipYearGrowth(
          fromYear: years[i - 1].year,
          toYear: years[i].year,
          grossPct: _pct(years[i - 1].avgMonthlyGrossCents, years[i].avgMonthlyGrossCents),
          netPct: _pct(years[i - 1].avgMonthlyNetCents, years[i].avgMonthlyNetCents),
        ),
    ];
  }

  /// Zam tespiti: ardışık iki bordronun ikisinde de birim ücret okunmuşsa ve ücret en az [minPct]
  /// artmışsa zamdır. Brüt/net kullanılmaz (fazla mesai, bayram harçlığı, ikramiye brütü oynatır ve
  /// yanlış zam gösterir); ücreti olmayan ay çifti için zam üretilmez.
  /// Yasal kesintisi (SGK) olmayan aylar karşılaştırmaya girmez: kesintili ilk aydaki ücret farkı
  /// ayrı kayıt/başlangıçtır, zam değildir.
  static List<PayslipRaise> detectRaises(List<PayslipMonth> months, {double minPct = minRaisePct}) {
    final list = months.where((m) => m.hasLegalDeductions).toList()..sort((a, b) => a.key.compareTo(b.key));
    final raises = <PayslipRaise>[];
    for (var i = 1; i < list.length; i++) {
      final prev = list[i - 1];
      final cur = list[i];
      final from = prev.baseWageCents;
      final to = cur.baseWageCents;
      if (from == null || to == null || from <= 0) continue;
      if (to <= from * (1 + minPct)) continue;
      raises.add(PayslipRaise(
        year: cur.year,
        month: cur.month,
        fromYear: prev.year,
        fromMonth: prev.month,
        pct: (to - from) / from,
        fromWageCents: from,
        toWageCents: to,
      ));
    }
    return raises;
  }

  /// Hiç birim ücret okunmuş bordro var mı (zam tespiti yapılabilir mi).
  static bool hasWageData(List<PayslipMonth> months) => months.any((m) => m.baseWageCents != null);

  /// Seçili ölçüde en yüksek ay (değeri olmayan aylar hariç).
  static PayslipMonth? peakMonth(List<PayslipMonth> months, PayslipMetric metric) {
    PayslipMonth? best;
    for (final m in months) {
      final v = m.valueOf(metric);
      if (v == null) continue;
      if (best == null || v > best.valueOf(metric)!) best = m;
    }
    return best;
  }

  /// Aralıktaki toplam vergi (gelir + damga); veri yoksa null.
  static int? totalTax(List<PayslipMonth> months) => _sum(months.map((m) => m.taxCents));

  /// Aralıktaki toplam SGK + işsizlik; veri yoksa null.
  static int? totalSocial(List<PayslipMonth> months) => _sum(months.map((m) => m.socialCents));
}
