// lib/features/goals/models/financial_goal.dart

import 'package:flutter/material.dart';

/// Kategori adları veritabanında `category_type` olarak saklanır; sıralama/ad değişirse eski kayıtlar bozulur.
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
        return 'Araç';
      case GoalCategory.house:
        return 'Ev / Peşinat';
      case GoalCategory.motorcycle:
        return 'Motosiklet';
      case GoalCategory.boat:
        return 'Tekne';
      case GoalCategory.gift:
        return 'Hediye';
      case GoalCategory.travel:
        return 'Tatil / Seyahat';
      case GoalCategory.electronics:
        return 'Elektronik';
      case GoalCategory.other:
        return 'Diğer';
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
        return const Color(0xFF0052FF);
      case GoalCategory.house:
        return const Color(0xFFFF8A00);
      case GoalCategory.motorcycle:
        return const Color(0xFF00D084);
      case GoalCategory.boat:
        return const Color(0xFF0284C7);
      case GoalCategory.gift:
        return const Color(0xFFFF2D55);
      case GoalCategory.travel:
        return const Color(0xFF8B5CF6);
      case GoalCategory.electronics:
        return const Color(0xFF6366F1);
      case GoalCategory.other:
        return const Color(0xFF4E5D78);
    }
  }

  /// Veritabanındaki `category_type` değerinden kategori; bilinmeyen değer "Diğer" olur.
  static GoalCategory fromDb(String? value) {
    for (final c in GoalCategory.values) {
      if (c.name == value) return c;
    }
    return GoalCategory.other;
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

  /// Hedef tarihi bugünden önce mi?
  bool get isOverdue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return targetDate.isBefore(today);
  }

  /// Hedef tarihine kalan takvim ayı sayısı (tarih geçmişse 0, bu ay içindeyse 1).
  int get monthsRemaining {
    if (isOverdue) return 0;
    final now = DateTime.now();
    final months =
        (targetDate.year - now.year) * 12 + (targetDate.month - now.month);
    return months > 0 ? months : 1;
  }

  /// Hedef tarihine yetişmek için ayda gereken tutar (kuruş): kalan tutar / kalan ay.
  /// Tarih geçmişse kalan tutarın tamamı döner.
  int get recommendedMonthlySavingsCents {
    if (remainingAmountCents <= 0) return 0;
    final months = monthsRemaining;
    if (months <= 0) return remainingAmountCents;
    return (remainingAmountCents / months).round();
  }

  bool get isCompleted => currentSavedCents >= targetAmountCents;

  /// Kart ve detayda gösterilen süre etiketi
  String get timeLabel {
    if (isCompleted) return 'Tamamlandı';
    if (isOverdue) return 'Tarihi geçti';
    return '$monthsRemaining ay kaldı';
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

/// Bir hedefe yapılan tek birikim katkısı (`goal_contributions` satırı).
class GoalContribution {
  final String id;
  final String goalId;
  final int amountCents;
  final DateTime date;
  final String? note;

  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.amountCents,
    required this.date,
    this.note,
  });
}
