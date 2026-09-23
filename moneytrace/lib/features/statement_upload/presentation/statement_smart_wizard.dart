// lib/features/statement_upload/presentation/statement_smart_wizard.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/parser/models/parsed_models.dart';
import '../../../core/services/data_export_service.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../../../core/widgets/morphing_share_button.dart';
import '../../../core/widgets/radar_checkout_button.dart';
import '../../../core/services/user_profile_service.dart';

class SmartWizardDecisionResult {
  final Map<String, String> cardOwnerAssignments; // cardMask -> familyMemberId
  final bool scheduleFutureInstallments;
  final bool trackGoldCryptoAsAssets;
  final List<String> confirmedSalaryTxIds;
  final bool generateFeeRefundPetition;
  final bool prioritizeEmergencyPayoff;
  final bool trackRecurringSubscriptions;
  final int? detectedFeeAmountCents;
  final String? feeRefundPetitionText;

  const SmartWizardDecisionResult({
    required this.cardOwnerAssignments,
    required this.scheduleFutureInstallments,
    required this.trackGoldCryptoAsAssets,
    required this.confirmedSalaryTxIds,
    this.generateFeeRefundPetition = false,
    this.prioritizeEmergencyPayoff = false,
    this.trackRecurringSubscriptions = true,
    this.detectedFeeAmountCents,
    this.feeRefundPetitionText,
  });
}

class StatementSmartWizardDialog extends StatefulWidget {
  final StatementDocumentResult result;
  final int salaryDayOfMonth; // Kullanıcının maaş günü (Örn: 15)

  const StatementSmartWizardDialog({
    Key? key,
    required this.result,
    this.salaryDayOfMonth = 15,
  }) : super(key: key);

  @override
  State<StatementSmartWizardDialog> createState() =>
      _StatementSmartWizardDialogState();
}

