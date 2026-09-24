// lib/features/fees/services/fee_report_service.dart

import '../../../core/database/app_database.dart';
import '../../../core/parser/util/tr_statement_text.dart';

/// Masraf raporunun üç ana grubu. Karıştırılmaz: kart masrafı toplamı bordro kesintisiyle şişmesin.
enum FeeGroup {
  bankCost, // Bankaya ödenen: ücretler, faizler, BSMV, KKDF
  taxPaid, // Ödenen vergi: stopaj, MTV, vergi dairesi, bordro gelir/damga vergisi
  premium, // Sosyal güvenlik primi: SGK, işsizlik
}

extension FeeGroupLabel on FeeGroup {
  String get label => switch (this) {
        FeeGroup.bankCost => 'Banka maliyeti',
        FeeGroup.taxPaid => 'Ödenen vergi',
        FeeGroup.premium => 'Prim',
      };
}

/// Masraf kalemi (araştırma: belgeler_mevzuat.md, 22 kalemlik taksonomi).
enum FeeItem {
  cardAnnualFee('Kart üyelik ücreti (aidat)', FeeGroup.bankCost),
  purchaseInterest('Akdi (alışveriş) faizi', FeeGroup.bankCost),
  lateInterest('Gecikme faizi', FeeGroup.bankCost),
  cashAdvanceInterest('Nakit avans faizi', FeeGroup.bankCost),
  overdraftInterest('KMH faizi', FeeGroup.bankCost),
  cashAdvanceFee('Nakit çekim ücreti', FeeGroup.bankCost),
  transactionFee('İşlem ücreti', FeeGroup.bankCost),
  statementFee('Ekstre / SMS ücreti', FeeGroup.bankCost),
  transferFee('EFT / FAST / havale ücreti', FeeGroup.bankCost),
  accountFee('Hesap işletim ücreti', FeeGroup.bankCost),
  otherFee('Diğer masraf ve komisyon', FeeGroup.bankCost),
  bsmv('BSMV', FeeGroup.bankCost),
  kkdf('KKDF', FeeGroup.bankCost),
  withholding('Mevduat stopajı', FeeGroup.taxPaid),
  mtv('Motorlu taşıtlar vergisi', FeeGroup.taxPaid),
  otherTaxPayment('Vergi dairesi / harç ödemesi', FeeGroup.taxPaid),
  payrollIncomeTax('Gelir vergisi (bordro)', FeeGroup.taxPaid),
  payrollStampTax('Damga vergisi (bordro)', FeeGroup.taxPaid),
  payrollSgk('SGK işçi payı (bordro)', FeeGroup.premium),
  payrollUnemployment('İşsizlik sigortası (bordro)', FeeGroup.premium);

  const FeeItem(this.label, this.group);
  final String label;
  final FeeGroup group;
}

/// Tek bir masraf satırı. [computed] true ise tutar ekstrede ayrı satır olarak yazmıyor,
/// oranla hesaplandı (ör. "BSMV dahildir" yazan faiz satırının vergi payı).
class FeeLine {
  final DateTime date;
  final String description;
  final FeeItem item;
  final int amountCents; // iade/iptal satırları eksi
  final bool computed;

  const FeeLine({
    required this.date,
    required this.description,
    required this.item,
    required this.amountCents,
    this.computed = false,
  });
}

class FeeReport {
  final DateTime from;
  final DateTime to;
  final List<FeeLine> lines;

  const FeeReport({required this.from, required this.to, required this.lines});

  /// Kalem toplamları. Ayrıntı listesi ile toplamlar aynı satırlardan hesaplanır, birbirini tutar.
  Map<FeeItem, int> get byItem {
    final m = <FeeItem, int>{};
    for (final l in lines) {
      m[l.item] = (m[l.item] ?? 0) + l.amountCents;
    }
    m.removeWhere((_, v) => v == 0);
    return m;
  }

  int totalOf(FeeGroup g) => lines.where((l) => l.item.group == g).fold(0, (s, l) => s + l.amountCents);

  bool get hasComputed => lines.any((l) => l.computed);
  bool get isEmpty => lines.isEmpty;
}

/// Ekstre ve bordrolardaki masrafları kalem kalem toplar.
class FeeReportService {
  FeeReportService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  /// Kart faizine eklenen vergi oranları (TCMB/mevzuat, 2026): BSMV %15, KKDF %15.
  /// Ekstre faizi "BSMV/KKDF dahil" tek satır yazdığında vergi payı bu oranlarla ayrıştırılır.
  static const int bsmvOnInterestPct = 15;
  static const int kkdfOnInterestPct = 15;

  /// Takvim ayı: [year]-[month]. Takvim yılı: month = null.
  Future<FeeReport> load({required int year, int? month}) async {
    final from = DateTime(year, month ?? 1, 1);
    final to = month == null ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    String day(DateTime d) => d.toIso8601String().split('T')[0];
    final db = await _db.database;

    final txRows = await db.rawQuery('''
      SELECT t.transaction_date, t.raw_description, t.transaction_type, t.tx_kind,
             t.billing_amount_cents, t.statement_id, a.account_type,
             (SELECT COUNT(*) FROM transactions x
               WHERE x.statement_id = t.statement_id AND x.tx_kind = 'TAX'
                 AND (UPPER(x.raw_description) LIKE '%BSMV%' OR UPPER(x.raw_description) LIKE '%KKDF%')) AS separate_tax_lines
      FROM transactions t JOIN accounts a ON a.id = t.account_id
      WHERE t.tx_kind IN ('INTERESTFEE', 'TAX')
        AND t.transaction_date >= ? AND t.transaction_date < ?
      ORDER BY t.transaction_date
    ''', [day(from), day(to)]);

    final payrollRows = await db.rawQuery('''
      SELECT t.transaction_date, d.tax_type, d.amount_cents
      FROM tax_deductions d
      JOIN transactions t ON t.id = d.transaction_id
      JOIN accounts a ON a.id = t.account_id
      WHERE a.account_type = 'PAYSLIP'
        AND t.transaction_date >= ? AND t.transaction_date < ?
    ''', [day(from), day(to)]);

    return FeeReport(from: from, to: to, lines: buildLines(txRows, payrollRows));
  }

