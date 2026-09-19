// lib/features/goals/models/financial_goal.dart

import 'package:flutter/material.dart';

enum GoalCategory {
  vehicle,
  house,
  motorcycle,
  boat,
  gift,
  travel,
  electronics,
  other,
}

enum GoalStatus {
  active,
  completed,
  paused,
}

extension GoalCategoryExtension on GoalCategory {
  String get displayName {
    switch (this) {
      case GoalCategory.vehicle:
        return 'Araç Alımı';
      case GoalCategory.house:
        return 'Ev Alma / Peşinat';
      case GoalCategory.motorcycle:
        return 'Motorsiklet';
      case GoalCategory.boat:
        return 'Tekne Alımı';
      case GoalCategory.gift:
        return 'Özel Hediye';
      case GoalCategory.travel:
        return 'Tatil & Seyahat';
      case GoalCategory.electronics:
        return 'Elektronik & Teknoloji';
      case GoalCategory.other:
        return 'Diğer Birikim';
    }
  }

  IconData get iconData {
    switch (this) {
      case GoalCategory.vehicle:
        return Icons.directions_car_rounded;
      case GoalCategory.house:
        return Icons.home_rounded;
      case GoalCategory.motorcycle:
        return Icons.two_wheeler_rounded;
      case GoalCategory.boat:
        return Icons.directions_boat_rounded;
      case GoalCategory.gift:
        return Icons.card_giftcard_rounded;
      case GoalCategory.travel:
        return Icons.flight_takeoff_rounded;
      case GoalCategory.electronics:
        return Icons.devices_other_rounded;
      case GoalCategory.other:
        return Icons.savings_rounded;
    }
  }

  Color get themeColor {
    switch (this) {
      case GoalCategory.vehicle:
        return const Color(0xFF0052FF); // Elektrik Mavisi
      case GoalCategory.house:
        return const Color(0xFFFF8A00); // Sıcak Turuncu
      case GoalCategory.motorcycle:
        return const Color(0xFF00D084); // Canlı Zümrüt Yeşil
      case GoalCategory.boat:
        return const Color(0xFF0284C7); // Deniz Mavisi
      case GoalCategory.gift:
        return const Color(0xFFFF2D55); // Canlı Kızıl Kırmızı
      case GoalCategory.travel:
        return const Color(0xFF8B5CF6); // Mor
      case GoalCategory.electronics:
        return const Color(0xFF6366F1); // İndigo
      case GoalCategory.other:
        return const Color(0xFF4E5D78); // Arduvaz
    }
  }
}

class FinancialGoal {
  final String id;
  final String title;
  final GoalCategory category;
  final int targetAmountCents;
  final int currentSavedCents;
  final String currency;
  final DateTime targetDate;
  final int? monthlyPlanCents;
  final GoalStatus status;
  final DateTime createdAt;

  // Dinamik Özelleştirilmiş Alanlar
  final String? subType; // Ev tipi (2+1 Daire, Müstakil Villa vb.)
  final String? brandModel; // Fiat Egea, Honda PCX 125 vb.
  final String? motivationalQuote; // Kişiselleştirilmiş motivasyon metni

  const FinancialGoal({
    required this.id,
    required this.title,
    required this.category,
    required this.targetAmountCents,
    required this.currentSavedCents,
    this.currency = 'TRY',
    required this.targetDate,
    this.monthlyPlanCents,
    this.status = GoalStatus.active,
    required this.createdAt,
    this.subType,
    this.brandModel,
    this.motivationalQuote,
  });

  /// Para birimi kodu
  String get currencyCode => currency;

  /// Tamamlanma yüzdesi (0.0 - 100.0)
  double get progressPercentage {
    if (targetAmountCents <= 0) return 0.0;
    final ratio = (currentSavedCents / targetAmountCents) * 100;
    return ratio > 100.0 ? 100.0 : double.parse(ratio.toStringAsFixed(1));
  }

