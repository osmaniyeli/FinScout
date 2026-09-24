// lib/features/tax_analytics/services/tax_analysis_service.dart

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/transaction_repository.dart';

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

/// Alışverişlerdeki TAHMİNİ KDV. Gerçek ödenen vergi değildir; Masraflar'daki
/// gerçek toplamlarla (banka maliyeti / ödenen vergi / prim) asla toplanmaz.
class TaxAnalysis {
  final DateTime from;
  final DateTime to;
  final List<VatEstimate> vat;

  /// Tahmine girmeyen harcamalar (dürüstlük notu için):
  /// döviz cinsinden harcamalar ve sınıflanamayan ('cat_general') harcamalar.
  final int excludedForeignCents;
  final int excludedUnclassifiedCents;

  const TaxAnalysis({
    required this.from,
    required this.to,
    required this.vat,
    this.excludedForeignCents = 0,
    this.excludedUnclassifiedCents = 0,
  });

  int get vatTotal => vat.fold(0, (s, v) => s + v.vatCents);
  int get spentTotal => vat.fold(0, (s, v) => s + v.spentCents);
  bool get isEmpty => vat.isEmpty;

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

/// Harcamalardaki KDV'yi kategoriye göre yürürlükteki oranla TAHMİN eder (fişte yazan değil).
/// Bordro kesintileri ve ekstrelerdeki vergi satırları artık FeeReportService'te (Masraflar).
class TaxAnalysisService {
  final AppDatabase _db;
  TaxAnalysisService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  /// Kategori → (KDV oranı, karma mı). Listede olmayan kategoriler tahmine girmez
  /// (maaş, transfer, kart ödemesi, yatırım, altın, kredi, faiz/banka ücreti (BSMV'li), sigorta (BSMV'li), vergi).
  /// 'cat_general' (sınıflanamayan) bilerek yok: içeriği bilinmeyen harcamaya oran varsayılmaz.
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
  };

  /// [from] dahil, [to] hariç dönemdeki harcamaların tahmini KDV'si (iadeler düşülür).
  Future<TaxAnalysis> load({required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    String day(DateTime d) => d.toIso8601String().substring(0, 10);

    // is_foreign: kart TL'ye çevirmiş olsa da işlem döviz cinsindense (yurt dışı/döviz alışveriş)
    // Türkiye KDV'si içermez; hesaba katılmaz.
    final catRows = await db.rawQuery('''
      SELECT t.category_id, COALESCE(c.name, t.category_id) AS name,
             CASE WHEN UPPER(COALESCE(NULLIF(TRIM(t.original_currency), ''), 'TRY')) IN ('TRY', 'TL')
                   AND UPPER(COALESCE(t.billing_currency, 'TRY')) IN ('TRY', 'TL')
                  THEN 0 ELSE 1 END AS is_foreign,
             SUM(CASE WHEN t.transaction_type = 'DEBIT' THEN t.billing_amount_cents ELSE -t.billing_amount_cents END) AS spent
      FROM transactions t LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.transaction_date >= ? AND t.transaction_date < ?
        AND t.tx_kind NOT IN ${TransactionRepository.neutralKindsSql}
        AND (t.transaction_type = 'DEBIT' OR t.tx_kind = 'REFUND')
      GROUP BY t.category_id, is_foreign
    ''', [day(from), day(to)]);

    final vat = <VatEstimate>[];
    var foreign = 0;
    var unclassified = 0;
    for (final r in catRows) {
      final spent = (r['spent'] as num?)?.toInt() ?? 0;
      if (spent <= 0) continue;
      if (r['is_foreign'] == 1) {
        foreign += spent;
        continue;
      }
      if (r['category_id'] == 'cat_general') {
        unclassified += spent;
        continue;
      }
      final rate = vatRates[r['category_id']];
      if (rate == null) continue;
      vat.add(VatEstimate(r['name'] as String, spent, rate.$1, rate.$2));
    }
    vat.sort((a, b) => b.vatCents.compareTo(a.vatCents));

    return TaxAnalysis(
      from: from,
      to: to,
      vat: vat,
      excludedForeignCents: foreign,
      excludedUnclassifiedCents: unclassified,
    );
  }
}
