// lib/features/subscriptions_bills/models/subscription_bill_item.dart

import 'package:flutter/material.dart';

enum BillCategory {
  internet,
  phone,
  streaming,
  utilities, // Doğalgaz, Elektrik, Su
  housing, // Kira, Site Aidatı
  music,
  software,
  other,
}

extension BillCategoryExt on BillCategory {
  String get displayName {
    switch (this) {
      case BillCategory.internet:
        return 'İnternet';
      case BillCategory.phone:
        return 'Telefon / GSM';
      case BillCategory.streaming:
        return 'Dizi / Film';
      case BillCategory.utilities:
        return 'Fatura (Gaz/Elk/Su)';
      case BillCategory.housing:
        return 'Kira / Aidat';
      case BillCategory.music:
        return 'Müzik';
      case BillCategory.software:
        return 'Yazılım / Bulut';
      case BillCategory.other:
        return 'Diğer Abonelik';
    }
  }

  IconData get iconData {
    switch (this) {
      case BillCategory.internet:
        return Icons.wifi_rounded;
      case BillCategory.phone:
        return Icons.phone_android_rounded;
      case BillCategory.streaming:
        return Icons.tv_rounded;
      case BillCategory.utilities:
        return Icons.receipt_long_rounded;
      case BillCategory.housing:
        return Icons.home_rounded;
      case BillCategory.music:
        return Icons.music_note_rounded;
      case BillCategory.software:
        return Icons.cloud_outlined;
      case BillCategory.other:
        return Icons.repeat_rounded;
    }
  }

  Color get color {
    switch (this) {
      case BillCategory.internet:
        return const Color(0xFF0284C7);
      case BillCategory.phone:
        return const Color(0xFFE11D48);
      case BillCategory.streaming:
        return const Color(0xFFDC2626);
      case BillCategory.utilities:
        return const Color(0xFFD97706);
      case BillCategory.housing:
        return const Color(0xFF059669);
      case BillCategory.music:
        return const Color(0xFF10B981);
      case BillCategory.software:
        return const Color(0xFF6366F1);
      case BillCategory.other:
        return const Color(0xFF64748B);
    }
  }
}

class SubscriptionBillItem {
  final String id;
  final String title;
  final String provider; // Süperonline, Vodafone, Netflix, vb.
  final BillCategory category;
  final int monthlyAmountCents;
  final int billingDayOfMonth;
  final bool isAutoPayment;
  final bool isActive;
  final String? subscriberNo;

  const SubscriptionBillItem({
    required this.id,
    required this.title,
    required this.provider,
    required this.category,
    required this.monthlyAmountCents,
    required this.billingDayOfMonth,
    this.isAutoPayment = true,
    this.isActive = true,
    this.subscriberNo,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'provider': provider,
        'category': category.name,
        'monthlyAmountCents': monthlyAmountCents,
        'billingDayOfMonth': billingDayOfMonth,
        'isAutoPayment': isAutoPayment ? 1 : 0,
        'isActive': isActive ? 1 : 0,
        'subscriberNo': subscriberNo ?? '',
      };

  factory SubscriptionBillItem.fromMap(Map<String, dynamic> map) {
    BillCategory cat = BillCategory.other;
    try {
      cat = BillCategory.values.firstWhere((c) => c.name == map['category']);
    } catch (_) {}

    return SubscriptionBillItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      provider: map['provider'] ?? '',
      category: cat,
      monthlyAmountCents: (map['monthlyAmountCents'] as num?)?.toInt() ?? 0,
      billingDayOfMonth: (map['billingDayOfMonth'] as num?)?.toInt() ?? 1,
      isAutoPayment: (map['isAutoPayment'] ?? 1) == 1,
      isActive: (map['isActive'] ?? 1) == 1,
      subscriberNo: map['subscriberNo'] as String?,
    );
  }

  SubscriptionBillItem copyWith({
    String? id,
    String? title,
    String? provider,
    BillCategory? category,
    int? monthlyAmountCents,
    int? billingDayOfMonth,
    bool? isAutoPayment,
    bool? isActive,
    String? subscriberNo,
  }) {
    return SubscriptionBillItem(
      id: id ?? this.id,
      title: title ?? this.title,
      provider: provider ?? this.provider,
      category: category ?? this.category,
      monthlyAmountCents: monthlyAmountCents ?? this.monthlyAmountCents,
      billingDayOfMonth: billingDayOfMonth ?? this.billingDayOfMonth,
      isAutoPayment: isAutoPayment ?? this.isAutoPayment,
      isActive: isActive ?? this.isActive,
      subscriberNo: subscriberNo ?? this.subscriberNo,
    );
  }
}
