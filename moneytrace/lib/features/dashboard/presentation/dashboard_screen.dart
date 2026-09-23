// lib/features/dashboard/presentation/dashboard_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/widgets/rolling_number_ticker.dart';
import '../../../core/widgets/fintech/fintech_components.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/user_profile_service.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../notifications/presentation/notifications_sheet.dart';
import '../../family_budget/presentation/family_budget_sheet.dart';
import '../../statement_upload/presentation/statement_upload_sheet.dart';
import '../../../core/config/remote_config_service.dart';
import '../../subscription/presentation/subscription_plans_sheet.dart';
import '../../subscription/services/subscription_service.dart';
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
    'OCAK',
    'ŞUBAT',
    'MART',
    'NİSAN',
    'MAYIS',
    'HAZİRAN',
    'TEMMUZ',
    'AĞUSTOS',
    'EYLÜL',
    'EKİM',
    'KASIM',
    'ARALIK'
  ];

  late String _selectedMonth;
  late String _monthDisplayName;

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

  int _totalExpenseCents = 0;
  int _totalIncomeCents = 0;
  int _netDifferenceCents = 0;

  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _upcomingInstallments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _monthDisplayName = '${now.year} ${_monthNames[now.month - 1]}';
    UserProfileService.instance.checkScheduledReminders();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final summary =
          await _repository.getMonthlySummary(yearMonth: _selectedMonth);
      final rawTxList = await _repository.getRecentTransactions(
          limit: 50, yearMonth: _selectedMonth);
      final upcoming = await _repository.getUpcomingInstallments(limit: 10);

      if (mounted) {
        setState(() {
          if (summary['totalDebitCents'] != null &&
              (summary['totalDebitCents']! > 0 ||
                  summary['totalCreditCents']! > 0)) {
            _totalExpenseCents = summary['totalDebitCents']!;
            _totalIncomeCents = summary['totalCreditCents']!;
            _netDifferenceCents = summary['netDifferenceCents']!;
          } else {
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

              String? badgeText;
              if (tx['current_installment'] != null &&
                  tx['total_installment'] != null) {
                badgeText =
                    'Taksit: ${tx['current_installment']}/${tx['total_installment']} ödendi';
              }

              return {
                'title': tx['clean_merchant'] ?? 'İşlem',
                'subtitle':
                    '${tx['category_name'] ?? "Genel"} • ${tx['transaction_date']}',
                'amount': (isExpense ? '-' : '+') +
                    CurrencyNormalizer.formatCents(
                        tx['billing_amount_cents'] as int),
                'icon': isExpense
                    ? Icons.arrow_outward_rounded
                    : Icons.arrow_downward_rounded,
                'color': color,
                'isExpense': isExpense,
                'badgeText': badgeText,
              };
            }).toList();
          } else {
            // SIFIR MOCKUP: Tamamen temiz ve boş başlar
            _recentTransactions = [];
          }
          _upcomingInstallments = upcoming;
          _isLoading = false;
        });
        _postScoutNote(_recentTransactions.isNotEmpty);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDocumentTypeSelector() {
    if (!RemoteConfigService.instance.isModuleActive('statement_upload')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.installment,
          content: Text(RemoteConfigService.instance
              .getMaintenanceMessage('statement_upload')),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(AppStrings.get('select_doc_type_title'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(AppStrings.get('select_doc_type_subtitle'),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _buildDocTypeOption(
              icon: Icons.credit_card_rounded,
              title: AppStrings.get('doc_credit_card'),
              subtitle: AppStrings.get('doc_credit_card_desc'),
              hint: 'CREDIT_CARD',
            ),
            _buildDocTypeOption(
              icon: Icons.work_outline_rounded,
              title: AppStrings.get('doc_payslip'),
              subtitle: AppStrings.get('doc_payslip_desc'),
              hint: 'PAYSLIP',
            ),
            _buildDocTypeOption(
              icon: Icons.account_balance_rounded,
              title: AppStrings.get('doc_bank_statement'),
              subtitle: AppStrings.get('doc_bank_statement_desc'),
              hint: 'CHECKING',
            ),
            _buildDocTypeOption(
              icon: Icons.receipt_long_rounded,
              title: AppStrings.get('doc_invoice'),
              subtitle: AppStrings.get('doc_invoice_desc'),
              hint: 'INVOICE',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocTypeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String hint,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF0052FF), size: 22),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      onTap: () {
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => StatementUploadSheet(
            documentTypeHint: hint,
            documentTypeTitle: title,
            onImportSuccess: () => _loadDashboardData(),
          ),
        );
      },
    );
  }

  void _openFamilyBudget() {
    if (!RemoteConfigService.instance.isModuleActive('family_budget')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.installment,
          content: Text(RemoteConfigService.instance
              .getMaintenanceMessage('family_budget')),
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: AppColors.actionPrimary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Üst Karşılama, Profil Barı, Kompakt PDF Yükleme ve Bildirimler
                _buildTopBar(),
                const SizedBox(height: 14),

                // 2. Dönem Seçici (Temiz FinTech Kapsül)
                _buildMonthNavigator(),
                const SizedBox(height: 14),

                // 3. Finansal Özet Kartı (iBank Hero Balance Tarzı)
                _buildSummaryCards(),
                const SizedBox(height: 14),

                const SizedBox(height: 6),

                // Yaklaşan Taksitler & Borçlar Bloğu
                if (_upcomingInstallments.isNotEmpty) ...[
                  _buildUpcomingInstallmentsBlock(),
                  const SizedBox(height: 20),
                ],

                // 5. Kayıtlar (Son Hareketler Başlığı ve Listesi)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Son İşlemler',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '${_recentTransactions.length} işlem',
                      style: const TextStyle(
                        fontSize: 12,
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
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_recentTransactions.isEmpty)
                  _buildEmptyStateCard()
                else
                  FinanceCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentTransactions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, index) =>
                          _buildTransactionRow(_recentTransactions[index]),
                    ),
                  ),

                const SizedBox(height: 84), // Navigasyon & FAB boşluğu
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
        // Sol Alan: Profil Avatarı ve Karşılama
        ValueListenableBuilder<UserProfile?>(
          valueListenable: UserProfileService.instance.profileNotifier,
          builder: (context, profile, _) {
            final name = profile?.name.trim().isNotEmpty == true
                ? profile!.name.trim()
                : AppStrings.get('guest_user');
            final initials = name
                .split(' ')
                .map((e) => e.isNotEmpty ? e[0] : '')
                .take(2)
                .join()
                .toUpperCase();

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => ProfileScreen(
                      onLoggedOut: () {
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF0F172A),
                    child: Text(
                      initials.isNotEmpty ? initials : 'P',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('welcome'),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        // Sağ Alan: Kompakt PDF Yükleme Butonu, Bildirimler ve Premium
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppShadows.card,
              ),
              child: IconButton(
                icon: const Icon(Icons.upload_file_rounded,
                    color: AppColors.textPrimary, size: 20),
                onPressed: _showDocumentTypeSelector,
                tooltip: AppStrings.get('upload_pdf_tooltip'),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<List<InAppNotificationItem>>(
              valueListenable:
                  UserProfileService.instance.notificationsNotifier,
              builder: (context, notifs, _) {
                final unreadCount = notifs.where((n) => !n.isRead).length;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: AppShadows.card,
                  ),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined,
                            color: AppColors.textPrimary, size: 20),
                        onPressed: () => NotificationsSheet.show(context),
                        tooltip: AppStrings.get('notifications_title'),
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.expenseRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            if (!SubscriptionService.instance.isPremium) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => SubscriptionPlansSheet.show(
                  context,
                  onSubscriptionUpdated: () => setState(() {}),
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded,
                          size: 14, color: Color(0xFFD97706)),
                      SizedBox(width: 4),
                      Text(
                        'PRO',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMonthNavigator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _changeMonth(-1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.chevron_left_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.calendar_month_rounded,
                size: 15, color: AppColors.actionPrimary),
            const SizedBox(width: 6),
            Text(
              _monthDisplayName,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _changeMonth(1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final isPositive = _netDifferenceCents >= 0;
    return FinanceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AYLIK NET BAKİYE (GELİR - GİDER)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 13,
                      color: isPositive
                          ? AppColors.incomeGreen
                          : AppColors.expenseRed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPositive ? 'Pozitif Kasa' : 'Bütçe Aşımı',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPositive
                            ? AppColors.incomeGreen
                            : AppColors.expenseRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RollingNumberTicker(
            value: (_netDifferenceCents / 100.0).abs(),
            prefix: isPositive ? '₺' : '-₺',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 14),
          Row(
            children: [
              // Toplam Gelir
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        size: 18,
                        color: AppColors.incomeGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Toplam Gelir',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          RollingNumberTicker(
                            value: _totalIncomeCents / 100.0,
                            prefix: '₺',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.incomeGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.cardBorder),
              const SizedBox(width: 14),
              // Toplam Gider
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: AppColors.expenseRed,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Toplam Gider',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          RollingNumberTicker(
                            value: _totalExpenseCents / 100.0,
                            prefix: '₺',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.expenseRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// İzci notu ekranda sabit durmaz; gerçek duruma göre bir kez bildirim olarak düşer.
  Future<void> _postScoutNote(bool hasData) async {
    final now = DateTime.now();
    if (hasData) {
      await UserProfileService.instance.addNotification(
        id: 'scout_analysis_${now.year}_${now.month}',
        title: "İzci'den bir not",
        message:
            'İşlemleriniz kategorilerine göre sınıflandırıldı. Harcama dağılımınızı Analiz sekmesinde inceleyebilirsiniz.',
      );
    } else {
      await UserProfileService.instance.addNotification(
        id: 'scout_first_upload',
        title: "İzci'den bir not",
        message:
            'Kredi kartı ekstrenizi, hesap ekstrenizi veya maaş bordronuzu yükleyerek harcama dağılımınızı görebilirsiniz.',
      );
    }
  }

  Widget _buildTransactionRow(Map<String, dynamic> tx) {
    final isExpense = tx['isExpense'] == true;
    return CleanTransactionRow(
      title: tx['title'] as String,
      subtitle: tx['subtitle'] as String,
      amount: tx['amount'] as String,
      isExpense: isExpense,
      icon: tx['icon'] as IconData,
      iconColor: tx['color'] as Color?,
      badgeText: tx['badgeText'] as String?,
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
    );
  }

  Widget _buildUpcomingInstallmentsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Yaklaşan Taksitler & Borçlar',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${_upcomingInstallments.length} aktif plan',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.actionPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FinanceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _upcomingInstallments.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (ctx, index) {
              final item = _upcomingInstallments[index];
              final current =
                  (item['current_installment'] as num?)?.toInt() ?? 1;
              final total = (item['total_installment'] as num?)?.toInt() ?? 1;
              final remainingInstallments = (total - current).clamp(0, 999);
              final monthlyCents =
                  (item['monthly_amount_cents'] as num?)?.toInt() ?? 0;
              final remainingCents =
                  (item['remaining_amount_cents'] as num?)?.toInt() ?? 0;
              final merchant =
                  item['clean_merchant'] as String? ?? 'Taksitli Harcama';
              final dueDate = item['due_date'] as String?;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            merchant,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$remainingInstallments taksit kaldı • Aylık ${CurrencyNormalizer.formatCents(monthlyCents)}${dueDate != null ? ' • Vade: $dueDate' : ''}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyNormalizer.formatCents(remainingCents),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.expenseRed,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$current/$total',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateCard() {
    return FinanceCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.actionPrimary.withValues(alpha: 0.08),
                  const Color(0xFF6366F1).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                  color: AppColors.actionPrimary.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.actionPrimary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.get('marketing_motto'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                size: 32, color: AppColors.actionPrimary),
          ),
          const SizedBox(height: 14),
          Text(
            AppStrings.get('no_transactions_title'),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.get('no_transactions_subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _showDocumentTypeSelector,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(AppStrings.get('upload_pdf_tooltip'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.actionPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
