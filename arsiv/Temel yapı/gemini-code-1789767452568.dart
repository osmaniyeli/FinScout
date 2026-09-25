// DOSYA ADI: 14_UI_dashboard_screen.dart
// HEDEF DİZİN: lib/features/dashboard/presentation/14_UI_dashboard_screen.dart

import 'package:flutter/material.dart';
import '../models/10_UI_dashboard_view_state.dart';
import '../controllers/13_CONTROLLER_dashboard_controller.dart';

class DashboardScreen extends StatefulWidget {
  final DashboardController controller;

  const DashboardScreen({Key? key, required this.controller}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadPeriodData('2026-06');
  }

  @override
  Widget build(BuildContext context) {
    const Color bgCream = Color(0xFFFAF8F5);
    const Color cardBg = Colors.white;
    const Color greenIncome = Color(0xFF2E7D32);
    const Color redExpense = Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.black87),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Paraİz',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE0E0E0),
              child: Icon(Icons.person, size: 20, color: Colors.black54),
            ),
            onPressed: () {},
          ),
        ],
      ),
      drawer: _buildLeftDrawer(context),
      body: StreamBuilder<DashboardViewState>(
        stream: widget.controller.stateStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.black87));
          }

          final state = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. İZCİ PERSONA VE KONUŞMA BALONU
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('🦉', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.scoutFeedback.badgeText,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.scoutFeedback.message,
                              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. GELİR - GİDER - NET FARK KARTI
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricCol('TOPLAM GELİR', state.totalIncomeCents, greenIncome),
                      _buildMetricCol('TOPLAM GİDER', state.totalExpenseCents, redExpense),
                      _buildMetricCol('NET FARK', state.netBalanceCents, Colors.black87),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. GELECEK AYIN TAKSİT BLOKAJI
                if (state.nextMonthCommittedInstallmentsCents > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gelecek Ayın Taksit Yükü',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
                        ),
                        Text(
                          '₺${(state.nextMonthCommittedInstallmentsCents / 100).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // 4. DEVLET PAYI VE VERGİ KESİNTİLERİ
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Devlet Payı & Vergiler', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '%${state.taxSummary.stateShareRatio}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: redExpense, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMetricCol(String label, int cents, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45)),
        const SizedBox(height: 6),
        Text(
          '₺${(cents / 100).toStringAsFixed(2)}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildLeftDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: const [
          DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFFFAF8F5)),
            child: Text('Paraİz Menü', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          ListTile(leading: Icon(Icons.credit_card), title: Text('Hesaplarım & Kartlarım')),
          ListTile(leading: Icon(Icons.receipt_long), title: Text('Yüklenen Belgeler')),
          ListTile(leading: Icon(Icons.subscriptions), title: Text('Abonelikler')),
          ListTile(leading: Icon(Icons.account_balance), title: Text('Vergi Analitiği')),
          ListTile(leading: Icon(Icons.settings), title: Text('Ayarlar & Güvenlik')),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarStyle.fixed,
      selectedItemColor: Colors.black87,
      unselectedItemColor: Colors.black38,
      backgroundColor: Colors.white,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Ana Sayfa'),
        BottomNavigationBarItem(icon: Icon(Icons.document_scanner), label: 'Ekstre Tara'),
        BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Trendler'),
        BottomNavigationBarItem(icon: Icon(Icons.savings), label: 'Varlıklar'),
      ],
    );
  }
}