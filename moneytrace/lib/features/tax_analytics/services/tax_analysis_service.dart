// lib/features/tax_analytics/services/tax_analysis_service.dart

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/transaction_repository.dart';

/// Bir bordronun dökümü: brüt → yasal kesintiler → net.
class PayslipBreakdown {
  final DateTime date;
  final String employer;
  final int? grossCents;
  final int netCents;
  final List<(String label, int cents)> deductions;

  const PayslipBreakdown({
    required this.date,
    required this.employer,
    required this.grossCents,
    required this.netCents,
    required this.deductions,
  });

  int get legalDeductionsCents => deductions.fold(0, (s, d) => s + d.$2);

  /// Brüt − yasal kesintiler − net: BES, avans, sendika, icra vb. (bordroda ayrı okunmayan kalemler)
  int get otherDeductionsCents {
    final g = grossCents;
    if (g == null) return 0;
    final rest = g - netCents - legalDeductionsCents;
    return rest > 0 ? rest : 0;
  }
}

/// Bir kategorideki harcamanın içindeki tahmini KDV.
class VatEstimate {
  final String categoryName;
  final int spentCents;
  final double rate;
  final bool
      approximate; // karma oranlı kategori (ör. market: %1 gıda + %20 temizlik)
  const VatEstimate(
      this.categoryName, this.spentCents, this.rate, this.approximate);

  /// KDV dahil tutardan KDV payı: tutar × r / (1 + r)
  int get vatCents => (spentCents * rate / (1 + rate)).round();
}

class TaxAnalysis {
  final DateTime from;
  final List<PayslipBreakdown> payslips;
  final Map<String, int> payrollTaxes; // Gelir vergisi, damga, SGK, işsizlik
  final Map<String, int>
      bankTaxes; // BSMV, KKDF, MTV, diğer vergi/harç (ekstre satırları)
  final List<VatEstimate> vat;

  const TaxAnalysis({
    required this.from,
    required this.payslips,
    required this.payrollTaxes,
    required this.bankTaxes,
    required this.vat,
  });

  int get payrollTotal => payrollTaxes.values.fold(0, (s, v) => s + v);
  int get bankTotal => bankTaxes.values.fold(0, (s, v) => s + v);
  int get vatTotal => vat.fold(0, (s, v) => s + v.vatCents);
  int get grandTotal => payrollTotal + bankTotal + vatTotal;
  bool get isEmpty => payslips.isEmpty && bankTotal == 0 && vat.isEmpty;

  /// Oran → (harcama, KDV)
  Map<double, (int spent, int vat)> get vatByRate {
    final out = <double, (int, int)>{};
    for (final v in vat) {
      final cur = out[v.rate] ?? (0, 0);
      out[v.rate] = (cur.$1 + v.spentCents, cur.$2 + v.vatCents);
    }
    return out;
  }
}

/// Kullanıcının devlete ödediği vergileri türüne göre toplar:
///  • Bordro: gelir vergisi, damga vergisi, SGK ve işsizlik primi (bordrodan okunan gerçek tutarlar)
///  • Banka: ekstrelerdeki BSMV, KKDF, MTV ve vergi dairesi ödemeleri (gerçek satırlar)
///  • Alışveriş: kategoriye göre yürürlükteki KDV oranıyla TAHMİNİ KDV (fişte yazan değil)
class TaxAnalysisService {
  final AppDatabase _db;
  TaxAnalysisService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  static const payrollLabels = {
    'INCOME_TAX': 'Gelir Vergisi',
    'STAMP_TAX': 'Damga Vergisi',
    'SGK_WORKER': 'SGK İşçi Payı',
    'UNEMPLOYMENT': 'İşsizlik Sigortası',
  };

  /// Kategori → (KDV oranı, karma mı). Listede olmayan kategoriler KDV'siz sayılır
  /// (maaş, transfer, kart ödemesi, yatırım, altın, kredi, faiz/banka ücreti (BSMV'li), sigorta (BSMV'li), vergi).
  static const Map<String, (double, bool)> vatRates = {
    'cat_market': (
      0.08,
      true
    ), // temel gıda %1, diğer gıda %10, temizlik/kozmetik %20
    'cat_fuel': (0.20, false), // ÖTV ayrıca vardır, dahil edilmedi
    'cat_transit': (0.20, true), // taksi/uçak %20, toplu taşıma farklı
    'cat_dining': (0.10, false),
    'cat_subscriptions': (0.20, false),
    'cat_utilities': (
      0.20,
      true
    ), // elektrik/doğalgaz/telefon %20, su farklı olabilir
    'cat_home': (0.20, false),
    'cat_pet': (0.20, false),
    'cat_kids': (0.20, true),
    'cat_clothing': (0.10, false),
    'cat_health': (0.10, false), // ilaç ve özel sağlık hizmeti
    'cat_shopping': (0.20, true),
    'cat_electronics': (0.20, false),
    'cat_education': (0.10, true), // kitap istisna, özel eğitim %10
    'cat_travel': (0.10, true), // konaklama %10, yurt içi uçuş %20
    'cat_personal_care': (0.20, false),
    'cat_auto_repair': (0.20, false),
    'cat_general': (0.20, true),
  };

