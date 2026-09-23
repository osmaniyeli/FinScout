// lib/core/parser/enrichment/counterparty_extractor.dart

import '../models/parsed_models.dart';
import '../services/merchant_sanitizer.dart';
import '../util/tr_statement_text.dart';

/// İşlem açıklamasından "kime ödendi / kimden geldi" bilgisini çıkarır.
///
/// Kart ekstrelerinde açıklama sabit genişlikli "İŞYERİ ADI · ŞEHİR · ÜLKE" alanlarından oluşur;
/// şehir bazen işyeri adına yapışık gelir ("MR DIY PARKOVA AVM ÇAYIROKOCAELİ").
class CounterpartyExtractor {
  CounterpartyExtractor._();

  static const _provinces = [
    'ADANA', 'ADIYAMAN', 'AFYONKARAHISAR', 'AGRI', 'AKSARAY', 'AMASYA', 'ANKARA', 'ANTALYA', 'ARDAHAN', 'ARTVIN',
    'AYDIN', 'BALIKESIR', 'BARTIN', 'BATMAN', 'BAYBURT', 'BILECIK', 'BINGOL', 'BITLIS', 'BOLU', 'BURDUR', 'BURSA',
    'CANAKKALE', 'CANKIRI', 'CORUM', 'DENIZLI', 'DIYARBAKIR', 'DUZCE', 'EDIRNE', 'ELAZIG', 'ERZINCAN', 'ERZURUM',
    'ESKISEHIR', 'GAZIANTEP', 'GIRESUN', 'GUMUSHANE', 'HAKKARI', 'HATAY', 'IGDIR', 'ISPARTA', 'ISTANBUL', 'IZMIR',
    'KAHRAMANMARAS', 'KARABUK', 'KARAMAN', 'KARS', 'KASTAMONU', 'KAYSERI', 'KILIS', 'KIRIKKALE', 'KIRKLARELI',
    'KIRSEHIR', 'KOCAELI', 'KONYA', 'KUTAHYA', 'MALATYA', 'MANISA', 'MARDIN', 'MERSIN', 'MUGLA', 'MUS', 'NEVSEHIR',
    'NIGDE', 'ORDU', 'OSMANIYE', 'RIZE', 'SAKARYA', 'SAMSUN', 'SANLIURFA', 'SIIRT', 'SINOP', 'SIRNAK', 'SIVAS',
    'TEKIRDAG', 'TOKAT', 'TRABZON', 'TUNCELI', 'USAK', 'VAN', 'YALOVA', 'YOZGAT', 'ZONGULDAK',
    // Ekstrelerde sık görülen ilçe / kısaltmalar
    'GEBZE', 'IZMIT', 'CAYIROVA', 'KADIKOY', 'BESIKTAS', 'SISLI', 'USKUDAR', 'KARTAL', 'PENDIK', 'MALTEPE',
    'ATASEHIR', 'BAKIRKOY', 'BEYLIKDUZU', 'ESENYURT', 'LONDON', 'DUBLIN', 'AMSTERDAM', 'LUXEMBOURG',
  ];

  static final RegExp _gatewayOnly = RegExp(
    r'^(IYZICO|İYZİCO|PAYTR|SIPAY|SİPAY|ODEAL|ÖDEAL|PARAM|MOKA|PARATIKA|PAYPAL|GOOGLE|APPLE\.COM/BILL)[\s.*/-]*$',
    caseSensitive: false,
  );

  static final RegExp _countryTail = RegExp(r'\s+([A-Z]{2}|[A-Z]{2}[A-Z]{2}|[A-Z]{2}US)$');

  static String extract(ParsedRecord record) {
    if (record.counterparty.isNotEmpty) {
      // Parser karşı tarafı verdiyse yalnızca POS kayıtlarındaki "İŞYERİ ŞEHİR TR" eklerini temizle
      final isPos = record.kind == TransactionKind.purchase || record.kind == TransactionKind.refund;
      return _tidy(isPos ? MerchantSanitizer.sanitize(_stripLocation(record.counterparty)) : record.counterparty);
    }

    // Sütun sınırları çift boşlukla korunur: ilk segment işyeri adıdır
    final segments = record.rawDescription.split(RegExp(r'\s{2,}')).where((s) => s.trim().isNotEmpty).toList();
    // "PAYTR.  *ANKAOUTDOOR" → aracı öneki ayrı hücreye düştüyse asıl işyeriyle birleştir
    if (segments.length > 1 && _gatewayOnly.hasMatch(segments.first.trim())) {
      segments.replaceRange(0, 2, ['${segments[0]} ${segments[1]}']);
    }
    var name = segments.isEmpty ? record.rawDescription : segments.first;
    if (segments.length == 1) {
      // Tek segment: sondaki ülke kodu ve şehir adını ayıkla
      name = name.replaceAll(_countryTail, '');
      name = _stripTrailingCity(name);
    } else {
      name = _stripTrailingCity(name);
    }
    return _tidy(MerchantSanitizer.sanitize(name));
  }

  /// Sondaki ülke kodlarını ve il/ilçe adlarını (birden fazla olabilir) ayıklar.
  static String _stripLocation(String name) {
    var current = name.trim();
    while (true) {
      final withoutCountry = current.replaceAll(_countryTail, '');
      final tokens = withoutCountry.split(' ');
      final last = TrStatementText.fold(tokens.last);
      final next = tokens.length > 1 && _provinces.contains(last)
          ? tokens.sublist(0, tokens.length - 1).join(' ')
          : withoutCountry;
      if (next == current) return current;
      current = next.trim();
    }
  }

  static String _stripTrailingCity(String name) {
    final folded = TrStatementText.fold(name);
    for (final city in _provinces) {
      if (folded.length > city.length + 3 && folded.endsWith(city)) {
        return name.substring(0, name.length - city.length).trim();
      }
    }
    return name;
  }

  static String _tidy(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s\-*/.,]+|[\s\-*/.,]+$'), '')
      .trim();
}
