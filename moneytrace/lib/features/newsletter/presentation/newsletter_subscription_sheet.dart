// lib/features/newsletter/presentation/newsletter_subscription_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/radar_checkout_button.dart';
import '../../../core/config/remote_config_service.dart';

class NewsletterSubscriptionSheet extends StatefulWidget {
  const NewsletterSubscriptionSheet({Key? key}) : super(key: key);

  @override
  State<NewsletterSubscriptionSheet> createState() =>
      _NewsletterSubscriptionSheetState();
}

class _NewsletterSubscriptionSheetState
    extends State<NewsletterSubscriptionSheet> {
  final TextEditingController _emailController = TextEditingController();
  late String _newsletterLanguage;
  bool _sendWeeklySummary = true;
  bool _sendGoldAlerts = true;

  @override
  void initState() {
    super.initState();
    _newsletterLanguage = RemoteConfigService.instance.appLanguage;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitSubscription() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir e-posta adresi girin.'),
          backgroundColor: AppColors.expenseRed,
        ),
      );
      return;
    }

    final langText = _newsletterLanguage == 'en' ? 'English' : 'Türkçe';
    final weeklyText = _sendWeeklySummary ? 'Evet' : 'Hayır';
    final goldText = _sendGoldAlerts ? 'Evet' : 'Hayır';

    final String subject = Uri.encodeComponent('Bülten Aboneliği');
    final String body = Uri.encodeComponent(
        'E-posta: $email\nDil: $langText\nHaftalık Karne: $weeklyText\nKritik Fiyat Bildirimleri: $goldText');
    final Uri mailUri =
        Uri.parse('mailto:pulcratechnology@gmail.com?subject=$subject&body=$body');

    try {
      final bool launched =
          await launchUrl(mailUri, mode: LaunchMode.externalApplication);
      if (launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.incomeGreen,
              content:
                  Text('E-posta uygulamanız açıldı, göndermeyi tamamlayın.'),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          _showCopyFallback(email, langText, weeklyText, goldText);
        }
      }
    } catch (_) {
      if (mounted) {
        _showCopyFallback(email, langText, weeklyText, goldText);
      }
    }
  }

  void _showCopyFallback(
      String email, String lang, String weekly, String gold) {
    final content =
        'Alıcı: pulcratechnology@gmail.com\nKonu: Bülten Aboneliği\nE-posta: $email\nDil: $lang\nHaftalık Karne: $weekly\nFiyat Bildirimleri: $gold';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'E-posta Açılamadı',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'E-posta istemcisi otomatik başlatılamadı. Bültene abone olmak için aşağıdaki bilgileri kopyalayıp pulcratechnology@gmail.com adresine gönderebilirsiniz:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                content,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bilgiler panoya kopyalandı!')),
              );
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Kopyala & Kapat'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.mark_email_unread_rounded,
                      color: AppColors.actionPrimary, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Haftalık Finans Bülteni',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      'Harcama raporları ve piyasa analizleri e-postanda',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppColors.textMuted),
                labelText: 'E-Posta Adresiniz',
                hintText: 'ornek@email.com',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bülten Dili / Language:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setState(() => _newsletterLanguage = 'tr'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _newsletterLanguage == 'tr'
                                    ? const Color(0xFFDCFCE7)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _newsletterLanguage == 'tr'
                                      ? const Color(0xFF166534)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                'Türkçe 🇹🇷',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _newsletterLanguage == 'tr'
                                      ? const Color(0xFF166534)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _newsletterLanguage = 'en'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _newsletterLanguage == 'en'
                                    ? const Color(0xFFEFF6FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _newsletterLanguage == 'en'
                                      ? AppColors.actionPrimary
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                'English 🇬🇧',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _newsletterLanguage == 'en'
                                      ? AppColors.actionPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Haftalık Harcama & Tasarruf Karnesi',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      Switch(
                        value: _sendWeeklySummary,
                        activeThumbColor: AppColors.actionPrimary,
                        onChanged: (val) =>
                            setState(() => _sendWeeklySummary = val),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Altın & Döviz Kritik Fiyat Bildirimleri',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      Switch(
                        value: _sendGoldAlerts,
                        activeThumbColor: AppColors.actionPrimary,
                        onChanged: (val) =>
                            setState(() => _sendGoldAlerts = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            RadarCheckoutButton(
              label: 'Bültene Doğrula & Abone Ol',
              idleAmountText: 'Ücretsiz',
              verifyingAmountText: 'Hazırlanıyor...',
              onPressed: () async {
                await _submitSubscription();
              },
              onVerificationComplete: () {},
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'İstediğin zaman tek tıkla abonelikten çıkabilirsin. Asla spam gönderilmez.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
