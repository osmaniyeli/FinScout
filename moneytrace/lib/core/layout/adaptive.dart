// lib/core/layout/adaptive.dart

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Material 3 pencere boyutu sınıfları (genişliğe göre, dp).
/// https://m3.material.io/foundations/layout/applying-layout/window-size-classes
enum WindowSizeClass {
  /// < 600: telefon dikey
  compact,

  /// 600–839: tablet dikey, katlanabilir açık, büyük telefon yatay
  medium,

  /// 840–1199: tablet yatay, masaüstü pencere
  expanded,

  /// 1200–1599
  large,

  /// ≥ 1600
  extraLarge;

  static WindowSizeClass fromWidth(double width) {
    if (width < Breakpoints.medium) return compact;
    if (width < Breakpoints.expanded) return medium;
    if (width < Breakpoints.large) return expanded;
    if (width < Breakpoints.extraLarge) return large;
    return extraLarge;
  }

  /// Pencerenin (uygulamanın tamamının) boyut sınıfı. Yalnız pencere genişliğine bağlanır;
  /// ekran bu genişlik değişince yeniden kurulur (MediaQuery.sizeOf).
  static WindowSizeClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == compact;
  bool get isAtLeastMedium => index >= medium.index;
  bool get isAtLeastExpanded => index >= expanded.index;
}

/// M3 kırılım noktaları ve uygulamanın içerik genişliği sınırları.
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double extraLarge = 1600;

  /// Okunabilir tek sütun: liste/ayar/detay ekranları (satır uzunluğu ~70 karakter).
  static const double readable = 720;

  /// Kart ızgarası veya iki sütunlu düzen kullanan özet ekranları.
  static const double wide = 1080;

  /// Alt sayfaların (bottom sheet) geniş ekrandaki en fazla genişliği (M3 önerisi 640).
  static const double sheet = 640;

  /// Bu içerik genişliğinden itibaren iki sütunlu (yan yana) bölümler açılır.
  static const double twoPane = 840;
}

/// Kullanılabilir [width] içinde en fazla [maxWidth] genişlikte, ortalanmış bir sütun için
/// [base] dolgusuna eklenecek yatay pay. Kaydırılabilir listelerde (ListView.padding) kullanılır:
/// kaydırma alanı tüm genişlikte kalır, yalnız içerik sütunu daralır.
EdgeInsets readablePadding(double width, EdgeInsets base,
    {double maxWidth = Breakpoints.readable}) {
  final contentWidth = width - base.horizontal;
  if (!width.isFinite || contentWidth <= maxWidth) return base;
  final extra = (contentWidth - maxWidth) / 2;
  return base.copyWith(left: base.left + extra, right: base.right + extra);
}

/// İçeriği yatayda ortalar ve genişliğini [maxWidth] ile sınırlar; dar ekranda hiçbir şey değiştirmez.
///
/// `SingleChildScrollView(child: AdaptiveBody(child: Column(...)))` biçiminde kullanılır:
/// kaydırma (ve RefreshIndicator) tüm genişlikte kalır, sütun ortada durur. Çocuğa sıkı (tight)
/// genişlik verilir; böylece `Column` gibi çocuklar dar ekrandakiyle aynı biçimde yayılır.
class AdaptiveBody extends StatelessWidget {
  const AdaptiveBody({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.readable,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || constraints.maxWidth <= maxWidth) {
        return child;
      }
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: maxWidth, child: child),
      );
    });
  }
}

/// [builder]'a verilen genişliğe göre ortalanmış dolgu hesaplayan kısayol (ListView için).
class AdaptiveListPadding extends StatelessWidget {
  const AdaptiveListPadding({
    super.key,
    required this.padding,
    required this.builder,
    this.maxWidth = Breakpoints.readable,
  });

  final EdgeInsets padding;
  final double maxWidth;
  final Widget Function(BuildContext context, EdgeInsets padding) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(
        context,
        readablePadding(constraints.maxWidth, padding, maxWidth: maxWidth),
      ),
    );
  }
}

/// Eşit genişlikli sütunlardan oluşan basit kart ızgarası. Sütun sayısı kullanılabilir genişlikten
/// hesaplanır: her kart en az [minItemWidth] olacak şekilde en fazla [maxColumns] sütun.
/// Kartların yüksekliği içeriklerine göredir (sabit en-boy oranı yok → büyük yazıda taşmaz).
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 320,
    this.maxColumns = 3,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  static int columnsFor(double width,
      {double minItemWidth = 320, int maxColumns = 3, double spacing = 12}) {
    if (!width.isFinite) return 1;
    final fit = ((width + spacing) / (minItemWidth + spacing)).floor();
    return math.max(1, math.min(maxColumns, fit));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = columnsFor(constraints.maxWidth,
          minItemWidth: minItemWidth, maxColumns: maxColumns, spacing: spacing);
      if (columns == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0 && runSpacing > 0) SizedBox(height: runSpacing),
              children[i],
            ],
          ],
        );
      }
      // Satır satır: aynı satırdaki kartlar üstten hizalı, genişlikleri eşit
      final rows = <Widget>[];
      for (var start = 0; start < children.length; start += columns) {
        if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing));
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) SizedBox(width: spacing),
              Expanded(
                child: start + c < children.length
                    ? children[start + c]
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    });
  }
}

/// Genişlik [breakpoint]'i geçince iki bölümü yan yana, değilse alt alta dizer.
/// Dar ekranda [start] üstte, [end] altta ve aralarında [gap] boşluk bulunur.
class AdaptiveTwoPane extends StatelessWidget {
  const AdaptiveTwoPane({
    super.key,
    required this.start,
    required this.end,
    this.breakpoint = Breakpoints.twoPane,
    this.gap = 16,
    this.verticalGap,
    this.startFlex = 1,
    this.endFlex = 1,
  });

  final Widget start;
  final Widget end;
  final double breakpoint;

  /// Yan yana düzende bölümler arası yatay boşluk.
  final double gap;

  /// Alt alta düzende boşluk; verilmezse [gap].
  final double? verticalGap;
  final int startFlex;
  final int endFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint) {
        // Dar ekranda ekranların önceki düzeniyle birebir aynı (Column + start hizası)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            start,
            if ((verticalGap ?? gap) > 0) SizedBox(height: verticalGap ?? gap),
            end,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: startFlex, child: start),
          SizedBox(width: gap),
          Expanded(flex: endFlex, child: end),
        ],
      );
    });
  }
}
