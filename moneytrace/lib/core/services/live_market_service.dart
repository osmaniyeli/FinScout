// lib/core/services/live_market_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class MarketTicker {
  final String symbol; // USD, EUR, ALTIN_GR, CEYREK, BTC
  final String name; // ABD Doları, Euro, Gram Altın, Çeyrek Altın
  final double buyingPrice;
  final double sellingPrice;
  final double changeRate; // Günlük % değişim
  final DateTime lastUpdated;

  const MarketTicker({
    required this.symbol,
    required this.name,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.changeRate,
    required this.lastUpdated,
  });

  String get formattedPrice {
    if (symbol == 'BTC') {
      return '₺${sellingPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    }
    return '₺${sellingPrice.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

class LiveMarketService {
  static final LiveMarketService instance = LiveMarketService._internal();
  LiveMarketService._internal();

  // Son başarılı önbellek (Offline koruması)
  final Map<String, MarketTicker> _cachedTickers = {
    'USD': MarketTicker(
      symbol: 'USD',
      name: 'Amerikan Doları',
      buyingPrice: 34.20,
      sellingPrice: 34.28,
      changeRate: 0.15,
      lastUpdated: DateTime.now(),
    ),
    'EUR': MarketTicker(
      symbol: 'EUR',
      name: 'Euro',
      buyingPrice: 37.15,
      sellingPrice: 37.26,
      changeRate: -0.08,
      lastUpdated: DateTime.now(),
    ),
    'ALTIN_GR': MarketTicker(
      symbol: 'ALTIN_GR',
      name: 'Gram Altın (Kapalıçarşı)',
      buyingPrice: 3020.0,
      sellingPrice: 3045.50,
      changeRate: 0.42,
      lastUpdated: DateTime.now(),
    ),
    'CEYREK': MarketTicker(
      symbol: 'CEYREK',
      name: 'Çeyrek Altın',
      buyingPrice: 4950.0,
      sellingPrice: 5010.0,
      changeRate: 0.38,
      lastUpdated: DateTime.now(),
    ),
  };

  /// Canlı kur çekimi: Serbest Piyasa & TCMB açık veri uç noktası (Dart stdlib HttpClient ile sıfır bağımlılık)
  Future<Map<String, MarketTicker>> fetchLiveRates() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      final request = await client.getUrl(Uri.parse('https://finans.truncgil.com/v4/today.json'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final now = DateTime.now();

        // USD
        if (data.containsKey('USD')) {
          final usd = data['USD'];
          _cachedTickers['USD'] = MarketTicker(
            symbol: 'USD',
            name: 'Amerikan Doları',
            buyingPrice: _parseDouble(usd['Buying']),
            sellingPrice: _parseDouble(usd['Selling']),
            changeRate: _parseDouble(usd['ChangeRate']),
            lastUpdated: now,
          );
        }

        // EUR
        if (data.containsKey('EUR')) {
          final eur = data['EUR'];
          _cachedTickers['EUR'] = MarketTicker(
            symbol: 'EUR',
            name: 'Euro',
            buyingPrice: _parseDouble(eur['Buying']),
            sellingPrice: _parseDouble(eur['Selling']),
            changeRate: _parseDouble(eur['ChangeRate']),
            lastUpdated: now,
          );
        }

        // Gram Altın
        if (data.containsKey('gram-altin')) {
          final gr = data['gram-altin'];
          _cachedTickers['ALTIN_GR'] = MarketTicker(
            symbol: 'ALTIN_GR',
            name: 'Gram Altın',
            buyingPrice: _parseDouble(gr['Buying']),
            sellingPrice: _parseDouble(gr['Selling']),
            changeRate: _parseDouble(gr['ChangeRate']),
            lastUpdated: now,
          );
        }

        // Çeyrek Altın
        if (data.containsKey('ceyrek-altin')) {
          final cy = data['ceyrek-altin'];
          _cachedTickers['CEYREK'] = MarketTicker(
            symbol: 'CEYREK',
            name: 'Çeyrek Altın',
            buyingPrice: _parseDouble(cy['Buying']),
            sellingPrice: _parseDouble(cy['Selling']),
            changeRate: _parseDouble(cy['ChangeRate']),
            lastUpdated: now,
          );
        }
      }
    } catch (e) {
      debugPrint('Canlı kur çekilemedi, yerel önbellek kullanılıyor: $e');
    } finally {
      client.close();
    }

    return _cachedTickers;
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final str = val.toString().replaceAll('%', '').replaceAll(',', '.').trim();
    return double.tryParse(str) ?? 0.0;
  }
}
