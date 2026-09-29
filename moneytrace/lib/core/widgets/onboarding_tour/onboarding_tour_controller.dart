// lib/core/widgets/onboarding_tour/onboarding_tour_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/user_profile_service.dart';
import 'accessible_tour_card.dart';
import 'balloon_tour_overlay.dart';
import 'spotlight_tour_overlay.dart';
import 'tour_step.dart';

/// Yeni hesap kaydından hemen sonra, kullanıcı ana ekranı (Dashboard) ilk gördüğünde TEK SEFERLİK
/// gösterilen tanıtım turunu yönetir.
///
/// Tetikleme: main.dart'ın `_announceNewAccount()`'ı ile AYNI sinyali kullanır
/// (`AccountService.instance.lastSignInCreatedAccount`) — main.dart yalnız [scheduleForNewAccount]
/// çağırır, gerçek tetikleme MainNavigationScaffold ilk kareyi çizdikten sonra [maybeStart] ile
/// olur (böylece Dashboard'daki hedef widget'lar ağaçta hazır olur).
///
/// Stil seçimi otomatik: `MediaQuery.of(context).accessibleNavigation` true ise (TalkBack/ekran
/// okuyucu açık) HER ZAMAN Stil C (AccessibleTourCard); değilse her adımın kendi [TourStep.style]
/// alanına göre Stil A (spotlight) ya da Stil B (balon) gösterilir.
class OnboardingTourController {
  OnboardingTourController._();
  static final OnboardingTourController instance = OnboardingTourController._();

  bool _pendingForNewAccount = false;
  bool _activeThisSession = false;
  OverlayEntry? _entry;

  /// main.dart _announceNewAccount tarafından çağrılır (aynı "yeni hesap" sinyaliyle, tek satır).
  void scheduleForNewAccount() => _pendingForNewAccount = true;

  /// Yalnız testler için: bekleyen/aktif durumu sıfırlar.
  @visibleForTesting
  void resetForTesting() {
    _pendingForNewAccount = false;
    _activeThisSession = false;
    _entry?.remove();
    _entry = null;
  }

  /// MainNavigationScaffold ilk kare çizildikten sonra (post-frame) çağırır. [steps] boşsa,
  /// bekleyen bir tetikleme yoksa, tur bu oturumda zaten başladıysa ya da kullanıcı turu daha
  /// önce (önceki bir oturumda) gördüyse sessizce vazgeçer.
  void maybeStart(BuildContext context, List<TourStep> steps) {
    if (!_pendingForNewAccount || _activeThisSession) return;
    _pendingForNewAccount = false;
    if (steps.isEmpty) return;
    if (UserProfileService.instance.profile?.hasSeenOnboardingTour == true) {
      return;
    }
    _activeThisSession = true;
    // Kalıcı bayrak hemen işaretlenir: uygulama tur ortasında kapanıp yeniden açılsa bile tur
    // ikinci kez tetiklenmez (bkz. görev notu — kalıcı bayrak yalnız çifte gösterime karşı).
    unawaited(UserProfileService.instance.markOnboardingTourSeen());

    final accessible = MediaQuery.of(context).accessibleNavigation;
    if (accessible) {
      _showAccessible(context, steps);
      return;
    }
    _showOverlayStep(context, steps, 0);
  }

  void _showAccessible(BuildContext context, List<TourStep> steps) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => AccessibleTourCard(steps: steps),
        fullscreenDialog: true,
      ),
    );
  }

  void _showOverlayStep(BuildContext context, List<TourStep> steps, int index) {
    _entry?.remove();
    _entry = null;
    if (index >= steps.length) return;

    final step = steps[index];
    // Hedef ağaçta yoksa (ör. sekme remote config ile gizlenmiş) bu adımı atla, sonrakine geç.
    if (step.targetKey.currentContext == null) {
      _showOverlayStep(context, steps, index + 1);
      return;
    }

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => step.style == TourStyle.spotlight
          ? SpotlightTourOverlay(
              step: step,
              stepNumber: index + 1,
              totalSteps: steps.length,
              onNext: () => _showOverlayStep(context, steps, index + 1),
              onSkip: _dismiss,
            )
          : BalloonTourOverlay(
              step: step,
              stepNumber: index + 1,
              totalSteps: steps.length,
              onNext: () => _showOverlayStep(context, steps, index + 1),
              onSkip: _dismiss,
            ),
    );
    _entry = entry;
    overlayState.insert(entry);
  }

  void _dismiss() {
    _entry?.remove();
    _entry = null;
  }
}
