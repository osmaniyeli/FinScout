import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/parser/enrichment/category_engine.dart';
import 'package:moneytrace/core/parser/models/parsed_models.dart';

/// Açılışta sözlük artık ilk kareyi bekletmeden, ayrı isolate'te yükleniyor. Arka plan yüklemesi
/// eşzamanlı yüklemeyle birebir aynı eşleşmeleri üretmeli ve içe aktarma öncesi beklenebilmeli.
void main() {
  final json = File('assets/dictionaries/merchant_sectors_tr.json').readAsStringSync();

  ParsedRecord record(String description) => ParsedRecord(
        cardOrAccountMask: '',
        date: DateTime(2026, 9, 1),
        rawDescription: description,
        billingAmountCents: 1000,
        type: ParsedTransactionType.debit,
      );

  List<String?> resolveAll(List<String> descriptions) => [
        for (final d in descriptions)
          CategoryEngine.instance.resolve(record(d), counterparty: d).categoryId,
      ];

  // Sözlükten geçen satırlar karışımı (eşleşen, eşleşmeyen, kelime sınırı)
  final samples = [
    'A101 YENI MAGAZACILIK ISTANBUL',
    'MIGROS TICARET A.S.',
    'SHELL AKARYAKIT',
    'IBIMA GIDA',
    'BILINMEYEN ISYERI 123',
    'NETFLIX.COM',
    'TRENDYOL',
  ];

  test('arka planda (isolate) yükleme eşzamanlı yüklemeyle aynı sonucu verir', () async {
    CategoryEngine.instance.loadDictionary(json);
    expect(CategoryEngine.instance.hasDictionary, isTrue);
    final sync = resolveAll(samples);
    // Örnekler gerçekten sözlükten eşleşmeli; yoksa karşılaştırma bir şey kanıtlamaz
    expect(
        samples.where((d) =>
            CategoryEngine.instance.resolve(record(d), counterparty: d).source == CategorySource.dictionary),
        isNotEmpty);

    CategoryEngine.instance.loadDictionary('{}');
    expect(CategoryEngine.instance.hasDictionary, isFalse);

    final pending = CategoryEngine.instance.loadDictionaryInBackground(() async => json);
    await CategoryEngine.instance.ensureDictionaryLoaded();
    await pending;
    expect(CategoryEngine.instance.hasDictionary, isTrue);
    expect(resolveAll(samples), sync);
  });

  test('kaynak okunamazsa ya da veri bozuksa sözlük boş kalır, hata fırlatmaz', () async {
    await CategoryEngine.instance.loadDictionaryInBackground(() async => throw const FileSystemException('yok'));
    expect(CategoryEngine.instance.hasDictionary, isFalse);
    await CategoryEngine.instance.loadDictionaryInBackground(() async => 'bozuk json');
    expect(CategoryEngine.instance.hasDictionary, isFalse);
    await CategoryEngine.instance.ensureDictionaryLoaded();
  });
}
