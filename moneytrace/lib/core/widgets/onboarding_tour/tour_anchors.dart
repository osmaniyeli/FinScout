// lib/core/widgets/onboarding_tour/tour_anchors.dart

import 'package:flutter/widgets.dart';

/// Tanıtım turunun hedef aldığı GERÇEK widget'ların paylaşılan [GlobalKey]'leri.
///
/// Dashboard (dashboard_screen.dart) ve ana gezinme iskeleti (main_navigation_scaffold.dart)
/// farklı dosyalarda olduğu için bu key'ler tek bir ortak yerden paylaşılır: her iki dosya da
/// kendi widget'ına ilgili key'i takar, OnboardingTourController ise yalnız bu key'leri okuyarak
/// TourStep listesini kurar. Böylece dosyalar arasında GlobalKey taşımak için constructor
/// parametreleri eklemeye gerek kalmaz.
class OnboardingTourAnchors {
  OnboardingTourAnchors._();

  /// Dashboard sağ üst: ekstre/bordro yükleme butonu (`upload_pdf_tooltip`).
  static final GlobalKey uploadButton =
      GlobalKey(debugLabel: 'tour_upload_button');

  /// Alt gezinme / rayın + (hızlı işlem) düğmesi — tüm sekmelerde ortak, tek FAB.
  static final GlobalKey quickAddButton =
      GlobalKey(debugLabel: 'tour_quick_add_button');

  /// Alt gezinme: Cüzdan (cashflow) sekmesi.
  static final GlobalKey walletTab = GlobalKey(debugLabel: 'tour_wallet_tab');

  /// Alt gezinme: Analiz sekmesi.
  static final GlobalKey analysisTab =
      GlobalKey(debugLabel: 'tour_analysis_tab');

  /// Alt gezinme: Varlıklar sekmesi.
  static final GlobalKey assetsTab =
      GlobalKey(debugLabel: 'tour_assets_tab');
}
