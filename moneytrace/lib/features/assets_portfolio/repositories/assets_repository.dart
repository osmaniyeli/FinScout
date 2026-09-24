// lib/features/assets_portfolio/repositories/assets_repository.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Kullanıcının elle girdiği varlık bilgileri (altın/döviz/nakit miktarları, araçlar, manuel kartlar).
/// Cihazda JSON olarak kalıcı tutulur; uygulama kapanınca kaybolmaz.
class AssetsRepository {
  static final AssetsRepository instance = AssetsRepository._internal();
  AssetsRepository._internal();

  Map<String, dynamic> _data = {};
  bool _loaded = false;

  /// Varlık verisi her değiştiğinde (kayıt, silme, sıfırlama) artar; Varlıklar ekranı dinleyip yeniden yükler.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/paraiz_assets.json');
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _file();
      if (await file.exists()) {
        _data = Map<String, dynamic>.from(
            jsonDecode(await file.readAsString()) as Map);
      }
    } catch (e) {
      debugPrint('Varlık verisi okunamadı: $e');
      _data = {};
    }
  }

  /// Dosyaya yazar; yazılamazsa hatayı fırlatır (ekran kullanıcıya gösterir, sahte "kaydedildi" yok).
  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(_data));
    } catch (e) {
      debugPrint('Varlık verisi kaydedilemedi: $e');
      rethrow;
    } finally {
      revision.value++;
    }
  }

  // --- Birikim (altın, döviz, nakit): {miktar, alış maliyeti, hedef fiyat} ---
  Map<String, double> holding(String key) {
    final raw = (_data['holdings'] as Map?)?[key] as Map?;
    return {
      'quantity': (raw?['quantity'] as num?)?.toDouble() ?? 0,
      'cost': (raw?['cost'] as num?)?.toDouble() ?? 0,
      'target': (raw?['target'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<void> setHolding(String key,
      {required double quantity, double cost = 0, double target = 0}) async {
    final holdings =
        Map<String, dynamic>.from((_data['holdings'] as Map?) ?? {});
    holdings[key] = {'quantity': quantity, 'cost': cost, 'target': target};
    _data['holdings'] = holdings;
    await _save();
  }

  String get housingType =>
      (_data['housing_type'] as String?) ?? 'Kiracı (Standart Daire)';
  Future<void> setHousingType(String value) async {
    _data['housing_type'] = value;
    await _save();
  }

  // --- Araçlar ---
  List<Map<String, dynamic>> get vehicles =>
      ((_data['vehicles'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> upsertVehicle(Map<String, dynamic> vehicle) async {
    final list = vehicles..removeWhere((v) => v['id'] == vehicle['id']);
    list.add(vehicle);
    _data['vehicles'] = list;
    await _save();
  }

  Future<void> deleteVehicle(String id) async {
    _data['vehicles'] = vehicles..removeWhere((v) => v['id'] == id);
    await _save();
  }

  // --- Manuel kartlar: yalnızca banka adı + limit; ekstre gelince bankaya göre eşleşir ---
  List<Map<String, dynamic>> get manualCards =>
      ((_data['manual_cards'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> upsertManualCard(Map<String, dynamic> card) async {
    final list = manualCards..removeWhere((c) => c['id'] == card['id']);
    list.add(card);
    _data['manual_cards'] = list;
    await _save();
  }

  Future<void> deleteManualCard(String id) async {
    _data['manual_cards'] = manualCards..removeWhere((c) => c['id'] == id);
    await _save();
  }

  Future<void> clearAll() async {
    _data = {};
    try {
      await _save();
    } catch (_) {
      // Sıfırlamanın geri kalanı (diğer dosyalar, bildirimler) yarıda kalmasın.
    }
  }
}
