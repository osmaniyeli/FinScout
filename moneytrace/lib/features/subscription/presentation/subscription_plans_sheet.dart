import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/radar_checkout_button.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../services/subscription_service.dart';

class SubscriptionPlansSheet extends StatefulWidget {
  final VoidCallback? onSubscriptionUpdated;

  const SubscriptionPlansSheet({
    Key? key,
    this.onSubscriptionUpdated,
  }) : super(key: key);

  static void show(BuildContext context,
      {VoidCallback? onSubscriptionUpdated}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SubscriptionPlansSheet(
        onSubscriptionUpdated: onSubscriptionUpdated,
      ),
    );
  }

  @override
  State<SubscriptionPlansSheet> createState() => _SubscriptionPlansSheetState();
}

class _SubscriptionPlansSheetState extends State<SubscriptionPlansSheet> {
  final SubscriptionService _service = SubscriptionService.instance;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _service.tierNotifier.addListener(_onTierChanged);
    _service.isPurchasingNotifier.addListener(_onPurchasingChanged);
    _isProcessing = _service.isPurchasingNotifier.value;
  }

  @override
  void dispose() {
    _service.tierNotifier.removeListener(_onTierChanged);
    _service.isPurchasingNotifier.removeListener(_onPurchasingChanged);
    super.dispose();
  }

  void _onTierChanged() {
    if (_service.isPremium) {
      widget.onSubscriptionUpdated?.call();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.incomeGreen,
            content:
                Text('Tebrikler! Premium üyeliğiniz başarıyla aktif edildi.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onPurchasingChanged() {
    if (mounted) {
      setState(() {
        _isProcessing = _service.isPurchasingNotifier.value;
      });

      if (!_isProcessing && _service.lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expenseRed,
            content: Text(_service.lastError!),
          ),
        );
      }
    }
  }

  Future<void> _selectPackage(SubscriptionPackage pkg) async {
    final success = await _service.purchasePackage(pkg);
    if (!success && mounted) {
      final errorMsg = _service.lastError ??
          'Satın alma işlemi başlatılamadı. Lütfen tekrar deneyin.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.expenseRed,
          content: Text(errorMsg),
        ),
      );
    }
  }

  Future<void> _restorePurchases() async {
    final success = await _service.restorePurchases();
    if (!success && mounted) {
      final errorMsg = _service.lastError ??
          'Satın alımları geri yükleme işlemi başlatılamadı.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.expenseRed,
          content: Text(errorMsg),
        ),
      );
    } else if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.actionPrimary,
          content: Text(
              'Satın alımları geri yükleme isteği gönderildi. Lütfen bekleyin...'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sürükleme Çubuğu
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

            // Başlık & Premium İkonu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded,
                          color: Color(0xFFD97706), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Paraİz Premium Paketleri',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          'Sınırsız PDF Ekstre, Aile Bütçesi & Finansal Zeka',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Paket Listesi
            ..._service.availablePackages.map((pkg) {
              final isFamily = pkg.tier == SubscriptionTier.familyPremium;
              final isAnnual = pkg.identifier.contains('annual') && !isFamily;
              final isCurrent = _service.currentTier == pkg.tier;

              // Fiyatı Google Play mağazasından çek, yoksa varsayılanı kullan
              final productDetails = _service.products[pkg.identifier];
              final displayPrice = productDetails?.price ?? pkg.priceFormatted;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isFamily
                      ? const Color(0xFFF0FDF4)
                      : (isAnnual
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isFamily
                        ? AppColors.incomeGreen
                        : (isAnnual
                            ? AppColors.actionPrimary
                            : const Color(0xFFE2E8F0)),
                    width: isFamily || isAnnual ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              pkg.title,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary),
                            ),
                            if (isFamily) ...[
                              const SizedBox(width: 8),
                              const PulseMetricBadge(
                                label: '4 KİŞİLİK',
                                value: 'AİLE',
                                pulseColor: Color(0xFF16A34A),
                                isPositive: true,
                              ),
                            ] else if (isAnnual) ...[
                              const SizedBox(width: 8),
                              const PulseMetricBadge(
                                label: 'AVANTAJ',
                                value: '2 AY HEDİYE',
                                pulseColor: AppColors.actionPrimary,
                                isPositive: true,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          displayPrice,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isFamily
                                ? AppColors.incomeGreen
                                : (isAnnual
                                    ? AppColors.actionPrimary
                                    : AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pkg.description,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3),
                    ),
                    const SizedBox(height: 12),
                    if (isCurrent)
                      Container(
                        width: double.infinity,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF15803D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Mevcut Aktif Planınız ✓',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      )
                    else
                      RadarCheckoutButton(
                        label: isFamily
                            ? 'Aile Paketine Geç (4 Kişi)'
                            : 'Paketi Doğrula & Başlat',
                        idleAmountText: displayPrice,
                        verifyingAmountText: 'Store Doğrulanıyor...',
                        onPressed:
                            _isProcessing ? null : () => _selectPackage(pkg),
                        onVerificationComplete: () {},
                      ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 10),

            // Satın Alımları Geri Yükle
            Center(
              child: TextButton.icon(
                onPressed: _isProcessing ? null : _restorePurchases,
                icon: const Icon(Icons.restore_rounded,
                    size: 16, color: AppColors.textSecondary),
                label: const Text(
                  'Geçmiş Satın Alımları Geri Yükle',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
