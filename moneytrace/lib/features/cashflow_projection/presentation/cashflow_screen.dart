// lib/features/cashflow_projection/presentation/cashflow_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/widgets/fintech/fintech_components.dart';
import '../../../core/widgets/morphing_segmented_bar.dart';
import '../../../core/services/data_changes.dart';
import '../../../core/widgets/bank_logo.dart';
import '../../assets_portfolio/presentation/widgets/card_payment_flow.dart';
import '../../navigation/tab_add_actions.dart';
import '../services/wallet_history_service.dart';

/// Cüzdan: geriye dönük, yalnızca gerçekleşmiş veriler (kayıtlı işlemler, ekstrelerdeki taksitler,
/// son ekstrelerde bankanın yazdığı bakiye ve borçlar). Tahmin veya örnek veri yoktur.
class CashflowScreen extends StatefulWidget {
  const CashflowScreen({Key? key}) : super(key: key);

  @override
  State<CashflowScreen> createState() => _CashflowScreenState();
}

class _CashflowScreenState extends State<CashflowScreen> implements TabAddActions {
  final WalletHistoryService _service = WalletHistoryService();
  static const _ranges = [3, 6, 12];
  static const _monthNames = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  int _rangeIndex = 1;
  bool _isLoading = true;
  WalletHistory? _history;

