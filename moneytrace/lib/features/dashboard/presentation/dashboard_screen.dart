// lib/features/dashboard/presentation/dashboard_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/widgets/dynamic_island_capsule.dart';
import '../../../core/widgets/daily_streak_modal.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../../../core/widgets/rolling_number_ticker.dart';
import '../../../core/widgets/in_app_notification_sheet.dart';
import '../../quick_entry/presentation/quick_entry_sheet.dart';
import '../../family_budget/presentation/family_budget_sheet.dart';
import '../../statement_upload/presentation/statement_upload_sheet.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../core/config/remote_config_service.dart';
import '../../subscription/presentation/subscription_plans_sheet.dart';
import 'widgets/transaction_detail_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenAnalytics;
  final VoidCallback? onOpenGoals;

  const DashboardScreen({
    Key? key,
    this.onOpenAnalytics,
    this.onOpenGoals,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TransactionRepository _repository = TransactionRepository();

  static const List<String> _monthNames = [
    'OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN',
    'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'
  ];

  String _selectedMonth = '2026-07';
  String _monthDisplayName = '2026 TEMMUZ';

  void _changeMonth(int offset) {
    try {
      final parts = _selectedMonth.split('-');
      int year = int.parse(parts[0]);
      int month = int.parse(parts[1]);

      month += offset;
      if (month < 1) {
        month = 12;
        year -= 1;
      } else if (month > 12) {
        month = 1;
        year += 1;
      }

      final newMonthStr = '$year-${month.toString().padLeft(2, '0')}';
      setState(() {
        _selectedMonth = newMonthStr;
        _monthDisplayName = '$year ${_monthNames[month - 1]}';
      });
      _loadDashboardData();
    } catch (_) {}
  }

  int _totalExpenseCents = 9882610; // Varsayılan demo değerler
  int _totalIncomeCents = 13360000;
  int _netDifferenceCents = 3477390;

  List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoading = false;
  bool _showTopInsightCapsule = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _repository.getMonthlySummary(yearMonth: _selectedMonth);
      final rawTxList = await _repository.getRecentTransactions(limit: 30);
      final isClean = RemoteConfigService.instance.isCleanDataMode;

      if (mounted) {
        setState(() {
          if (summary['totalDebitCents']! > 0 || summary['totalCreditCents']! > 0) {
            _totalExpenseCents = summary['totalDebitCents']!;
            _totalIncomeCents = summary['totalCreditCents']!;
            _netDifferenceCents = summary['netDifferenceCents']!;
          } else if (isClean) {
            _totalExpenseCents = 0;
            _totalIncomeCents = 0;
            _netDifferenceCents = 0;
          }

          if (rawTxList.isNotEmpty) {
            _recentTransactions = rawTxList.map((tx) {
              final isExpense = tx['transaction_type'] == 'DEBIT';
              Color color = AppColors.dynamicPrimary;
              if (tx['color_hex'] != null) {
                final hex = (tx['color_hex'] as String).replaceAll('#', '');
                color = Color(int.parse('FF$hex', radix: 16));
              }

              return {
                'title': tx['clean_merchant'] ?? 'İşlem',
                'subtitle': '${tx['category_name'] ?? "Genel"} • ${tx['transaction_date']}',
                'amount': (isExpense ? '-' : '+') + CurrencyNormalizer.formatCents(tx['billing_amount_cents'] as int),
                'icon': isExpense ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                'color': color,
                'isExpense': isExpense,
              };
            }).toList();
          } else if (isClean) {
            _recentTransactions = [];
          } else {
            // İlk açılışta zengin mockup gösterimi (yalnızca demo modunda)
            _recentTransactions = [
              {
                'title': 'Fatura',
                'subtitle': 'Gider • 2026-07-28',
                'amount': '-₺890,00',
                'icon': Icons.receipt_long_rounded,
                'color': const Color(0xFF10B981),
                'isExpense': true,
              },
              {
                'title': 'Market',
                'subtitle': 'Gider • 2026-07-28',
                'amount': '-₺2.700,00',
                'icon': Icons.shopping_cart_rounded,
                'color': const Color(0xFF14B8A6),
                'isExpense': true,
              },
              {
                'title': 'Spotify',
                'subtitle': 'Abonelik • 2026-07-28',
                'amount': '-₺59,99',
                'icon': Icons.subscriptions_rounded,
                'color': const Color(0xFF22C55E),
                'isExpense': true,
              },
              {
                'title': 'Kahve',
                'subtitle': 'Gider • 2026-07-28',
                'amount': '-₺185,00',
                'icon': Icons.local_cafe_rounded,
                'color': const Color(0xFFF97316),
                'isExpense': true,
              },
              {
                'title': 'Yakıt',
                'subtitle': 'Gider • 2026-07-28',
                'amount': '-₺1.850,00',
                'icon': Icons.local_gas_station_rounded,
                'color': const Color(0xFFEA580C),
                'isExpense': true,
              },
            ];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openStatementUpload() {
    if (!RemoteConfigService.instance.isModuleActive('statement_upload')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.installment,
          content: Text(RemoteConfigService.instance.getMaintenanceMessage('statement_upload')),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatementUploadSheet(
        onImportSuccess: () {
          _loadDashboardData();
        },
      ),
    );
  }

  void _openFamilyBudget() {
    if (!RemoteConfigService.instance.isModuleActive('family_budget')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.installment,
          content: Text(RemoteConfigService.instance.getMaintenanceMessage('family_budget')),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FamilyBudgetSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: AppColors.accentBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 0. Shakuro Inspired Dynamic Island Kapsülü (< 24% Height, Drag-to-Dismiss)
                if (_showTopInsightCapsule) ...[
                  DynamicIslandCapsule(
                    title: 'Akıllı Tasarruf: Finansal Bütçe Analizi',
                    message:
                        'Bu ayki sabit harcamalarınız gelirinize oranla dengeli seviyede seyrediyor. Elektrikli araç veya toplu taşıma alternatifleriyle yakıt giderinizi %40 azaltabilirsiniz.',
                    comparisonHighlight:
                        'İpucu: Düzenli harcama girişleri sayesinde 30 günlük finansal seri rozetini koruyorsunuz!',
                    onDismissed: () => setState(() => _showTopInsightCapsule = false),
                    onActionTap: () {
                      DailyStreakModal.show(context, currentStreak: 30);
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 1. Üst Karşılama ve Profil Barı
                _buildTopBar(),
                const SizedBox(height: 16),

                // 2. Dönem Seçici (< 2026 TEMMUZ AYI TOPLAMI >)
                _buildMonthNavigator(),
                const SizedBox(height: 14),

                // 3. Finansal Özet Kartları (Toplam Gider / Toplam Gelir / Fark)
                _buildSummaryCards(),
                const SizedBox(height: 14),

                // 4. Ekstre Yükle Hızlı Banner Kartı
                _buildStatementUploadBanner(),
                const SizedBox(height: 14),

                // 5. "İzci" (Scout) Zeka & Persona Kartı
                _buildScoutPersonaCard(),
                const SizedBox(height: 20),

                // 6. Kayıtlar (Son Hareketler Başlığı ve Listesi)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'KAYITLAR',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${_recentTransactions.length} Kayıt',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_recentTransactions.isEmpty)
                  _buildEmptyStateCard()
                else
                  ..._recentTransactions.map((tx) => _buildTransactionRow(tx)).toList(),

                const SizedBox(height: 84),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF0F172A),
                child: Text(
                  'AA',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Hoş Geldin,',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Ahmet AYDIN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.group_rounded, color: AppColors.accentBlue, size: 22),
              onPressed: _openFamilyBudget,
              tooltip: 'Aile Bütçesi',
            ),
            InkWell(
              onTap: () => DailyStreakModal.show(context, currentStreak: 30),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0E14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Text('🔥', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 4),
                    Text(
                      '30 Gün',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => SubscriptionPlansSheet.show(
                context,
                onSubscriptionUpdated: () => setState(() {}),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFF78350F)),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF78350F)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24, color: AppColors.textSecondary),
          onPressed: () => _changeMonth(-1),
          tooltip: 'Önceki Ay',
          splashRadius: 20,
        ),
        const SizedBox(width: 4),
        Text(
          '< $_monthDisplayName AYI TOPLAMI >',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.textSecondary),
          onPressed: () => _changeMonth(1),
          tooltip: 'Sonraki Ay',
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Toplam Gider Kartı
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.expenseRed),
                          SizedBox(width: 4),
                          Text('TOPLAM GİDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.expenseRed)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      RollingNumberTicker(
                        value: _totalExpenseCents / 100.0,
                        prefix: '₺',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.expenseRed),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Toplam Gelir Kartı
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.incomeGreen),
                          SizedBox(width: 4),
                          Text('TOPLAM GELİR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.incomeGreen)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      RollingNumberTicker(
                        value: _totalIncomeCents / 100.0,
                        prefix: '₺',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.incomeGreen),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ortalanmış Net Fark Canlı Radar Rozeti
          PulseMetricBadge(
            label: 'NET FARK: ',
            value: (_netDifferenceCents >= 0 ? '+' : '') + CurrencyNormalizer.formatCents(_netDifferenceCents),
            icon: _netDifferenceCents >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            pulseColor: _netDifferenceCents >= 0 ? const Color(0xFF10B981) : AppColors.expenseRed,
            baseColor: const Color(0xFF0C0E14),
            onTap: () {
              widget.onOpenAnalytics?.call();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatementUploadBanner() {
    return InkWell(
      onTap: _openStatementUpload,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF38BDF8), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Banka Ekstresi veya Bordro Yükle',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Enpara, Yapı Kredi PDF dökümlerini saniyeler içinde tara',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScoutPersonaCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('🦉', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'İzci',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                SizedBox(height: 3),
                Text(
                  'Kahve harcamaların uçuşa geçmiş, tüylerim ürperdi! Biraz tencere yemeğiyle barışma vakti.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(Map<String, dynamic> tx) {
    final isExpense = tx['isExpense'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          TransactionDetailSheet.show(
            context,
            transaction: tx,
            onDelete: () {
              setState(() {
                _recentTransactions.remove(tx);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.textPrimary,
                  content: Text('${tx['title']} kaydı silindi.'),
                ),
              );
            },
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (tx['color'] as Color).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tx['icon'] as IconData, color: tx['color'] as Color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx['title'] as String,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx['subtitle'] as String,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                tx['amount'] as String,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isExpense ? AppColors.expenseRed : AppColors.incomeGreen,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.dynamicPrimary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.note_add_rounded, size: 36, color: AppColors.dynamicPrimary),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tertemiz Başlangıç',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Henüz hesap ekstresi veya harcama kaydı bulunmuyor.\nÖrnek PDF ekstrelerinizi yükleyerek harcama analitiğini başlatabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _openStatementUpload,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('PDF Ekstre Yükle', style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dynamicPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
