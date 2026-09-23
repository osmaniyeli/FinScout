// lib/features/wallets/presentation/wallet_selection_sheet.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../models/wallet.dart';
import '../repositories/wallet_repository.dart';

class WalletSelectionSheet extends StatefulWidget {
  final String title;
  final String? selectedWalletId;

  const WalletSelectionSheet({
    Key? key,
    this.title = 'İşlemlerin Aktarılacağı Cüzdanı Seçin',
    this.selectedWalletId,
  }) : super(key: key);

  static Future<Wallet?> show(BuildContext context,
      {String? title, String? selectedWalletId}) {
    return showModalBottomSheet<Wallet>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WalletSelectionSheet(
        title: title ?? 'İşlemlerin Aktarılacağı Cüzdanı Seçin',
        selectedWalletId: selectedWalletId,
      ),
    );
  }

  @override
  State<WalletSelectionSheet> createState() => _WalletSelectionSheetState();
}

class _WalletSelectionSheetState extends State<WalletSelectionSheet> {
  final WalletRepository _repo = WalletRepository.instance;
  late String _chosenWalletId;

  @override
  void initState() {
    super.initState();
    _chosenWalletId = widget.selectedWalletId ??
        (_repo.wallets.isNotEmpty ? _repo.wallets.first.id : 'wallet_checking');
    _repo.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showAddWalletDialog() {
    final nameController = TextEditingController();
    WalletType selectedType = WalletType.checking;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Yeni Cüzdan / Hesap Ekle',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Cüzdan / Hesap Adı',
                  hintText: 'Örn: Maaş Hesabım, Bonus Kart',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Cüzdan Türü:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<WalletType>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(
                      value: WalletType.checking,
                      child: Text('Vadesiz / Banka Hesabı')),
                  DropdownMenuItem(
                      value: WalletType.creditCard, child: Text('Kredi Kartı')),
                  DropdownMenuItem(
                      value: WalletType.cash, child: Text('Nakit Cüzdan')),
                  DropdownMenuItem(
                      value: WalletType.savings,
                      child: Text('Birikim / Yatırım')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedType = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Vazgeç',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final newWallet = Wallet(
                    id: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    type: selectedType,
                    balanceCents: 0,
                    colorHex: selectedType == WalletType.creditCard
                        ? '#DC2626'
                        : (selectedType == WalletType.cash
                            ? '#10B981'
                            : '#0284C7'),
                    createdAt: DateTime.now(),
                  );
                  await _repo.addWallet(newWallet);
                  if (mounted) {
                    setState(() {
                      _chosenWalletId = newWallet.id;
                    });
                  }
                  Navigator.pop(dialogCtx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ekle',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallets = _repo.wallets;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showAddWalletDialog,
                icon: const Icon(Icons.add_rounded,
                    size: 16, color: AppColors.actionPrimary),
                label: const Text(
                  'Yeni Cüzdan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.actionPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Hareketler bu cüzdanın bakiyesine ve geçmişine yansıtılacaktır.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...wallets.map((w) {
            final isSelected = w.id == _chosenWalletId;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                onTap: () {
                  setState(() => _chosenWalletId = w.id);
                },
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: w.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(w.type.iconData, color: w.color, size: 22),
                ),
                title: Text(
                  w.name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  '${w.type.displayName} • ${CurrencyNormalizer.formatCents(w.balanceCents)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: w.type == WalletType.creditCard && w.balanceCents > 0
                        ? AppColors.expenseRed
                        : AppColors.textSecondary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF3B82F6))
                    : const Icon(Icons.radio_button_unchecked_rounded,
                        color: Color(0xFFCBD5E1)),
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final selected = wallets.firstWhere(
                (w) => w.id == _chosenWalletId,
                orElse: () => _repo.getConsolidatedWallet(),
              );
              Navigator.pop(context, selected);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.actionPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Cüzdanı Onayla & Devam Et',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
