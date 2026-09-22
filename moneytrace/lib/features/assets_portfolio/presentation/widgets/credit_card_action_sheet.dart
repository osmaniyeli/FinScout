// lib/features/assets_portfolio/presentation/widgets/credit_card_action_sheet.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_normalizer.dart';
import '../../../../core/widgets/fintech/fintech_components.dart';

class CreditCardActionSheet extends StatefulWidget {
  final Map<String, dynamic> card;
  final Function(Map<String, dynamic> updatedCard) onCardUpdated;
  final Function(int paidCents, String paymentAccount) onDebtPaid;

  const CreditCardActionSheet({
    Key? key,
    required this.card,
    required this.onCardUpdated,
    required this.onDebtPaid,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> card,
    required Function(Map<String, dynamic> updatedCard) onCardUpdated,
    required Function(int paidCents, String paymentAccount) onDebtPaid,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreditCardActionSheet(
        card: card,
        onCardUpdated: onCardUpdated,
        onDebtPaid: onDebtPaid,
      ),
    );
  }

  @override
  State<CreditCardActionSheet> createState() => _CreditCardActionSheetState();
}

class _CreditCardActionSheetState extends State<CreditCardActionSheet> {
  bool _isSecondaryMode = false; // false: Borç Öde, true: Limit & Kesim Düzenle

  // Borç Öde Controller & Hesap
  late TextEditingController _paymentAmountController;
  String _selectedSourceAccount = 'Nakit Cüzdan';
  final List<String> _sourceAccounts = [
    'Nakit Cüzdan',
    'Garanti BBVA Ana Hesap',
    'İş Bankası Vadesiz',
    'Yapı Kredi Vadesiz',
  ];

  // Limit & Kesim Controller
  late TextEditingController _limitController;
  late TextEditingController _debtController;
  late TextEditingController _dayController;

  @override
  void initState() {
    super.initState();
    final rawDebt = widget.card['debt'].toString().replaceAll('₺', '').replaceAll(',00', '').replaceAll('.', '').trim();
    final rawLimit = widget.card['limit'].toString().replaceAll('₺', '').replaceAll(',00', '').replaceAll('.', '').trim();

    _paymentAmountController = TextEditingController(text: rawDebt);
    _limitController = TextEditingController(text: rawLimit);
    _debtController = TextEditingController(text: rawDebt);
    _dayController = TextEditingController(text: widget.card['statement_day']?.toString() ?? 'Her ayın 15\'i');
  }

  @override
  void dispose() {
    _paymentAmountController.dispose();
    _limitController.dispose();
    _debtController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _selectQuickAmountRatio(double ratio) {
    final rawDebtStr = widget.card['debt'].toString().replaceAll('₺', '').replaceAll('.', '').replaceAll(',', '.').trim();
    final debtNum = double.tryParse(rawDebtStr) ?? 0.0;
    final targetAmount = (debtNum * ratio).round();

    setState(() {
      _paymentAmountController.text = targetAmount > 0 ? targetAmount.toString() : '0';
    });
  }

  void _submitDebtPayment() {
    final amountText = _paymentAmountController.text.trim();
    final paidCents = CurrencyNormalizer.toMinorUnits(amountText);

    if (paidCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.expenseRed,
          content: Text('Lütfen geçerli bir ödeme tutarı girin (0\'dan büyük olmalıdır).'),
        ),
      );
      return;
    }

    final currentDebtCents = CurrencyNormalizer.toMinorUnits(widget.card['debt'].toString());
    final newDebtCents = (currentDebtCents - paidCents).clamp(0, double.infinity).toInt();

    setState(() {
      widget.card['debt'] = CurrencyNormalizer.formatCents(newDebtCents);
    });

