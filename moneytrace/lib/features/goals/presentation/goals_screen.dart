// lib/features/goals/presentation/goals_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dynamic_island_capsule.dart';
import '../../../core/widgets/daily_streak_modal.dart';
import '../../../core/widgets/morphing_share_button.dart';
import '../../../core/widgets/radar_checkout_button.dart';
import '../../../core/widgets/morphing_segmented_bar.dart';
import '../../../core/widgets/streak_confetti_burst.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/config/remote_config_service.dart';
import '../models/financial_goal.dart';
import '../services/goal_calculator_service.dart';
import '../repositories/goal_repository.dart';
import '../widgets/goal_summary_header.dart';
import '../widgets/goal_card_tile.dart';
import 'add_goal_sheet.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with SingleTickerProviderStateMixin {
  final GoalRepository _goalRepository = GoalRepository();
  late AnimationController _confettiController;
  int _filterIndex = 0; // 0: Tümü, 1: Aktif, 2: Tamamlanan
  bool _isLoading = false;
  bool _showGoalsCapsule = true;

  List<FinancialGoal> _goals = [];

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _loadGoals();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      final dbGoals = await _goalRepository.getAllGoals();
      if (mounted) {
        setState(() {
          if (dbGoals.isNotEmpty) {
            _goals = dbGoals;
          } else if (RemoteConfigService.instance.isCleanDataMode) {
            _goals = [];
          } else {
            // Başlangıç Mockup hedefleri
            _goals = [
              FinancialGoal(
                id: 'goal_1',
                title: 'Araç Alım Hedefi',
                category: GoalCategory.vehicle,
                targetAmountCents: 120000000, // ₺1.200.000
                currentSavedCents: 75000000,  // ₺750.000 (%62.5)
                targetDate: DateTime.now().add(const Duration(days: 240)), // ~8 ay
                createdAt: DateTime.now().subtract(const Duration(days: 90)),
              ),
              FinancialGoal(
                id: 'goal_2',
                title: 'Ev Alma Hedefi',
                category: GoalCategory.house,
                targetAmountCents: 300000000, // ₺3.000.000
                currentSavedCents: 180000000, // ₺1.800.000 (%60)
                targetDate: DateTime.now().add(const Duration(days: 720)), // ~24 ay
                createdAt: DateTime.now().subtract(const Duration(days: 180)),
              ),
              FinancialGoal(
                id: 'goal_3',
                title: 'Motorsiklet Hedefi',
                category: GoalCategory.motorcycle,
                targetAmountCents: 25000000, // ₺250.000
                currentSavedCents: 18000000, // ₺180.000 (%72)
                targetDate: DateTime.now().add(const Duration(days: 90)), // ~3 ay
                createdAt: DateTime.now().subtract(const Duration(days: 60)),
              ),
              FinancialGoal(
                id: 'goal_4',
                title: 'Tekne Alma Hedefi',
                category: GoalCategory.boat,
                targetAmountCents: 150000000, // ₺1.500.000
                currentSavedCents: 42000000,  // ₺420.000 (%28)
                targetDate: DateTime.now().add(const Duration(days: 540)), // ~18 ay
                createdAt: DateTime.now().subtract(const Duration(days: 30)),
              ),
              FinancialGoal(
                id: 'goal_5',
                title: 'Özel Hediye Hedefi',
                category: GoalCategory.gift,
                targetAmountCents: 4000000, // ₺40.000
                currentSavedCents: 3500000, // ₺35.000 (%87.5)
                targetDate: DateTime.now().add(const Duration(days: 30)), // ~1 ay
                createdAt: DateTime.now().subtract(const Duration(days: 20)),
              ),
            ];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddGoal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddGoalSheet(
        onGoalCreated: (newGoal) async {
          await _goalRepository.insertGoal(newGoal);
          _loadGoals();
        },
      ),
    );
  }

  void _showContributionDialog(FinancialGoal goal) {
    final amountController = TextEditingController(text: '5000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(goal.category.iconData, color: goal.category.themeColor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${goal.title} - Birikim Ekle',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu hedefe aktarmak istediğiniz tutarı belirleyin:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            // Hızlı Seçim Çipleri
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [1000, 2500, 5000, 10000].map((val) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('+₺$val', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFFF1F5F9),
                      onPressed: () => amountController.text = val.toString(),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₺ ',
                labelText: 'Eklenecek Tutar',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: Column(
              children: [
                // Video 4: Radar Dalgalı Doğrulama ve Güvenli Aktarım Butonu
                RadarCheckoutButton(
                  label: 'Birikimi Doğrula ve Aktar',
                  idleAmountText: '₺${amountController.text}',
                  verifyingAmountText: 'Kasa Güncelleniyor...',
                  onPressed: () async {
                    final rawText = amountController.text.trim().replaceAll('.', '').replaceAll(',', '.');
                    final parsedNum = double.tryParse(rawText);
                    if (parsedNum == null || parsedNum <= 0) return;

                    final int addCents = (parsedNum * 100).round();
                    await _goalRepository.addContribution(
                      goalId: goal.id,
                      amountCents: addCents,
                      note: 'Manuel birikim katkısı',
                    );
                    await _loadGoals();
                  },
                  onVerificationComplete: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.incomeGreen,
                        content: Text('"${goal.title}" hedefine birikim aktarıldı!'),
                      ),
                    );
                    // Video 1 Habit Streak & Başarı Kutlaması + Konfeti Efekti
                    _confettiController.forward(from: 0.0);
                    DailyStreakModal.show(context, currentStreak: 30);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGoalDetail(FinancialGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: goal.category.themeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(goal.category.iconData, color: goal.category.themeColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${goal.category.displayName} • ${goal.monthsRemaining} ay kaldı',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // İlerleme Özeti
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mevcut Birikim:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        '₺${(goal.currentSavedCents / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.incomeGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Hedef Tutar:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        '₺${(goal.targetAmountCents / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Aylık Önerilen Tasarruf:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        '₺${(goal.recommendedMonthlySavingsCents / 100).toStringAsFixed(2)} / ay',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: goal.category.themeColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Video 2: Hedef İlerlemesi Morflayan Paylaşım Butonu
            MorphingShareButton(
              fileName: '${goal.title.replaceAll(" ", "_")}_ilerleme.pdf',
              label: 'Hedef İlerlemesini Paylaş (%${goal.progressPercentage.toStringAsFixed(0)})',
              accentColor: goal.category.themeColor,
              onDownloadComplete: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text('"${goal.title}" hedef ilerlemeniz paylaşıldı.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showContributionDialog(goal);
                },
                icon: const Icon(Icons.savings_rounded, size: 18),
                label: const Text('+ Birikim Katkısı Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: goal.category.themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = GoalCalculatorService.calculateSummary(_goals);
    final scoutMessage = GoalCalculatorService.generateScoutGoalInsight(summary, _goals);

    List<FinancialGoal> filteredGoals = _goals;
    if (_filterIndex == 1) {
      filteredGoals = _goals.where((g) => !g.isCompleted).toList();
    } else if (_filterIndex == 2) {
      filteredGoals = _goals.where((g) => g.isCompleted).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Hedeflerim',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.actionPrimary, size: 24),
            onPressed: _openAddGoal,
            tooltip: 'Yeni Hedef Ekle',
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadGoals,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shakuro Inspired Yüzen Kapsül (%25 Maksimum Boyut, Drag-to-Dismiss)
                        if (_showGoalsCapsule) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: DynamicIslandCapsule(
                              title: 'Hedef İlerlemesi & Akıllı Birikim',
                              message:
                                  'Araç ve konut hedefleriniz ortalama %60 tamamlama oranına ulaştı. Düzenli aylık tasarruf katkılarıyla hedefinize planlanan tarihten 2 ay erken ulaşabilirsiniz.',
                              comparisonHighlight:
                                  'İpucu: Birikim hedefinize her katkı eklediğinizde 30 günlük finansal alışkanlık seriniz güçlenir.',
                              onDismissed: () => setState(() => _showGoalsCapsule = false),
                              onActionTap: () {
                                DailyStreakModal.show(context, currentStreak: 30);
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],

                        // 1. Özet Kartı
                        GoalSummaryHeader(summary: summary),

                        // 2. "İzci" Hedef Tavsiyesi
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFEF3C7)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_rounded, color: Color(0xFFD97706), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  scoutMessage,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. Video & Shakuro Micro-Interaction: Morflayan Kayan Filtre Barı
                        MorphingSegmentedBar(
                          segments: [
                            'Tümü (${_goals.length})',
                            'Aktif (${summary.activeGoalsCount})',
                            'Tamamlanan (${summary.completedGoalsCount})',
                          ],
                          selectedIndex: _filterIndex,
                          onSelected: (idx) => setState(() => _filterIndex = idx),
                        ),

                    // 4. Hedef Kartları Listesi
                    if (_goals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFDBEAFE)),
                                ),
                                child: const Icon(Icons.flag_rounded, size: 36, color: AppColors.actionPrimary),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Henüz Bir Finansal Hedef Eklenmedi',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Konut, araç, acil durum fonu veya tatil için birikim hedefi oluşturarak tasarruf planınızı hemen başlatın.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _openAddGoal,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('İlk Hedefinizi Oluşturun', style: TextStyle(fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.actionPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (filteredGoals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'Bu filtrede hedef bulunamadı.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      ...filteredGoals.map((g) {
                        return GoalCardTile(
                          goal: g,
                          onTap: () => _showGoalDetail(g),
                          onAddContribution: () => _showContributionDialog(g),
                        );
                      }).toList(),

                    const SizedBox(height: 84), // Navigasyon & FAB boşluğu
                  ],
                ),
              ),
            ),
          // Video Kutlama Efekti: Konfeti Patlaması
          IgnorePointer(
            child: StreakConfettiBurst(controller: _confettiController),
          ),
        ],
      ),
    );
  }
}
