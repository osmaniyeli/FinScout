// lib/features/navigation/tab_add_actions.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../quick_entry/presentation/quick_entry_sheet.dart';

/// + (FAB) menüsündeki tek seçenek.
class TabAddAction {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onSelected;

  const TabAddAction({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onSelected,
  });
}

/// Alt sekme ekranlarının State sınıfları bunu uygular. Ana iskelet, ekranın `GlobalKey`'i üzerinden
/// o an geçerli ekleme seçeneklerini okur; her sekme kendi ekleme akışlarını kendi içinde tutar.
abstract class TabAddActions {
  /// O anki duruma göre (ör. hedef var mı, kart var mı) sunulacak ekleme seçenekleri.
  List<TabAddAction> get addActions;
}

/// Manuel gelir/gider formu. Kayıt, doğrulama ve sonuç mesajı sayfanın içinde
/// (saveManualTransaction → DataChanges.notify).
Future<void> openQuickEntrySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const QuickEntrySheet(),
  );
}

/// Sekmeye özgü kısa ekleme menüsü. Tek seçenek varsa menü açılmadan doğrudan çalışır.
Future<void> showTabAddMenu(
    BuildContext context, String title, List<TabAddAction> actions) async {
  if (actions.isEmpty) return;
  if (actions.length == 1) {
    actions.first.onSelected();
    return;
  }
  final selected = await showModalBottomSheet<TabAddAction>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 8),
            for (final a in actions)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(a.icon, color: AppColors.actionPrimary, size: 22),
                ),
                title: Text(a.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: a.subtitle == null
                    ? null
                    : Text(a.subtitle!,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
                onTap: () => Navigator.pop(ctx, a),
              ),
          ],
        ),
      ),
    ),
  );
  // Menü kapandıktan sonra seçilen akış açılır (iç içe alt sayfa olmasın).
  selected?.onSelected();
}
