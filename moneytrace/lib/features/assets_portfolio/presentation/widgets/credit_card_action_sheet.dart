// lib/features/assets_portfolio/presentation/widgets/credit_card_action_sheet.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_normalizer.dart';
import '../../../../core/utils/thousands_input_formatter.dart';

/// Ödemenin çıktığı gerçek hesap: nakit cüzdan ya da ekstresi yüklenmiş vadesiz hesap.
class PaymentSource {
  /// accounts.id; null ise nakit cüzdan (acc_manual_cash) kullanılır.
  final String? accountId;
  final String label;
  const PaymentSource({required this.accountId, required this.label});
}

/// "Ödemeyi kaydet": FinScout ödeme yapmaz, kullanıcının bankada yaptığı kart ödemesini kayda geçirir.
/// Kayıt nötrdür (CARDPAYMENT): gelir ya da gider sayılmaz. Dönem borcu yine ekstreden okunur.
class CreditCardActionSheet extends StatefulWidget {
  final Map<String, dynamic> card;

  /// Kaydı yazar; hata olursa fırlatır (sayfa hatayı gösterir, başarı mesajı yalnız kayıttan sonra).
  final Future<void> Function(int paidCents, PaymentSource source, DateTime date) onPaymentRecorded;

  final List<PaymentSource> sourceAccounts;

  const CreditCardActionSheet({
    Key? key,
    required this.card,
    required this.onPaymentRecorded,
    required this.sourceAccounts,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> card,
    required Future<void> Function(int paidCents, PaymentSource source, DateTime date)
        onPaymentRecorded,
    required List<PaymentSource> sourceAccounts,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreditCardActionSheet(
        card: card,
        onPaymentRecorded: onPaymentRecorded,
        sourceAccounts: sourceAccounts,
      ),
    );
  }

  @override
  State<CreditCardActionSheet> createState() => _CreditCardActionSheetState();
}

class _CreditCardActionSheetState extends State<CreditCardActionSheet> {
  final TextEditingController _amountController = TextEditingController();
  late final List<PaymentSource> _sources;
  late PaymentSource _selectedSource;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  int? get _debtCents => (widget.card['debt_cents'] as num?)?.toInt();
  int? get _minimumCents => (widget.card['minimum_cents'] as num?)?.toInt();

  @override
  void initState() {
    super.initState();
    _sources = widget.sourceAccounts.isEmpty
        ? const [PaymentSource(accountId: null, label: 'Nakit Cüzdan')]
        : widget.sourceAccounts;
    _selectedSource = _sources.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Kuruşu giriş kutusu biçimine çevirir: 125050 → "1.250,50"
  static String _toInput(int cents) {
    final whole = ThousandsInputFormatter.format('${cents ~/ 100}');
    final frac = cents % 100;
    return frac == 0 ? whole : '$whole,${frac.toString().padLeft(2, '0')}';
  }

  void _fill(int cents) => setState(() {
        _amountController.text = _toInput(cents);
        _error = null;
      });

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final paidCents = CurrencyNormalizer.toMinorUnits(_amountController.text.trim());
    if (paidCents <= 0) {
      setState(() => _error = 'Ödediğin tutarı gir.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onPaymentRecorded(paidCents, _selectedSource, _date);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.incomeGreen,
        content: Text(
            '${widget.card['name']} kart ödemesi kaydedildi: ${CurrencyNormalizer.formatCents(paidCents)} (${_selectedSource.label}).'),
      ));
    } catch (e) {
      debugPrint('Kart ödemesi kaydedilemedi: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Ödeme kaydedilemedi. Lütfen tekrar dene.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = (widget.card['color'] as Color?) ?? AppColors.actionPrimary;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final debt = _debtCents;
    final minimum = _minimumCents;

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.12),
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
                        'Ödemeyi kaydet: ${widget.card['name']}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        widget.card['mask']?.toString() ?? '',
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
            const SizedBox(height: 10),
            const Text(
              'FinScout ödeme yapmaz, yaptığın ödemeyi kayda geçirir. '
              'Kayıt gelir ya da gider sayılmaz; dönem borcu bir sonraki ekstreden okunur.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),

            // Son ekstrede bankanın yazdığı değerler
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
                  _summaryItem('Dönem borcu',
                      debt != null ? CurrencyNormalizer.formatCents(debt) : '—', AppColors.expenseRed),
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  _summaryItem('Asgari ödeme',
                      minimum != null ? CurrencyNormalizer.formatCents(minimum) : '—',
                      AppColors.textPrimary),
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  _summaryItem('Son ödeme', widget.card['due']?.toString() ?? '—',
                      AppColors.actionPrimary),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if ((minimum != null && minimum > 0) || (debt != null && debt > 0)) ...[
              Row(
                children: [
                  if (minimum != null && minimum > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _fill(minimum),
                        child: const Text('Asgari'),
                      ),
                    ),
                  if (minimum != null && minimum > 0 && debt != null && debt > 0)
                    const SizedBox(width: 8),
                  if (debt != null && debt > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _fill(debt),
                        child: const Text('Dönem borcu'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _amountController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [ThousandsInputFormatter()],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: const InputDecoration(
                labelText: 'Ödediğin tutar (₺)',
                prefixText: '₺ ',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _sources.indexOf(_selectedSource),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ödemenin çıktığı hesap'),
              items: [
                for (var i = 0; i < _sources.length; i++)
                  DropdownMenuItem(value: i, child: Text(_sources[i].label)),
              ],
              onChanged: _saving
                  ? null
                  : (i) {
                      if (i != null) setState(() => _selectedSource = _sources[i]);
                    },
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_rounded, size: 20),
              title: const Text('Ödeme tarihi', style: TextStyle(fontSize: 13)),
              trailing: Text(_formatDate(_date),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: _saving ? null : _pickDate,
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.expenseRed, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Ödemeyi kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
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
}
