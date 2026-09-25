// lib/core/theme/app_motion.dart

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Uygulama genelinde hareket (motion) dili: Material 3 süre ve eğrileri.
///
/// Kurallar: 200–300 ms, Material standart/emphasized eğriler, zıplama (bounce) yok.
/// Sistemde "animasyonları kaldır" açıksa tüm süreler 0'a iner.
class AppMotion {
  AppMotion._();

  /// Küçük öğeler (liste satırı girişi, sayı geçişi).
  static const Duration short = Duration(milliseconds: 220);

  /// Sekme geçişi (fade-through).
  static const Duration medium = Duration(milliseconds: 280);

  /// Tam ekran push/pop geçişi.
  static const Duration page = Duration(milliseconds: 300);

  /// Ekrana giren öğeler için (M3 emphasized decelerate).
  static const Curve enter = Easing.emphasizedDecelerate;

  /// Ekrandan çıkan öğeler için (M3 emphasized accelerate).
  static const Curve exit = Easing.emphasizedAccelerate;

  /// Yerinde değişen öğeler için (M3 standard).
  static const Curve standard = Easing.standard;

  /// Erişilebilirlik: platform "animasyonları kaldır/azalt" ayarı açık mı?
  /// BuildContext yoksa (ör. route süresi okunurken) platformdan okunur.
  static bool reduceMotion([BuildContext? context]) {
    if (context != null) {
      final fromMedia = MediaQuery.maybeDisableAnimationsOf(context);
      if (fromMedia != null) return fromMedia;
    }
    return WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  /// [duration] ya da hareket azaltılmışsa sıfır.
  static Duration resolve(Duration duration, [BuildContext? context]) =>
      reduceMotion(context) ? Duration.zero : duration;

  /// Tema düzeyinde tüm [MaterialPageRoute] geçişleri.
  ///
  /// Android: Android 14+ öngörülü geri (predictive back) hareketi korunur; düğme/programatik
  /// geçişlerde Android U "fade forwards" (yeni sayfa sağdan %25 kayarak belirir, eski sayfa
  /// sola kayarak söner — yatay shared-axis benzeri) 300 ms, emphasized eğri ile oynar.
  /// iOS/macOS: yerel Cupertino kaydırma + kenardan geri kaydırma hareketi.
  static const PageTransitionsTheme pageTransitionsTheme = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: AppPageTransitionsBuilder(
        PredictiveBackPageTransitionsBuilder(fallbackColor: AppColors.background),
        duration: page,
      ),
      TargetPlatform.fuchsia: AppPageTransitionsBuilder(
        FadeForwardsPageTransitionsBuilder(backgroundColor: AppColors.background),
        duration: page,
      ),
      TargetPlatform.windows: AppPageTransitionsBuilder(
        FadeForwardsPageTransitionsBuilder(backgroundColor: AppColors.background),
        duration: page,
      ),
      TargetPlatform.linux: AppPageTransitionsBuilder(
        FadeForwardsPageTransitionsBuilder(backgroundColor: AppColors.background),
        duration: page,
      ),
      TargetPlatform.iOS: AppPageTransitionsBuilder(CupertinoPageTransitionsBuilder()),
      TargetPlatform.macOS: AppPageTransitionsBuilder(CupertinoPageTransitionsBuilder()),
    },
  );
}

/// Bir [PageTransitionsBuilder]'ı sarar: süreyi uygulama standardına çeker ve
/// "animasyonları kaldır" ayarı açıkken geçişi anında (0 ms) yapar.
///
/// Route süresi push/pop anında okunur ([MaterialRouteTransitionMixin.didPush]),
/// bu yüzden ayar uygulama açıkken değişse de bir sonraki geçişte uygulanır.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder(this.inner, {this.duration});

  /// Asıl görsel geçişi çizen yerleşik builder.
  final PageTransitionsBuilder inner;

  /// Null ise [inner]'ın kendi süresi kullanılır (ör. iOS yerel süresi).
  final Duration? duration;

  @override
  Duration get transitionDuration =>
      AppMotion.resolve(duration ?? inner.transitionDuration);

  @override
  Duration get reverseTransitionDuration =>
      AppMotion.resolve(duration ?? inner.reverseTransitionDuration);

  @override
  DelegatedTransitionBuilder? get delegatedTransition => inner.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return inner.buildTransitions<T>(
        route, context, animation, secondaryAnimation, child);
  }
}
