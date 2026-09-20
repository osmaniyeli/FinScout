// lib/features/subscriptions_bills/repositories/subscription_bill_repository.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/subscription_bill_item.dart';

class SubscriptionBillRepository {
  static final SubscriptionBillRepository instance = SubscriptionBillRepository._internal();
  SubscriptionBillRepository._internal();

  List<SubscriptionBillItem> _items = [];
  bool _isLoaded = false;
  final ValueNotifier<List<SubscriptionBillItem>> itemsNotifier = ValueNotifier([]);

  List<SubscriptionBillItem> get items => List.unmodifiable(_items);

  int get totalActiveMonthlyCents {
    return _items
        .where((item) => item.isActive)
        .fold<int>(0, (sum, item) => sum + item.monthlyAmountCents);
  }

  Future<File> _getFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/paraiz_subscriptions_bills.json');
  }

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = jsonDecode(content);
          _items = list.map((item) => SubscriptionBillItem.fromMap(Map<String, dynamic>.from(item))).toList();
        }
      }
    } catch (_) {
      _items = [];
    }
    _isLoaded = true;
    itemsNotifier.value = List.unmodifiable(_items);
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      final data = _items.map((e) => e.toMap()).toList();
      await file.writeAsString(jsonEncode(data));
      itemsNotifier.value = List.unmodifiable(_items);
    } catch (_) {}
  }

  Future<void> addBill(SubscriptionBillItem item) async {
    await load();
    _items.removeWhere((x) => x.id == item.id);
    _items.add(item);
    await _save();
  }

  Future<void> toggleActive(String id) async {
    await load();
    final index = _items.indexWhere((x) => x.id == id);
    if (index != -1) {
      final current = _items[index];
      _items[index] = current.copyWith(isActive: !current.isActive);
      await _save();
    }
  }

  Future<void> deleteBill(String id) async {
    await load();
    _items.removeWhere((x) => x.id == id);
    await _save();
  }

  Future<void> clearAll() async {
    _items.clear();
    await _save();
  }
}
