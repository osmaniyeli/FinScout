// lib/core/services/home_widget_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../database/repositories/transaction_repository.dart';
import '../localization/app_strings.dart';
import '../utils/currency_normalizer.dart';
import 'data_changes.dart';
import 'user_profile_service.dart';

/// Ana ekran widget'ları (Aylık Değişim / Aylık Harcama / Aylık Maaş) için Flutter ↔ native
/// köprüsü. `home_widget` paketi üzerinden SharedPreferences'a JSON yazar ve ilgili
/// AppWidgetProvider'ı (bkz. android/app/.../kotlin/com/moneytrace/app/widget/) günceller.
///
/// Polling YOK: [DataChanges.revision] (her veri değişikliğinde artan sayaç) ve
/// [UserProfileService.profileNotifier] (gizle/göster tercihi değiştiğinde) dinlenir; her
/// sinyalde kısa bir debounce ile [refreshNow] çağrılır.
class HomeWidgetService {
  HomeWidgetService._internal({
    Duration? debounce,
    TransactionRepository? repository,
  })  : _debounceDuration = debounce ?? const Duration(seconds: 2),
        _repository = repository ?? TransactionRepository();

  static final HomeWidgetService instance = HomeWidgetService._internal();

  /// Yalnız testler için: gerçek singleton'a dokunmadan kısa debounce ve/veya sahte repository ile.
  @visibleForTesting
  factory HomeWidgetService.forTesting({
    Duration debounce = const Duration(milliseconds: 10),
    TransactionRepository? repository,
  }) =>
      HomeWidgetService._internal(debounce: debounce, repository: repository);

  // Android tarafındaki tam sınıf adları (AndroidManifest.xml'deki <receiver> girişleriyle
  // birebir eşleşmeli, bkz. android/app/src/main/kotlin/com/moneytrace/app/widget/).
  static const String _pkg = 'com.moneytrace.app.widget';
  static const String _changeProvider = '$_pkg.MonthlyChangeWidgetProvider';
  static const String _expenseProvider = '$_pkg.MonthlyExpenseWidgetProvider';
  static const String _salaryProvider = '$_pkg.MonthlySalaryWidgetProvider';

  /// Widget'larda gösterilen ay sayısı (bkz. görev tanımı: 12 ay).
  static const int _months = 12;

  final Duration _debounceDuration;
  final TransactionRepository _repository;

  Timer? _debounceTimer;
  bool _listenerAttached = false;

  /// DataChanges ve profil dinleyicisini kurar, açılışta bir kez widget verisini hesaplar.
  /// Birden çok kez çağrılırsa dinleyiciler yalnız bir kez eklenir.
  Future<void> initialize() async {
    if (_listenerAttached) return;
    _listenerAttached = true;
    DataChanges.revision.addListener(_onSignal);
    UserProfileService.instance.profileNotifier.addListener(_onSignal);
    unawaited(refreshNow());
  }

  /// Yalnız testler için: dinleyicileri kaldırır, bekleyen zamanlayıcıyı iptal eder.
  @visibleForTesting
  void dispose() {
    if (_listenerAttached) {
      DataChanges.revision.removeListener(_onSignal);
      UserProfileService.instance.profileNotifier.removeListener(_onSignal);
      _listenerAttached = false;
    }
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void _onSignal() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(refreshNow());
    });
  }

  /// Üç widget'ın da verisini yeniden hesaplar, kaydeder ve native tarafı günceller.
  /// Widget hiç eklenmemişse `HomeWidget.updateWidget` sessizce etkisiz kalır (hedef id listesi
  /// boş döner); herhangi bir hata (DB kilitli, platform kanalı yok vb.) uygulamayı etkilemez.
  Future<void> refreshNow() async {
    try {
      final hideAmounts =
          UserProfileService.instance.profile?.hideWidgetAmounts ?? false;

      final changeRows =
          await _repository.getMonthlyNetChangeTrends(months: _months);
      final expenseRows =
          await _repository.getMonthlyTrendsAnalysis(months: _months);
      final salaryRows =
          await _repository.getMonthlySalaryTrends(months: _months);

      await _saveAndUpdate(
        prefsId: 'widget_monthly_change',
        providerName: _changeProvider,
        title: AppStrings.get('widget_title_monthly_change'),
        rows: changeRows,
        hideAmounts: hideAmounts,
        showSign: true,
      );
      await _saveAndUpdate(
        prefsId: 'widget_monthly_expense',
        providerName: _expenseProvider,
        title: AppStrings.get('widget_title_monthly_expense'),
        rows: expenseRows,
        hideAmounts: hideAmounts,
        showSign: false,
      );
      await _saveAndUpdate(
        prefsId: 'widget_monthly_salary',
        providerName: _salaryProvider,
        title: AppStrings.get('widget_title_monthly_salary'),
        rows: salaryRows,
        hideAmounts: hideAmounts,
        showSign: false,
      );
    } catch (e) {
      debugPrint('HomeWidgetService.refreshNow başarısız: $e');
    }
  }

  Future<void> _saveAndUpdate({
    required String prefsId,
    required String providerName,
    required String title,
    required List<Map<String, dynamic>> rows,
    required bool hideAmounts,
    required bool showSign,
  }) async {
    final payload = _buildPayload(
      title: title,
      rows: rows,
      hideAmounts: hideAmounts,
      showSign: showSign,
    );
    await HomeWidget.saveWidgetData<String>(prefsId, jsonEncode(payload));
    await HomeWidget.updateWidget(qualifiedAndroidName: providerName);
  }

  /// Native tarafa HAZIR string olarak geçilecek yük. Para biçimi tamamen burada (Flutter,
  /// [CurrencyNormalizer] ile) üretilir — native tarafta ayrıca bir biçimlendirme mantığı YOK,
  /// yalnız bu alanları RemoteViews'a yazar.
  Map<String, dynamic> _buildPayload({
    required String title,
    required List<Map<String, dynamic>> rows,
    required bool hideAmounts,
    required bool showSign,
  }) {
    if (rows.isEmpty) {
      return {
        'title': title,
        'hasData': false,
        'noDataText': AppStrings.get('widget_no_data'),
      };
    }

    // Repository satırları eskiden yeniye sıralı döner (bkz. TransactionRepository._mapMonthlyRows).
    final months = rows.map((r) => r['month'] as String).toList();
    final cents = rows.map((r) => (r['cents'] as num).toInt()).toList();
    final ratios = rows.map((r) => (r['ratio'] as num).toDouble()).toList();

    final current = cents.last;
    final currentLabel = hideAmounts
        ? AppStrings.get('widget_amount_hidden')
        : CurrencyNormalizer.formatCents(current, showSign: showSign);

    // Önceki aya göre yüzde değişim: yalnız tutar gösterilirken hesaplanır (gizliyken anlamsız,
    // şekil zaten korunuyor ama yüzde metni ek bilgi sızdırmasın diye gösterilmez).
    String? deltaLabel;
    if (!hideAmounts && cents.length >= 2) {
      final prev = cents[cents.length - 2];
      if (prev != 0) {
        final pct = ((current - prev) / prev.abs()) * 100;
        final sign = pct >= 0 ? '+' : '';
        deltaLabel =
            '$sign${pct.round()}% ${AppStrings.get('widget_vs_last_month')}';
      }
    }

    return {
      'title': title,
      'hasData': true,
      'months': months,
      'cents': cents,
      'ratios': ratios,
      'currentLabel': currentLabel,
      'currentMonth': months.last,
      'deltaLabel': deltaLabel,
      'hideAmounts': hideAmounts,
    };
  }
}