    widget.onDebtPaid(paidCents, _selectedSourceAccount);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF059669),
        content: Text(
          '${widget.card['name']} kartına ${CurrencyNormalizer.formatCents(paidCents)} borç ödemesi $_selectedSourceAccount üzerinden yapıldı.',
        ),
      ),
    );
  }

  void _submitCardDetails() {
    final limitText = _limitController.text.trim();
    final debtText = _debtController.text.trim();
    final dayText = _dayController.text.trim();

    final limitCents = CurrencyNormalizer.toMinorUnits(limitText);
    final debtCents = CurrencyNormalizer.toMinorUnits(debtText);

    final updatedCard = Map<String, dynamic>.from(widget.card);

    if (limitText.isNotEmpty) {
      updatedCard['limit'] = CurrencyNormalizer.formatCents(limitCents);
    }
    if (debtText.isNotEmpty) {
      updatedCard['debt'] = CurrencyNormalizer.formatCents(debtCents);
    }
    if (dayText.isNotEmpty) {
      updatedCard['statement_day'] = dayText;
    }

    widget.onCardUpdated(updatedCard);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF7C3AED),
        content: Text('${widget.card['name']} limit ve hesap kesim detayları başarıyla güncellendi.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = (widget.card['color'] as Color?) ?? const Color(0xFF2563EB);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Tutamaç
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
            const SizedBox(height: 14),

            // Kart Bilgisi Başlığı
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.credit_card_rounded, color: cardColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.card['name'] as String,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${widget.card['mask']} • ${widget.card['holder']}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Özet Bant (Dönem Borcu, Limit, Kesim Günü)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Dönem Borcu', widget.card['debt'].toString(), AppColors.expenseRed),
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  _buildSummaryItem('Toplam Limit', widget.card['limit'].toString(), AppColors.textPrimary),
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  _buildSummaryItem('Kesim Günü', widget.card['statement_day']?.toString() ?? '15\'i', AppColors.actionPrimary),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ==========================================
            // FRONTEND JOE SLIDING OVERLAY DUAL-CARD
            // ==========================================
            SlidingOverlayCard(
              height: 175,
              borderRadius: 20,
              isSecondary: _isSecondaryMode,
              onToggle: (toSecondary) {
                setState(() => _isSecondaryMode = toSecondary);
              },
              // 1. Birincil Kapak: BORÇ ÖDE
              primaryHeroTitle: 'BORÇ ÖDE',
              primaryHeroSubtitle: 'Kart borcunu hesabından kapat.',
              primaryButtonText: 'LİMİT DÜZENLE ➔',
              primaryGradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF059669), Color(0xFF0F172A)],
              ),
              primaryForm: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.payment_rounded, color: Color(0xFF059669), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'HIZLI ÖDEME',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Asgari veya dönem borcunu seçip anında kapatın.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                  ),
                ],
              ),
              // 2. İkincil Kapak: LİMİT & KESİM DÜZENLE
              secondaryHeroTitle: 'LİMİT & KESİM',
              secondaryHeroSubtitle: 'Kart limitini & gününü güncelle.',
              secondaryButtonText: 'BORÇ ÖDE ➔',
              secondaryGradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7C3AED), Color(0xFF0F172A)],
              ),
              secondaryForm: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: Color(0xFF7C3AED), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'KART AYARLARI',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Limit, borç ve kesim günü detaylarını revize edin.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ==========================================
            // DİNAMİK FORM ALANI (Borç Öde vs Limit Düzenle)
            // ==========================================
            AnimatedCrossFade(
              firstChild: _buildPaymentForm(),
              secondChild: _buildEditLimitForm(),
              crossFadeState: _isSecondaryMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 320),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTheme.numericStyle.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // FORM 1: BORÇ ÖDEME FORMU
  // ==========================================
  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ödeme Tutarı Seçimi',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),

          // Hızlı Tutar Seçim Butonları (Asgari %20, Tamamı %100, Yarısı %50)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _selectQuickAmountRatio(0.20),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Asgari (%20)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _selectQuickAmountRatio(0.50),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Yarısı (%50)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _selectQuickAmountRatio(1.0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Tamamı', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tutar Giriş TextField
          const Text(
            'Ödenecek Tutar (TL) *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _paymentAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Örn: 5000',
              prefixText: '₺ ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // Ödeme Kaynak Hesabı
          const Text(
            'Ödeme Yapılacak Kaynak Hesap',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSourceAccount,
                isExpanded: true,
                items: _sourceAccounts.map((acc) => DropdownMenuItem(
                  value: acc,
                  child: Text(acc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSourceAccount = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Borç Öde Onay Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submitDebtPayment,
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Borç Ödemesini Tamamla', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FORM 2: LİMİT & KESİM DÜZENLEME FORMU
  // ==========================================
  Widget _buildEditLimitForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kart Limit & Kesim Bilgileri',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),

          // Toplam Limit
          const Text('Toplam Limit (TL)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Örn: 75000',
              prefixText: '₺ ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),

          // Güncel Dönem Borcu
          const Text('Güncel Dönem Borcu (TL)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: _debtController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Örn: 12500',
              prefixText: '₺ ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),

          // Hesap Kesim Günü
          const Text('Hesap Kesim / Yenilenme Günü', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: _dayController,
            decoration: InputDecoration(
              hintText: 'Örn: Her ayın 15\'i',
              prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
            ),
          ),
          const SizedBox(height: 18),

          // Değişiklikleri Kaydet Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submitCardDetails,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Değişiklikleri Kaydet', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