class _StatementSmartWizardDialogState
    extends State<StatementSmartWizardDialog> {
  // Karar değişkenleri
  final Map<String, String> _cardAssignments = {};
  bool _scheduleInstallments = true;
  bool _trackAssets = true;
  final Set<String> _selectedSalaryTxIds = {};

  // Yeni Akıllı Tespit Kararları
  bool _generateFeeRefundPetition = true;
  bool _prioritizeEmergencyPayoff = true;
  bool _trackRecurringSubscriptions = true;

  // Tespit Edilen Kayıtlar
  List<String> _detectedCards = [];
  List<ParsedRecord> _installmentRecords = [];
  List<ParsedRecord> _investmentRecords = [];
  List<ParsedRecord> _irregularCreditRecords = [];
  List<ParsedRecord> _annualFeeRecords = [];
  List<ParsedRecord> _cashAdvanceRecords = [];
  List<ParsedRecord> _recurringSubscriptionRecords = [];

  late final List<Map<String, String>> _familyMembers = [
    {
      'id': 'mem_1',
      'name':
          '${UserProfileService.instance.profile?.name ?? "Kullanıcı"} (Asıl Kart)'
    },
    {'id': 'mem_2', 'name': 'Eş (Ek Kart)'},
    {'id': 'mem_3', 'name': 'Çocuk (Öğrenci Kartı)'},
  ];

  @override
  void initState() {
    super.initState();
    _analyzeRecords();
  }

  void _analyzeRecords() {
    final cards = <String>{};
    for (final r in widget.result.records) {
      if (r.cardOrAccountMask.isNotEmpty) {
        cards.add(r.cardOrAccountMask);
      }
      if (r.installment != null) {
        _installmentRecords.add(r);
      }

      final lowerDesc = r.rawDescription
          .toLowerCase()
          .replaceAll('ı', 'i')
          .replaceAll('İ', 'i')
          .replaceAll('I', 'i');

      // 1. Altın / Döviz / Kripto tespiti
      if (lowerDesc.contains('kuyumcu') ||
          lowerDesc.contains('altın') ||
          lowerDesc.contains('gold') ||
          lowerDesc.contains('sarraf') ||
          lowerDesc.contains('binance') ||
          lowerDesc.contains('btcturk') ||
          lowerDesc.contains('paribu') ||
          lowerDesc.contains('döviz')) {
        _investmentRecords.add(r);
      }

      // 2. Kart Aidatı / Üyelik Ücreti Tespiti
      final isFee = lowerDesc.contains('üyelik ücreti') ||
          lowerDesc.contains('uyelik ucreti') ||
          lowerDesc.contains('kart aidat') ||
          lowerDesc.contains('yıllık ücret') ||
          lowerDesc.contains('yillik ucret') ||
          (lowerDesc.contains('aidat') &&
              !lowerDesc.contains('site aidat') &&
              !lowerDesc.contains('apartman'));
      if (isFee) {
        _annualFeeRecords.add(r);
      }

      // 3. Nakit Avans / Taksitli Avans Tespiti
      final isCashAdv = lowerDesc.contains('nakit avans') ||
          lowerDesc.contains('taksitli avans') ||
          lowerDesc.contains('nakit çekim') ||
          lowerDesc.contains('nakit cekim') ||
          lowerDesc.contains('avans faizi') ||
          lowerDesc.contains('atm nakit');
      if (isCashAdv) {
        _cashAdvanceRecords.add(r);
      }

      // 4. Tekrarlayan Abonelikler & Dijital Sözleşmeler
      final isSub = r.categoryId == 'cat_subscriptions' ||
          lowerDesc.contains('netflix') ||
          lowerDesc.contains('spotify') ||
          lowerDesc.contains('youtube') ||
          lowerDesc.contains('apple.com/bill') ||
          lowerDesc.contains('disney') ||
          lowerDesc.contains('amazon prime') ||
          lowerDesc.contains('macfit') ||
          lowerDesc.contains('gym') ||
          lowerDesc.contains('fitness');
      if (isSub) {
        _recurringSubscriptionRecords.add(r);
      }

      // 5. Maaş Girişi Kontrolü (+- 2 Gün Kuralı)
      if (r.type == ParsedTransactionType.credit &&
          r.billingAmountCents >= 1000000) {
        // 10.000 TL ve üstü
        final txDay = r.date.day;
        final dayDiff = (txDay - widget.salaryDayOfMonth).abs();
        if (dayDiff > 2 && dayDiff < 28) {
          _irregularCreditRecords.add(r);
        } else {
          _selectedSalaryTxIds.add(r.rawDescription);
        }
      }
    }

    _detectedCards = cards.toList();
    for (final c in _detectedCards) {
      _cardAssignments[c] = _familyMembers.first['id']!;
    }
  }

  int get _totalAnnualFeeCents =>
      _annualFeeRecords.fold(0, (sum, r) => sum + r.billingAmountCents);

  int get _totalCashAdvanceCents =>
      _cashAdvanceRecords.fold(0, (sum, r) => sum + r.billingAmountCents);

  int get _totalSubscriptionsCents => _recurringSubscriptionRecords.fold(
      0, (sum, r) => sum + r.billingAmountCents);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Başlık & Akıllı Asistan Rozeti
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: AppColors.actionPrimary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Ekstre İnceleme & Onay',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const PulseMetricBadge(
                    label: 'OTOMATİK',
                    value: 'SİHİRBAZ',
                    pulseColor: AppColors.actionPrimary,
                    isPositive: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text(
                'Ekstrenizdeki finansal durumlar tespit edildi. Lütfen aşağıdaki akıllı kararlarınızı gözden geçirin:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // 1. SORU: KART AİDATI TESPİTİ & DİLEKÇE TASLAĞI
              if (_annualFeeRecords.isNotEmpty) ...[
                _buildSectionHeader('Kart Aidatı Kesintisi Tespit Edildi!',
                    Icons.gavel_rounded),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_rounded,
                              color: Color(0xFFDC2626), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Toplam ${CurrencyNormalizer.formatCents(_totalAnnualFeeCents)} Aidat Kesildi',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF991B1B)),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '6502 sayılı Tüketici Kanunu & Yargıtay emsal kararınca aidat iadesi talep edebilirsiniz. Bankaya sunulmak üzere resmi itiraz dilekçesi hazırlansın mı?',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF7F1D1D),
                                      height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _generateFeeRefundPetition,
                            activeThumbColor: const Color(0xFFDC2626),
                            onChanged: (val) => setState(
                                () => _generateFeeRefundPetition = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _showPetitionPreviewModal,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF87171)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.description_rounded,
                                  size: 14, color: Color(0xFFDC2626)),
                              SizedBox(width: 6),
                              Text(
                                'Resmi Dilekçe Taslağını Gör & Kopyala',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFDC2626)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. SORU: NAKİT AVANS FAİZ MALİYETİ ALARMI
              if (_cashAdvanceRecords.isNotEmpty) ...[
                _buildSectionHeader('Yüksek Faizli Nakit Avans Uyarısı!',
                    Icons.trending_up_rounded),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: Color(0xFFD97706), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${CurrencyNormalizer.formatCents(_totalCashAdvanceCents)} Nakit Avans',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF92400E)),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Aylık %5.00 akdi faiz + vergiler yıllık maliyeti katlar. 30 günlük nakit akışında bu borç "Acil Kapatılacak 1. Öncelik" yapılsın mı?',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFB45309),
                                  height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _prioritizeEmergencyPayoff,
                        activeThumbColor: const Color(0xFFD97706),
                        onChanged: (val) =>
                            setState(() => _prioritizeEmergencyPayoff = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. SORU: TEKRARLAYAN ABONELİKLER
              if (_recurringSubscriptionRecords.isNotEmpty) ...[
                _buildSectionHeader(
                    'Yinelenen Dijital Abonelikler', Icons.repeat_rounded),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.subscriptions_rounded,
                          color: Color(0xFF7C3AED), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_recurringSubscriptionRecords.length} Abonelik (${CurrencyNormalizer.formatCents(_totalSubscriptionsCents)}/ay)',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF5B21B6)),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Bu sözleşmeler Sabit Gider Takvimine eklenip, çekim gününden 2 gün önce bütçe hatırlatması kurulsun mu?',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6D28D9),
                                  height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _trackRecurringSubscriptions,
                        activeThumbColor: const Color(0xFF7C3AED),
                        onChanged: (val) =>
                            setState(() => _trackRecurringSubscriptions = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. SORU: ÇOKLU KART SAHİBİ EŞLEŞTİRMESİ
              if (_detectedCards.length > 1) ...[
                _buildSectionHeader(
                    'Ek Kart & Harcama Sahibi', Icons.credit_card_rounded),
                const SizedBox(height: 6),
                const Text(
                  'Ekstrenizde birden fazla kart tespit edildi. Harcamaları aile üyelerine atayabilirsiniz:',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                ..._detectedCards.map((cardMask) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cardMask,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _cardAssignments[cardMask],
                            items: _familyMembers.map((m) {
                              return DropdownMenuItem(
                                value: m['id'],
                                child: Text(m['name']!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null)
                                setState(
                                    () => _cardAssignments[cardMask] = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 14),
              ],

              // 5. SORU: GELECEK TAKSİTLER NAKİT AKIŞINA İŞLENSİN Mİ?
              if (_installmentRecords.isNotEmpty) ...[
                _buildSectionHeader(
                    'Gelecek Taksit Takvimi', Icons.calendar_month_rounded),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timelapse_rounded,
                          color: AppColors.installment, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_installmentRecords.length} Taksitli İşlem Bulundu',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary),
                            ),
                            const Text(
                              'Gelecek aylara sarkan taksitler otomatik olarak Nakit Akışı projeksiyonunuza işlensin mi?',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _scheduleInstallments,
                        activeThumbColor: AppColors.installment,
                        onChanged: (val) =>
                            setState(() => _scheduleInstallments = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 6. SORU: MAAŞ TARİHİ DIŞINDAKİ ZAMANSIZ GİRİŞLER
              if (_irregularCreditRecords.isNotEmpty) ...[
                _buildSectionHeader('Zamansız Para Girişleri (Maaş Kontrolü)',
                    Icons.payments_rounded),
                const SizedBox(height: 6),
                Text(
                  'Belirlediğiniz maaş gününüzün (${widget.salaryDayOfMonth}. gün) dışındaki bu girişler maaşınız mı?',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                ..._irregularCreditRecords.map((r) {
                  final isChecked =
                      _selectedSalaryTxIds.contains(r.rawDescription);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          activeColor: AppColors.incomeGreen,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSalaryTxIds.add(r.rawDescription);
                              } else {
                                _selectedSalaryTxIds.remove(r.rawDescription);
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  r.cleanMerchant.isNotEmpty
                                      ? r.cleanMerchant
                                      : r.rawDescription,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  '${r.date.day}/${r.date.month} • ${CurrencyNormalizer.formatCents(r.billingAmountCents)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.incomeGreen,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        Text(
                          isChecked ? 'Maaş Geliri' : 'Diğer Giriş',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isChecked
                                  ? AppColors.incomeGreen
                                  : AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 14),
              ],

              // 7. SORU: ALTIN / DÖVİZ / KRİPTO VARLIKLARA EKLENSİN Mİ?
              if (_investmentRecords.isNotEmpty) ...[
                _buildSectionHeader('Yatırım & Altın / Döviz Varlığı',
                    Icons.monetization_on_rounded),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.savings_rounded,
                          color: AppColors.actionPrimary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_investmentRecords.length} Yatırım / Altın İşlemi',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.actionPrimary),
                            ),
                            const Text(
                              'Bu harcamalar yalnızca bir gider olarak kalmasın, doğrudan Varlıklar / Portföy sayfanıza eklensin mi?',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF1E40AF)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _trackAssets,
                        activeThumbColor: AppColors.actionPrimary,
                        onChanged: (val) => setState(() => _trackAssets = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Video 4: Radar Dalgalı Doğrulama ve Güvenli Cüzdana Aktarma Butonu
              RadarCheckoutButton(
                label: 'Seçimlerimi Doğrula & Aktar',
                idleAmountText: '${widget.result.records.length} Kayıt',
                verifyingAmountText: 'Cüzdana İşleniyor...',
                onPressed: () async {
                  String? petition;
                  if (_generateFeeRefundPetition &&
                      _annualFeeRecords.isNotEmpty) {
                    final feeRecord = _annualFeeRecords.first;
                    petition =
                        DataExportService.instance.generateFeeRefundPetition(
                      bankName: widget.result.institution,
                      cardMask: widget.result.accountIdentifier,
                      feeAmountCents: _totalAnnualFeeCents,
                      feeDate: feeRecord.date,
                    );
                  }

                  final decision = SmartWizardDecisionResult(
                    cardOwnerAssignments: _cardAssignments,
                    scheduleFutureInstallments: _scheduleInstallments,
                    trackGoldCryptoAsAssets: _trackAssets,
                    confirmedSalaryTxIds: _selectedSalaryTxIds.toList(),
                    generateFeeRefundPetition: _generateFeeRefundPetition,
                    prioritizeEmergencyPayoff: _prioritizeEmergencyPayoff,
                    trackRecurringSubscriptions: _trackRecurringSubscriptions,
                    detectedFeeAmountCents: _annualFeeRecords.isNotEmpty
                        ? _totalAnnualFeeCents
                        : null,
                    feeRefundPetitionText: petition,
                  );
                  Navigator.pop(context, decision);
                },
                onVerificationComplete: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPetitionPreviewModal() {
    final feeRecord = _annualFeeRecords.first;
    final petitionText = DataExportService.instance.generateFeeRefundPetition(
      bankName: widget.result.institution,
      cardMask: widget.result.accountIdentifier,
      feeAmountCents: _totalAnnualFeeCents,
      feeDate: feeRecord.date,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Resmi Aidat İade Dilekçesi',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        size: 20, color: AppColors.actionPrimary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: petitionText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF10B981),
                          content: Text('Dilekçe metni panoya kopyalandı!'),
                        ),
                      );
                    },
                    tooltip: 'Dilekçeyi Kopyala',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    petitionText,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontFamily: 'monospace',
                        color: Color(0xFF1E293B)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Video 2: Morflayan Dilekçe Kopyalama & Paylaşma Butonu
              MorphingShareButton(
                fileName:
                    '${widget.result.institution}_Aidat_Iade_Dilekcesi.txt',
                label: 'Dilekçe Metnini Kopyala & Paylaş',
                accentColor: AppColors.actionPrimary,
                onDownloadComplete: () {
                  Clipboard.setData(ClipboardData(text: petitionText));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF10B981),
                      content: Text(
                          'Dilekçe metni panoya kopyalandı! Banka uygulamasına veya Tüketici Hakem Heyetine iletebilirsiniz.'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textPrimary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
