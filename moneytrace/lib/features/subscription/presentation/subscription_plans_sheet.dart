import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_links.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../services/subscription_service.dart';
import '../../family/presentation/family_screen.dart';

class SubscriptionPlansSheet extends StatefulWidget {
  final VoidCallback? onSubscriptionUpdated;

  const SubscriptionPlansSheet({
    super.key,
    this.onSubscriptionUpdated,
  });

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

  /// Google Play ödeme ekranını açar. Premium ancak Google satın almayı onayladığında (purchaseStream) açılır;
  /// bu yüzden düğme hiçbir durumda "başarılı" animasyonu oynatmaz (false döner).
  Future<bool> _selectPackage(SubscriptionPackage pkg) async {
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
    return false;
  }

  Future<void> _restorePurchases() async {
    final success = await _service.restorePurchases();
    if (!success && mounted) {
      final errorMsg = _service.lastError ??
          'Bu Google hesabında ve FinScout hesabında etkin bir abonelik bulunamadı.';
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
          content: Text('Aboneliğin sunucuda doğrulandı ve etkin.'),
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FinScout Premium Paketleri',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          'Aylık belge kotası artar, reklam yok, veriler telefonunda',
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
              // Yalnız kullanıcının KENDİ doğrulanmış aboneliği "mevcut plan" sayılır (aile üyeliği değil)
              final isCurrent = _service.ownProductId == pkg.identifier;

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
                                value: '%37 TASARRUF',
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
                    if (isFamily)
                      TextButton.icon(
                        onPressed: () => FamilyScreen.showHowItWorks(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          foregroundColor: AppColors.incomeGreen,
                        ),
                        icon: const Icon(Icons.help_outline_rounded, size: 16),
                        label: const Text('Aile nasıl çalışır?',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    if (_service.hasTrial(pkg.identifier) && !isCurrent) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'İlk 7 gün ücretsiz; deneme bitmeden iptal edersen ücret alınmaz.',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669)),
                      ),
                    ],
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
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton(
                          onPressed:
                              _isProcessing ? null : () => _selectPackage(pkg),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.actionPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('$displayPrice ile başlat',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              );
            }),

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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Abonelik, iptal edilmedikçe dönem sonunda aynı fiyattan otomatik yenilenir. '
                'İptal ve ödeme yöntemi Google Play üzerinden yönetilir; iptal, dönem sonuna kadar geçerli olur.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, height: 1.4, color: AppColors.textSecondary),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () =>
                      AppLinks.open(AppLinks.manageSubscriptions()),
                  child: const Text('Aboneliği yönet / iptal et',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () => AppLinks.open(AppLinks.privacyPolicy),
                  child: const Text('Gizlilik politikası',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
