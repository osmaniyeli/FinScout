// DOSYA ADI: 20_UI_about_and_compliance_screen.dart
// HEDEF DİZİN: lib/features/about/presentation/20_UI_about_and_compliance_screen.dart

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class AboutAndComplianceScreen extends StatelessWidget {
  final Database db;
  final VoidCallback onDataWiped;

  const AboutAndComplianceScreen({
    Key? key,
    required this.db,
    required this.onDataWiped,
  }) : super(key: key);

  Future<void> _wipeAllUserData(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm Veriler Silinsin mi?'),
        content: const Text(
          'Bu işlem telefonunuzda saklanan tüm ekstre dökümlerini, harcama geçmişini ve kategori hafızasını kalıcı olarak yok eder. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Hepsini Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await db.transaction((txn) async {
        await txn.delete('transactions');
        await txn.delete('installments');
        await txn.delete('tax_deductions');
        await txn.delete('statements');
        await txn.delete('accounts');
        await txn.delete('user_category_rules');
        await txn.rawUpdate("UPDATE app_meta SET value = '0' WHERE key = 'current_month_pdf_count'");
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tüm yerel verileriniz başarıyla silindi.')),
        );
        onDataWiped();
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgCream = Color(0xFFFAF8F5);
    const Color cardBg = Colors.white;

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hakkında & Gizlilik',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. UYGULAMA KİMLİĞİ
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('🦉', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Paraİz (MoneyTrace)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Sürüm 2.1.0 (Build 2026.09)', style: TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. GİZLİLİK VE ZERO-KNOWLEDGE GARANTİSİ
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: Color(0xFF2E7D32), size: 20),
                    SizedBox(width: 8),
                    Text('Sıfır Sunucu Güvencesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Yüklediğiniz banka ekstreleri ve bordrolar harici hiçbir sunucuya yüklenmez. '
                  'Tüm analizler telefonunuzun kendi işlemcisinde yerel olarak yapılır. '
                  'TCKN, IBAN ve kart numaralarınız bellekte anında maskelenir.',
                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. YASAL VE REGÜLATİF BAĞLANTILAR
          Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, size: 20),
                  title: const Text('Gizlilik Politikası', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    // Gizlilik politikası URL yönlendirmesi
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: const Text('Kullanım Koşulları', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_rounded, size: 20),
                  title: const Text('Açık Kaynak Lisansları', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. VERİLERİ SİLME (GOOGLE PLAY 2026 ZORUNLULUĞU)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Veri Yönetimi ve Ayrılma',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFD32F2F)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Google Play politikaları uyarınca dilediğiniz an tek dokunuşla tüm verilerinizi ve kayıtlarınızı bu cihazdan tamamen silebilirsiniz.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Tüm Verilerimi ve Geçmişimi Sil'),
                  onPressed: () => _wipeAllUserData(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}