// lib/features/wallets/models/wallet.dart

import 'package:flutter/material.dart';

enum WalletType {
  checking, // Vadesiz / Maaş
  creditCard, // Kredi Kartı
  cash, // Nakit Cüzdan
  savings, // Birikim / Altın / Döviz
  consolidated, // Ana Cüzdan (Tümünün Özeti)
}

extension WalletTypeExt on WalletType {
  String get displayName {
    switch (this) {
      case WalletType.checking:
        return 'Vadesiz / Banka Hesabı';
      case WalletType.creditCard:
        return 'Kredi Kartı';
      case WalletType.cash:
        return 'Nakit Cüzdan';
      case WalletType.savings:
        return 'Birikim / Yatırım';
      case WalletType.consolidated:
        return 'Ana Cüzdan (Konsolide)';
    }
  }

  IconData get iconData {
    switch (this) {
      case WalletType.checking:
        return Icons.account_balance_rounded;
      case WalletType.creditCard:
        return Icons.credit_card_rounded;
      case WalletType.cash:
        return Icons.account_balance_wallet_rounded;
      case WalletType.savings:
        return Icons.savings_rounded;
      case WalletType.consolidated:
        return Icons.pie_chart_rounded;
    }
  }
}

class Wallet {
  final String id;
  final String name;
  final WalletType type;
  final int balanceCents;
  final String currency;
  final String colorHex;
  final bool isDefault;
  final DateTime createdAt;

  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    this.balanceCents = 0,
    this.currency = 'TRY',
    this.colorHex = '#0052FF',
    this.isDefault = false,
    required this.createdAt,
  });

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF0052FF);
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'balanceCents': balanceCents,
    'currency': currency,
    'colorHex': colorHex,
    'isDefault': isDefault ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Wallet.fromMap(Map<String, dynamic> map) {
    WalletType t = WalletType.checking;
    try {
      t = WalletType.values.firstWhere((x) => x.name == map['type']);
    } catch (_) {}

    return Wallet(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: t,
      balanceCents: (map['balanceCents'] as num?)?.toInt() ?? 0,
      currency: map['currency'] ?? 'TRY',
      colorHex: map['colorHex'] ?? '#0052FF',
      isDefault: (map['isDefault'] ?? 0) == 1,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }

  Wallet copyWith({
    String? id,
    String? name,
    WalletType? type,
    int? balanceCents,
    String? currency,
    String? colorHex,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balanceCents: balanceCents ?? this.balanceCents,
      currency: currency ?? this.currency,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