  Future<TaxAnalysis> load({int months = 12, DateTime? now}) async {
    final db = await _db.database;
    final today = now ?? DateTime.now();
    final from = DateTime(today.year, today.month - (months - 1), 1);
    final fromIso = from.toIso8601String().substring(0, 10);

    // --- Bordrolar (tüm zamanlar; döküm listesi) ---
    final slipRows = await db.rawQuery('''
      SELECT t.id, t.transaction_date, t.clean_merchant, t.billing_amount_cents, t.original_amount_cents
      FROM transactions t
      WHERE EXISTS (SELECT 1 FROM tax_deductions d WHERE d.transaction_id = t.id
                    AND d.tax_type IN ('INCOME_TAX','STAMP_TAX','SGK_WORKER','UNEMPLOYMENT'))
      ORDER BY t.transaction_date DESC
    ''');
    final dedRows = await db.rawQuery('''
      SELECT transaction_id, tax_type, amount_cents FROM tax_deductions
      WHERE tax_type IN ('INCOME_TAX','STAMP_TAX','SGK_WORKER','UNEMPLOYMENT')
    ''');
    final byTx = <String, List<(String, int)>>{};
    for (final d in dedRows) {
      final type = d['tax_type'] as String;
      byTx.putIfAbsent(d['transaction_id'] as String, () => []).add(
          (payrollLabels[type] ?? type, (d['amount_cents'] as num).toInt()));
    }

    final payslips = <PayslipBreakdown>[];
    final payroll = <String, int>{};
    for (final r in slipRows) {
      final date = DateTime.parse(r['transaction_date'] as String);
      final deductions = byTx[r['id']] ?? const <(String, int)>[];
      payslips.add(PayslipBreakdown(
        date: date,
        employer: r['clean_merchant'] as String,
        grossCents: (r['original_amount_cents'] as num?)?.toInt(),
        netCents: (r['billing_amount_cents'] as num).toInt(),
        deductions: deductions,
      ));
      if (!date.isBefore(from)) {
        for (final d in deductions) {
          payroll[d.$1] = (payroll[d.$1] ?? 0) + d.$2;
        }
      }
    }

    // --- Ekstrelerdeki vergi satırları ---
    final taxRows = await db.rawQuery('''
      SELECT raw_description, billing_amount_cents FROM transactions
      WHERE tx_kind = 'TAX' AND transaction_type = 'DEBIT' AND transaction_date >= ?
    ''', [fromIso]);
    final bank = <String, int>{};
    for (final r in taxRows) {
      final label = _bankTaxLabel(r['raw_description'] as String);
      bank[label] =
          (bank[label] ?? 0) + (r['billing_amount_cents'] as num).toInt();
    }

    // --- Harcamalardaki tahmini KDV (iadeler düşülür) ---
    final catRows = await db.rawQuery('''
      SELECT t.category_id, COALESCE(c.name, t.category_id) AS name,
             SUM(CASE WHEN t.transaction_type = 'DEBIT' THEN t.billing_amount_cents ELSE -t.billing_amount_cents END) AS spent
      FROM transactions t LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.transaction_date >= ?
        AND t.tx_kind NOT IN ${TransactionRepository.neutralKindsSql}
        AND (t.transaction_type = 'DEBIT' OR t.tx_kind = 'REFUND')
      GROUP BY t.category_id
    ''', [fromIso]);
    final vat = <VatEstimate>[];
    for (final r in catRows) {
      final rate = vatRates[r['category_id']];
      final spent = (r['spent'] as num?)?.toInt() ?? 0;
      if (rate == null || spent <= 0) continue;
      vat.add(VatEstimate(r['name'] as String, spent, rate.$1, rate.$2));
    }
    vat.sort((a, b) => b.vatCents.compareTo(a.vatCents));

    return TaxAnalysis(
        from: from,
        payslips: payslips,
        payrollTaxes: payroll,
        bankTaxes: bank,
        vat: vat);
  }

  static String _bankTaxLabel(String raw) {
    final u = raw
        .toUpperCase()
        .replaceAll('İ', 'I')
        .replaceAll('Ş', 'S')
        .replaceAll('Ğ', 'G');
    if (u.contains('BSMV')) return 'BSMV';
    if (u.contains('KKDF')) return 'KKDF';
    if (u.contains('MOTORLU') || RegExp(r'\bMTV\b').hasMatch(u)) return 'MTV';
    if (u.contains('DAMGA')) return 'Damga Vergisi';
    return 'Diğer Vergi & Harç';
  }
}