  /// Saf hesap (birim testlenebilir): veritabanı satırlarından masraf satırları.
  static List<FeeLine> buildLines(
      List<Map<String, Object?>> txRows, List<Map<String, Object?>> payrollRows) {
    final lines = <FeeLine>[];
    for (final r in txRows) {
      final desc = (r['raw_description'] as String?) ?? '';
      final date = DateTime.parse(r['transaction_date'] as String);
      final sign = r['transaction_type'] == 'CREDIT' ? -1 : 1;
      final amount = sign * (r['billing_amount_cents'] as num).toInt();
      final item = classify(desc, r['tx_kind'] as String?);
      final isCard = r['account_type'] == 'CREDIT_CARD';
      final hasSeparateTax = ((r['separate_tax_lines'] as num?) ?? 0) > 0;

      if (isCard && !hasSeparateTax && _isCardInterest(item)) {
        // Faiz satırı BSMV ve KKDF'yi içeriyor: faiz = toplam / 1,30; vergiler faizin %15'er fazlası
        const totalPct = 100 + bsmvOnInterestPct + kkdfOnInterestPct;
        final base = (amount * 100 / totalPct).round();
        final bsmv = (base * bsmvOnInterestPct / 100).round();
        final kkdf = amount - base - bsmv; // yuvarlama farkı KKDF'de kalır, toplam korunur
        lines
          ..add(FeeLine(date: date, description: desc, item: item, amountCents: base, computed: true))
          ..add(FeeLine(date: date, description: desc, item: FeeItem.bsmv, amountCents: bsmv, computed: true))
          ..add(FeeLine(date: date, description: desc, item: FeeItem.kkdf, amountCents: kkdf, computed: true));
      } else {
        lines.add(FeeLine(date: date, description: desc, item: item, amountCents: amount));
      }
    }
    for (final r in payrollRows) {
      final item = switch (r['tax_type']) {
        'INCOME_TAX' => FeeItem.payrollIncomeTax,
        'STAMP_TAX' => FeeItem.payrollStampTax,
        'SGK_WORKER' => FeeItem.payrollSgk,
        'UNEMPLOYMENT' => FeeItem.payrollUnemployment,
        _ => null,
      };
      if (item == null) continue;
      lines.add(FeeLine(
        date: DateTime.parse(r['transaction_date'] as String),
        description: item.label,
        item: item,
        amountCents: (r['amount_cents'] as num).toInt(),
      ));
    }
    return lines;
  }

  static bool _isCardInterest(FeeItem i) =>
      i == FeeItem.purchaseInterest || i == FeeItem.lateInterest || i == FeeItem.cashAdvanceInterest;

  static final Map<String, RegExp> _re = {};
  static bool _has(String text, List<String> keys) => keys.any(
      (k) => _re.putIfAbsent(k, () => RegExp('(?<![A-Z0-9])${RegExp.escape(k)}')).hasMatch(text));

  /// Açıklamadan masraf kalemini bulur. Sıra önemli: özel kalıplar genel olanlardan önce.
  static FeeItem classify(String rawDescription, String? txKind) {
    final t = TrStatementText.fold(rawDescription);
    if (_has(t, ['BSMV'])) return FeeItem.bsmv;
    if (_has(t, ['KKDF'])) return FeeItem.kkdf;
    if (_has(t, ['STOPAJ', 'GV KESINTISI'])) return FeeItem.withholding;
    if (_has(t, ['MOTORLU TASITLAR', 'MTV'])) return FeeItem.mtv;
    if (txKind == 'TAX') return FeeItem.otherTaxPayment;

    if (_has(t, ['GECIKME FAIZI'])) return FeeItem.lateInterest;
    if (_has(t, ['NAKIT AVANS FAIZI'])) return FeeItem.cashAdvanceInterest;
    if (_has(t, ['KMH FAIZI', 'KREDILI MEVDUAT'])) return FeeItem.overdraftInterest;
    if (_has(t, ['DONEM FAIZI', 'AKDI FAIZ', 'ALISVERIS FAIZI'])) return FeeItem.purchaseInterest;
    if (_has(t, ['KART AIDATI', 'YILLIK UYELIK', 'UYELIK UCRETI', 'KART UCRETI', 'YILLIK UCRET'])) {
      return FeeItem.cardAnnualFee;
    }
    if (_has(t, ['NAKIT AVANS UCRETI', 'NAKIT CEKIM UCRETI'])) return FeeItem.cashAdvanceFee;
    if (_has(t, ['EFT', 'FAST', 'HAVALE', 'SWIFT'])) return FeeItem.transferFee;
    if (_has(t, ['EKSTRE UCRETI', 'GECMIS EKSTRE', 'SMS UCRETI'])) return FeeItem.statementFee;
    if (_has(t, ['HESAP ISLETIM'])) return FeeItem.accountFee;
    if (_has(t, ['ISLEM UCRETI', 'FATURA ODEME UCRETI'])) return FeeItem.transactionFee;
    if (_has(t, ['FAIZ'])) return FeeItem.purchaseInterest;
    return FeeItem.otherFee;
  }
}
