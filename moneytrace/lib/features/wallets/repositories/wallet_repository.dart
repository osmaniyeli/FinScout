// lib/features/wallets/repositories/wallet_repository.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/wallet.dart';

class WalletRepository {
  static final WalletRepository instance = WalletRepository._internal();
  WalletRepository._internal();

  List<Wallet> _wallets = [];
  bool _isLoaded = false;
  String _activeWalletId = 'consolidated'; // Varsayılan olarak Ana Cüzdan (Konsolide)

  final ValueNotifier<List<Wallet>> walletsNotifier = ValueNotifier([]);
  final ValueNotifier<String> activeWalletIdNotifier = ValueNotifier('consolidated');

  List<Wallet> get wallets => List.unmodifiable(_wallets);
  String get activeWalletId => _activeWalletId;

  Wallet? get activeWallet {
    if (_activeWalletId == 'consolidated') {
      return getConsolidatedWallet();
    }
    return _wallets.firstWhere(
      (w) => w.id == _activeWalletId,
      orElse: () => getConsolidatedWallet(),
    );
  }

  /// Tüm cüzdanların net konsolide toplamını hesaplar
  Wallet getConsolidatedWallet() {
    int total = 0;
    for (final w in _wallets) {
      if (w.type == WalletType.creditCard) {
        total -= w.balanceCents.abs(); // Kredi kartı borcu net varlığı düşürür
      } else {
        total += w.balanceCents;
      }
    }
    return Wallet(
      id: 'consolidated',
      name: 'Ana Cüzdan (Konsolide)',
      type: WalletType.consolidated,
      balanceCents: total,
      colorHex: '#0052FF',
      isDefault: true,
      createdAt: DateTime.now(),
    );
  }

  Future<File> _getFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/paraiz_wallets.json');
  }

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = jsonDecode(content);
          _wallets = list.map((item) => Wallet.fromMap(Map<String, dynamic>.from(item))).toList();
        }
      }
    } catch (_) {
      _wallets = [];
    }

    if (_wallets.isEmpty) {
      // Varsayılan temiz cüzdan şablonları
      final now = DateTime.now();
      _wallets = [
        Wallet(
          id: 'wallet_checking',
          name: 'Vadesiz / Maaş Hesabı',
          type: WalletType.checking,
          balanceCents: 0,
          colorHex: '#0284C7',
          isDefault: true,
          createdAt: now,
        ),
        Wallet(
          id: 'wallet_credit_card',
          name: 'Kredi Kartı',
          type: WalletType.creditCard,
          balanceCents: 0,
          colorHex: '#DC2626',
          isDefault: false,
          createdAt: now,
        ),
        Wallet(
          id: 'wallet_cash',
          name: 'Nakit Cüzdan',
          type: WalletType.cash,
          balanceCents: 0,
          colorHex: '#10B981',
          isDefault: false,
          createdAt: now,
        ),
      ];
      await _save();
    }

    _isLoaded = true;
    walletsNotifier.value = List.unmodifiable(_wallets);
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      final data = _wallets.map((e) => e.toMap()).toList();
      await file.writeAsString(jsonEncode(data));
      walletsNotifier.value = List.unmodifiable(_wallets);
    } catch (_) {}
  }

  void setActiveWallet(String walletId) {
    _activeWalletId = walletId;
    activeWalletIdNotifier.value = walletId;
  }

  Future<void> addWallet(Wallet wallet) async {
    await load();
    _wallets.removeWhere((w) => w.id == wallet.id);
    _wallets.add(wallet);
    await _save();
  }

  Future<void> updateBalance(String walletId, int newBalanceCents) async {
    await load();
    final idx = _wallets.indexWhere((w) => w.id == walletId);
    if (idx != -1) {
      _wallets[idx] = _wallets[idx].copyWith(balanceCents: newBalanceCents);
      await _save();
    }
  }

  Future<void> deleteWallet(String walletId) async {
    await load();
    _wallets.removeWhere((w) => w.id == walletId);
    if (_activeWalletId == walletId) {
      _activeWalletId = 'consolidated';
      activeWalletIdNotifier.value = 'consolidated';
    }
    await _save();
  }

  Future<void> clearAll() async {
    _wallets.clear();
    await _save();
  }
}