  /// Kalan hedef tutar (kuruş)
  int get remainingAmountCents {
    final diff = targetAmountCents - currentSavedCents;
    return diff > 0 ? diff : 0;
  }

  /// Hedefe kalan ay sayısı
  int get monthsRemaining {
    final now = DateTime.now();
    int months = (targetDate.year - now.year) * 12 + (targetDate.month - now.month);
    return months > 0 ? months : 1;
  }

  /// Hedefe zamanında ulaşmak için gereken aylık tasarruf tutarı (kuruş)
  int get recommendedMonthlySavingsCents {
    if (remainingAmountCents <= 0) return 0;
    final months = monthsRemaining;
    return (remainingAmountCents / months).round();
  }

  bool get isCompleted => currentSavedCents >= targetAmountCents;

  /// Kategori ve duruma göre dinamik motivasyon metni üretir
  String get dynamicMotivation {
    if (motivationalQuote != null && motivationalQuote!.isNotEmpty) {
      return motivationalQuote!;
    }
    switch (category) {
      case GoalCategory.house:
        return 'Kendi kapını anahtarınla açtığın o ilk günün huzuru paha biçilemez. Her ay biriktirdiğin her kuruş, o evin temeline konan sağlam bir tuğla! 🏠';
      case GoalCategory.vehicle:
        return brandModel != null
            ? '$brandModel direksiyonuna geçip kontak anahtarını çevirdiğin ilk anı hayal et. Hedefe adım adım yaklaşıyorsun! 🚗'
            : 'Yeni araç kokusu ve ilk yolculuğun heyecanı... Gaza basmaya devam! 🚗';
      case GoalCategory.motorcycle:
        return brandModel != null
            ? '$brandModel ile rüzgarı hissedeceğin ilk rota çok yakın! Birikim depon hızla doluyor. 🏍️'
            : 'Trafiğe takılmadan, rüzgarı yüzünde hissettiğin o ilk rotayı hayal et! Birikim depon hızla doluyor. 🏍️';
      case GoalCategory.boat:
        return 'Mavi sularda kendi rotanı çizeceğin, gün batımını denizden izleyeceğin günler çok yakın! ⛵';
      case GoalCategory.gift:
        return 'Sevdiklerinin yüzündeki o samimi tebessüm, bu birikimin en büyük getirisi olacak. 🎁';
      case GoalCategory.travel:
        return 'Yeni kültürler, unutulmaz anılar ve pasaportuna vurulacak o yeni mühür seni bekliyor! ✈️';
      case GoalCategory.electronics:
        return 'Hayatını kolaylaştıracak o yeni teknolojiye kavuşmana çok az kaldı! 💻';
      case GoalCategory.other:
        return 'Bugün biriktirdiğin her kuruş, yarının finansal özgürlüğünün güvencesidir! 💎';
    }
  }

  FinancialGoal copyWith({
    String? id,
    String? title,
    GoalCategory? category,
    int? targetAmountCents,
    int? currentSavedCents,
    String? currency,
    DateTime? targetDate,
    int? monthlyPlanCents,
    GoalStatus? status,
    DateTime? createdAt,
    String? subType,
    String? brandModel,
    String? motivationalQuote,
  }) {
    return FinancialGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      targetAmountCents: targetAmountCents ?? this.targetAmountCents,
      currentSavedCents: currentSavedCents ?? this.currentSavedCents,
      currency: currency ?? this.currency,
      targetDate: targetDate ?? this.targetDate,
      monthlyPlanCents: monthlyPlanCents ?? this.monthlyPlanCents,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      subType: subType ?? this.subType,
      brandModel: brandModel ?? this.brandModel,
      motivationalQuote: motivationalQuote ?? this.motivationalQuote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category_type': category.name,
      'target_amount_cents': targetAmountCents,
      'current_saved_cents': currentSavedCents,
      'currency_code': currency,
      'target_date': targetDate.toIso8601String().split('T')[0],
      'monthly_plan_cents': monthlyPlanCents,
      'status': status.name.toUpperCase(),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
