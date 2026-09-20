// lib/features/family_budget/presentation/family_budget_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../../../core/widgets/morphing_share_button.dart';
import '../../../core/widgets/radar_checkout_button.dart';
import '../../../core/services/user_profile_service.dart';

class FamilyMember {
  final String id;
  final String name;
  final String role;
  final String joinedDate;
  final String initials;
  final String? assignedCardMask;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.role,
    required this.joinedDate,
    required this.initials,
    this.assignedCardMask,
  });
}

class FamilyBudgetSheet extends StatefulWidget {
  const FamilyBudgetSheet({Key? key}) : super(key: key);

  @override
  State<FamilyBudgetSheet> createState() => _FamilyBudgetSheetState();
}

class _FamilyBudgetSheetState extends State<FamilyBudgetSheet> {
  String _inviteCode = '429YJD';
  bool _isPrivateRecordsEnabled = false;

  // Aile Boyu Üyelik Paketi: Maksimum 4 Kişi (1 Asıl + 3 Aile Bireyi)
  final int _maxFamilyMembers = 4;
  late final List<FamilyMember> _members = [
    FamilyMember(
      id: 'mem_1',
      name: '${UserProfileService.instance.profile?.name ?? "Kullanıcı"} (sen)',
      role: 'Sahip (Asıl Kart)',
      joinedDate: 'Oluşturuldu',
      initials: (UserProfileService.instance.profile?.name ?? 'K').trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
      assignedCardMask: 'Asıl Kart',
    ),
  ];

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Davet kodu panoya kopyalandı!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _refreshCode() {
    setState(() {
      _inviteCode = 'MT${(1000 + DateTime.now().millisecond % 9000)}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yeni davet kodu üretildi!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addNewMember() {
    if (_members.length >= _maxFamilyMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aile Paketinizde maksimum 4 kişi sınırına ulaşıldı.'),
          backgroundColor: AppColors.installment,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final roleController = TextEditingController(text: 'Çocuk / Aile Üyesi');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Aile Bireyi Ekle',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                hintText: 'Örn: Can Aydın',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleController,
              decoration: const InputDecoration(
                labelText: 'Rol / Kart Bağı',
                hintText: 'Örn: Ek Kart 2',
              ),
            ),
            const SizedBox(height: 16),
            // Video 4: Radar Dalgalı Doğrulama ve Güvenli Birey Ekleme Butonu
            RadarCheckoutButton(
              label: 'Bireyi Doğrula ve Ekle',
              idleAmountText: '${_members.length + 1}/$_maxFamilyMembers Kişi',
              verifyingAmountText: 'Kayıt Yapılıyor...',
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final name = nameController.text.trim();
                  final initials = name.split(' ').map((w) => w[0]).take(2).join('').toUpperCase();
                  setState(() {
                    _members.add(FamilyMember(
                      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      role: roleController.text.trim(),
                      joinedDate: 'Yeni Katıldı',
                      initials: initials,
                    ));
                  });
                }
              },
              onVerificationComplete: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text('${nameController.text} aile bütçenize eklendi.'),
                  ),
                );
              },
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: 30,
      ),
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
            const SizedBox(height: 16),

            // Başlık & Aile Paketi Rozeti
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
                      child: const Icon(Icons.group_rounded, color: AppColors.actionPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Aile Bütçemiz',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                PulseMetricBadge(
                  label: 'KONTENJAN',
                  value: '${_members.length}/$_maxFamilyMembers KİŞİ',
                  pulseColor: AppColors.actionPrimary,
                  isPositive: _members.length < _maxFamilyMembers,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Davet Kodu Kartı
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AİLE KATILIM KODU',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _inviteCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 2.0,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 22),
                        onPressed: _copyCode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Video 2: Morflayan Davet Paylaşım Butonu
                  MorphingShareButton(
                    fileName: 'Aile_Daveti_$_inviteCode.txt',
                    label: 'Davet Kodunu Paylaş & Gönder',
                    accentColor: AppColors.actionPrimary,
                    onDownloadComplete: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Davet kodu paylaşıldı.')),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _refreshCode,
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.textSecondary),
                      label: const Text('Yeni Kod Üret', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Aile Boyu Üyelik ile 4 kişiye kadar tek çatı altında bütçe, ekstre ve hedef takibi.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Üyeler Başlığı + Yeni Üye Butonu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Üyeler (${_members.length}/$_maxFamilyMembers)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                if (_members.length < _maxFamilyMembers)
                  TextButton.icon(
                    onPressed: _addNewMember,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.actionPrimary),
                    label: const Text(
                      'Üye Ekle',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.actionPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            ..._members.map((m) {
              final isOwner = m.role.contains('Sahip');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMemberRow(
                  member: m,
                  isOwner: isOwner,
                  onDelete: isOwner
                      ? null
                      : () {
                          setState(() {
                            _members.removeWhere((item) => item.id == m.id);
                          });
                        },
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            // Gizlilik Kutusu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.lock_rounded, color: AppColors.scout, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Kişisel Harcamalarımı Gizle',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Özel işaretlediğin işlemler diğer aile üyelerine görünmez',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPrivateRecordsEnabled,
                    activeColor: AppColors.scout,
                    onChanged: (val) => setState(() => _isPrivateRecordsEnabled = val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow({
    required FamilyMember member,
    required bool isOwner,
    VoidCallback? onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isOwner ? const Color(0xFF0A0F1D) : const Color(0xFFE2E8F0),
            child: Text(
              member.initials,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isOwner ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                Text(
                  member.assignedCardMask != null
                      ? '${member.role} • ${member.assignedCardMask}'
                      : member.role,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.expenseRed),
              onPressed: onDelete,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
        ],
      ),
    );
  }
}