  @override
  void initState() {
    super.initState();
    DataChanges.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    DataChanges.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final history = await _service.load(months: _ranges[_rangeIndex]);
      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _money(int cents) => CurrencyNormalizer.formatCents(cents);

  /// + menüsü: manuel gelir/gider ve (ekstresi yüklü kart varsa) kart ödemesi.
  /// Kart ödemesi, Varlıklar'daki "Ödemeyi kaydet" sayfasının kendisidir (CardPaymentFlow):
  /// aynı nötr kayıt, aynı ödeme kaynağı seçimi; ayrı bir form yazılmadı.
  @override
  List<TabAddAction> get addActions => [
        TabAddAction(
          icon: Icons.edit_note_rounded,
          title: 'Manuel gelir / gider',
          subtitle: 'Nakit harcama, ek gelir vb.',
          onSelected: () => openQuickEntrySheet(context),
        ),
        if (_history?.cardDebts.isNotEmpty ?? false)
          TabAddAction(
            icon: Icons.credit_score_rounded,
            title: 'Kart ödemesi kaydet',
            subtitle: 'Bankada yaptığın kart ödemesini borçtan düş',
            onSelected: () => CardPaymentFlow.start(context),
          ),
      ];

  static String _formatIso(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Cüzdan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading || history == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.actionPrimary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 84),
                children: [
                  _buildBalanceCard(history),
                  const SizedBox(height: 16),
                  MorphingSegmentedBar(
                    segments: const ['Son 3 ay', 'Son 6 ay', 'Son 12 ay'],
                    selectedIndex: _rangeIndex,
                    padding: EdgeInsets.zero,
                    height: 38,
                    onSelected: (i) {
                      setState(() => _rangeIndex = i);
                      _load();
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTrendChart(history),
                  const SizedBox(height: 16),
                  IzciInsightCard(message: _scoutNote(history)),
                  if (history.cardDebts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('Kart borçları'),
                    const SizedBox(height: 8),
                    ...history.cardDebts.map(_buildCardDebtRow),
                  ],
                  if (history.installments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('Devam eden taksitler',
                        trailing: 'Aylık ${_money(history.monthlyInstallmentsCents)}'),
                    const SizedBox(height: 8),
                    ...history.installments.map(_buildInstallmentRow),
                  ],
                  const SizedBox(height: 20),
                  _sectionTitle('Aylar'),
                  const SizedBox(height: 8),
                  ...history.months.reversed.map(_buildMonthRow),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard(WalletHistory history) {
    final thisMonth = history.months.last;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _stat(
                  'Hesap bakiyesi',
                  history.accountBalanceCents == null ? '—' : _money(history.accountBalanceCents!),
                  AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: _stat(
                  'Kart borcu',
                  history.cardDebtCents == null
                      ? '—'
                      : _money((history.cardDebtCents! - history.cardPaymentsSinceStatementCents)
                          .clamp(0, history.cardDebtCents!)),
                  AppColors.expenseRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            history.accountBalanceCents == null && history.cardDebtCents == null
                ? 'Bakiye ve borç, yüklediğin son ekstreden okunur.'
                : 'Son ekstrelere göre${history.cardPaymentsSinceStatementCents > 0 ? '; kart borcundan sonradan kaydedilen ${_money(history.cardPaymentsSinceStatementCents)} ödeme düşüldü' : ''}.',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Text('${_monthNames[thisMonth.month.month - 1]} ${thisMonth.month.year}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _stat('Gelir', _money(thisMonth.incomeCents), AppColors.incomeGreen)),
              Expanded(child: _stat('Gider', _money(thisMonth.expenseCents), AppColors.expenseRed)),
              Expanded(
                child: _stat(
                  'Değişim',
                  '${thisMonth.netCents >= 0 ? '+' : ''}${_money(thisMonth.netCents)}',
                  thisMonth.netCents >= 0 ? AppColors.actionPrimary : AppColors.expenseRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      );

  /// Aylık net değişim çubukları (gerçekleşmiş). Sıfır çizgisinin üstü artış, altı azalış.
  Widget _buildTrendChart(WalletHistory history) {
    final maxAbs = history.months.fold<int>(1, (m, x) => x.netCents.abs() > m ? x.netCents.abs() : m);
    const barMax = 56.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aylık değişim',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: barMax * 2 + 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: history.months.map((m) {
                final h = (m.netCents.abs() / maxAbs) * barMax;
                final positive = m.netCents >= 0;
                final bar = Container(
                  height: m.netCents == 0 ? 1 : h,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: m.transactionCount == 0
                        ? const Color(0xFFE2E8F0)
                        : (positive ? AppColors.actionPrimary : AppColors.expenseRed),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
                return Expanded(
                  child: Column(
                    children: [
                      SizedBox(height: barMax, child: Align(alignment: Alignment.bottomCenter, child: positive ? bar : null)),
                      SizedBox(height: barMax, child: Align(alignment: Alignment.topCenter, child: positive ? null : bar)),
                      Text(_monthNames[m.month.month - 1].substring(0, 3),
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// İzci notu: yalnızca gerçek verilerden üretilir; veri yoksa bunu açıkça söyler.
  String _scoutNote(WalletHistory history) {
    final withData = history.months.where((m) => m.transactionCount > 0).toList();
    if (withData.isEmpty) {
      return 'Bu dönemde kayıtlı işlem yok. Ekstre veya bordro yükledikçe cüzdan değişimini burada göreceksiniz.';
    }
    final parts = <String>[];
    final thisMonth = history.months.last;
    final past = withData.where((m) => m != thisMonth).toList();
    if (past.isNotEmpty) {
      final avgExpense = past.fold<int>(0, (s, m) => s + m.expenseCents) ~/ past.length;
      if (avgExpense > 0 && thisMonth.expenseCents > 0) {
        final diff = ((thisMonth.expenseCents - avgExpense) * 100 / avgExpense).round();
        parts.add(diff >= 0
            ? 'Bu ayki gideriniz önceki ayların ortalamasından %$diff fazla.'
            : 'Bu ayki gideriniz önceki ayların ortalamasından %${diff.abs()} az.');
      }
    }
    final top = history.categoryChanges.where((c) => c.$2 > c.$3 && c.$3 > 0).toList();
    if (top.isNotEmpty) {
      parts.add('En çok artan kalem: ${top.first.$1} (${_money(top.first.$2)}, ortalama ${_money(top.first.$3)}).');
    }
    if (history.installments.isNotEmpty) {
      parts.add('Devam eden ${history.installments.length} taksitin kalan toplamı ${_money(history.remainingInstallmentsCents)}.');
    }
    return parts.isEmpty ? 'Karşılaştırma için en az iki aylık veri gerekiyor.' : parts.join(' ');
  }

  Widget _sectionTitle(String title, {String? trailing}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          if (trailing != null)
            Text(trailing, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      );

  Widget _buildCardDebtRow(CardDebt c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              BankLogo(bankName: c.bankName, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        [c.bankName, if ((c.cardMask ?? '').isNotEmpty) c.cardMask!].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                        c.paidSinceStatementCents > 0
                            ? 'Ekstre ${_money(c.statementDebtCents)} · sonradan ödenen ${_money(c.paidSinceStatementCents)}'
                            : 'Son ödeme ${_formatIso(c.dueDate)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text(_money(c.remainingCents),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.expenseRed)),
            ],
          ),
        ),
      );

  Widget _buildInstallmentRow(ActiveInstallment i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              BankLogo(bankName: i.bankName, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.merchant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('${i.bankName != null ? '${i.bankName} · ' : ''}${i.currentInstallment} / ${i.totalInstallment} taksit · kalan ${i.remainingCount} ay',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money(i.monthlyCents),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  Text('kalan ${_money(i.remainingCents)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildMonthRow(WalletMonth m) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('${_monthNames[m.month.month - 1]} ${m.month.year}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              if (m.transactionCount == 0)
                const Text('Kayıt yok', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${m.netCents >= 0 ? '+' : ''}${_money(m.netCents)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: m.netCents >= 0 ? AppColors.actionPrimary : AppColors.expenseRed)),
                    Text('gelir ${_money(m.incomeCents)} · gider ${_money(m.expenseCents)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
            ],
          ),
        ),
      );
}
