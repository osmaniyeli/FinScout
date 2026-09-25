// DOSYA ADI: 16_WIDGET_home_widget_service.dart
// HEDEF DİZİN: lib/features/widgets/services/16_WIDGET_home_widget_service.dart

import 'package:home_widget/home_widget.dart';
import '../../persona_scout/services/08_SCOUT_persona_insight_engine.dart';

class HomeWidgetService {
  static const String androidWidgetName = 'ParaIzHomeWidget';
  static const String iOSWidgetFamily = 'ParaIzWidget';

  /// Yeni bir ekstre analiz edildiğinde veya harcama girildiğinde
  /// kilit ekranı ve ana ekran widget verilerini günceller.
  static Future<void> syncWidgetData({
    required int safeSpendBalanceCents,
    required int monthlyTotalExpenseCents,
    required String topCategoryTitle,
    required int topCategoryAmountCents,
    required ScoutFeedback scoutFeedback,
  }) async {
    final double safeSpendLira = safeSpendBalanceCents / 100;
    final double expenseLira = monthlyTotalExpenseCents / 100;
    final double topCatLira = topCategoryAmountCents / 100;

    // 1. Yerel Widget Hafızasına Değerleri Kaydet
    await HomeWidget.saveWidgetData<String>(
      'widget_safe_balance',
      '₺${safeSpendLira.toStringAsFixed(0)}',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_total_expense',
      '₺${expenseLira.toStringAsFixed(0)}',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_top_category',
      '$topCategoryTitle: ₺${topCatLira.toStringAsFixed(0)}',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_scout_badge',
      scoutFeedback.badgeText,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_scout_message',
      scoutFeedback.message,
    );

    // 2. Widget Arayüzünü Yenile
    await HomeWidget.updateWidget(
      name: androidWidgetName,
      iOSName: iOSWidgetFamily,
    );
  }
}