// lib/core/widgets/onboarding_tour/tour_step.dart

import 'package:flutter/widgets.dart';

/// Tanıtım turunun bir adımı hangi görsel stille gösterilir (bkz. karar K28).
///
/// [spotlight] (Stil A): ekranın geri kalanı koyu bir overlay ile kaplanır, hedefin etrafında
/// bir "delik" (highlight) açılır — ana sayfadaki adımlarda kullanılır.
///
/// [balloon] (Stil B): yalnız hedefin yanında küçük, hafif bir tooltip/balon (tam ekran karartma
/// yok) — diğer ekranlarda / gezinmede kullanılır.
///
/// Ekran okuyucu (TalkBack) açıkken adımın [style] alanı YOK SAYILIR: OnboardingTourController
/// bunun yerine her zaman erişilebilir bir "Bu ekranda" kartı (Stil C) gösterir; konuma dayalı
/// spotlight/balon konumlandırması ekran okuyucu kullanıcılar için anlamsız ve kafa karıştırıcıdır.
enum TourStyle { spotlight, balloon }

/// Tanıtım turunun tek bir adımı: gerçek bir widget'a (GlobalKey ile) işaret eder.
///
/// [targetKey] ağaçta yoksa (ör. sekme remote config ile gizlenmiş, hiç kurulmamış) bu adım
/// OnboardingTourController tarafından sessizce atlanır — turun kalanı bozulmaz.
class TourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final TourStyle style;

  /// Spotlight deliğinin / balon vurgu çerçevesinin hedef etrafındaki boşluğu.
  final double highlightPadding;

  const TourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.style,
    this.highlightPadding = 8,
  });
}
