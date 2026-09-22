// lib/core/services/data_export_service.dart

import 'dart:convert';
import '../security/aes_cipher.dart';
import '../utils/currency_normalizer.dart';

class DataExportService {
  static final DataExportService instance = DataExportService._internal();
  DataExportService._internal();

  /// Excel uyumlu UTF-8 BOM'lu CSV formatında harcama raporu üretir.
  /// Not: Excel'in Türkçe karakterleri (ş, ç, ğ, ı, ö, ü) doğru tanıması için \uFEFF BOM şarttır.
  String exportToCsv(List<Map<String, dynamic>> records) {
    final buffer = StringBuffer();

    // 1. UTF-8 Byte Order Mark (BOM)
    buffer.write('\uFEFF');

    // 2. Kolon Başlıkları (Noktalı virgül Excel TR standardıdır)
    buffer.writeln('Tarih;İşlem Türü;İşyeri / Açıklama;Kategori;Tutar (TL);Hesap / Kart;Taksit Durumu;Vergi Kesintisi');

    // 3. Satırlar
    for (final row in records) {
      final date = row['transaction_date'] ?? '';
      final type = row['transaction_type'] == 'DEBIT' ? 'Gider' : 'Gelir';
      final merchant = (row['clean_merchant'] ?? row['raw_description'] ?? '').toString().replaceAll(';', ',');
      final category = (row['category_name'] ?? 'Diğer').toString().replaceAll(';', ',');
      final amountCents = (row['billing_amount_cents'] as num?)?.toInt() ?? 0;
      final amountFormatted = CurrencyNormalizer.formatCents(amountCents).replaceAll('₺', '').trim();
      final account = (row['institution_name'] ?? row['card_mask'] ?? 'Nakit').toString().replaceAll(';', ',');
      
      String installmentStr = '-';
      if (row['total_installment'] != null && (row['total_installment'] as num) > 1) {
        installmentStr = '${row['current_installment']}/${row['total_installment']} Taksit';
      }

      String taxStr = '-';
      if (row['tax_amount_cents'] != null && (row['tax_amount_cents'] as num) > 0) {
        taxStr = '${row['tax_type'] ?? 'Vergi'}: ${CurrencyNormalizer.formatCents((row['tax_amount_cents'] as num).toInt())}';
      }

      buffer.writeln('$date;$type;$merchant;$category;$amountFormatted;$account;$installmentStr;$taxStr');
    }

    return buffer.toString();
  }

  /// Tüketici Hakem Heyeti ve Banka için Resmi Kart Aidatı İade Dilekçesi Taslağı
  String generateFeeRefundPetition({
    required String bankName,
    required String cardMask,
    required int feeAmountCents,
    required DateTime feeDate,
    String? customerName,
  }) {
    final feeStr = CurrencyNormalizer.formatCents(feeAmountCents);
    final dateStr = '${feeDate.day}.${feeDate.month}.${feeDate.year}';
    final applicant = customerName ?? '[Adınız Soyadınız]';

    return '''
$bankName GENEL MÜDÜRLÜĞÜ'NE / İLGİLİ ŞUBE MÜDÜRLÜĞÜ'NE
(Gereği Halinde: T.C. TİCARET BAKANLIĞI İLÇE TÜKETİCİ HAKEM HEYETİ BAŞKANLIĞI'NA)

BAŞVURU SAHİBİ : $applicant
T.C. KİMLİK NO  : [TCKN / Müşteri No]
KART BİLGİSİ    : $cardMask
KESİNTİ TARİHİ  : $dateStr
KESİNTİ TUTARI  : $feeStr
KONU            : Haksız Olarak Kesilen Kredi Kartı Yıllık Üyelik Ücretinin İadesi Talebidir.

AÇIKLAMALAR:
1. Bankanız nezdinde $cardMask numaralı kredi kartı müşterisiyim.
2. $dateStr hesap kesim döneminde, tarafımdan hiçbir ek onay ve yazılı talep alınmaksızın "$feeStr" tutarında "Kart Üyelik Ücreti / Yıllık Aidat" adı altında kesinti yapılmıştır.
3. 6502 sayılı Tüketicinin Korunması Hakkında Kanun'un 5. maddesi ve Tüketici Sözleşmelerindeki Haksız Şartlar Hakkında Yönetmelik gereğince; tüketici ile müzakere edilmeden sözleşmeye dahil edilen haksız şartlar kesin olarak hükümsüzdür.
4. Yargıtay 13. Hukuk Dairesi'nin 2011/4736 E., 2011/11579 K. sayılı ve müteaddit emsal kararlarında, kart çıkaran kuruluşların kart hamillerinden herhangi bir hizmet karşılığı olmaksızın aidat talep edemeyeceği açıkça hüküm altına alınmıştır.
5. Ayrıca 5464 sayılı Banka Kartları ve Kredi Kartları Kanunu uyarınca kart çıkaran kuruluşların aidatsız kart sunma zorunluluğu bulunmaktadır.

TALEP VE SONUÇ:
Yukarıda izah edilen kanuni gerekçeler doğrultusunda; kartımdan haksız surette tahsil edilen $feeStr aidat tutarının derhal bir sonraki ekstrede alacak olarak kaydedilmesini veya IBAN hesabıma iadesini, aksi takdirde T.C. Tüketici Hakem Heyeti ve BDDK nezdinde yasal başvurularımı yapacağımı ihtaren bildirir, gereğinin yapılmasını arz ederim.

Tarih: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}
İmza: $applicant
''';
  }

  /// Tüm SQLite Tablolarını Standart Güvenli JSON Zarfına Dönüştürür
  String createFullVaultBackupJson({
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> statements,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> installments,
    required List<Map<String, dynamic>> taxes,
  }) {
    final payload = {
      'app': 'ParaIz (MoneyTrace)',
      'version': '1.0.0',
      'vault_format': 'zero_knowledge_v1',
      'created_at': DateTime.now().toIso8601String(),
      'metrics': {
        'total_accounts': accounts.length,
        'total_statements': statements.length,
        'total_transactions': transactions.length,
        'total_installments': installments.length,
        'total_taxes': taxes.length,
      },
      'data': {
        'accounts': accounts,
        'statements': statements,
        'transactions': transactions,
        'installments': installments,
        'tax_deductions': taxes,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Parola Korumalı AES-256-CBC Şifreli Kasa Yedeği (.vault) Üretir
  String createEncryptedVaultBackup({
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> statements,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> installments,
    required List<Map<String, dynamic>> taxes,
    required String password,
  }) {
    if (password.length < 6) {
      throw ArgumentError('Yedekleme parolası en az 6 karakter olmalıdır.');
    }
    final rawJson = createFullVaultBackupJson(
      accounts: accounts,
      statements: statements,
      transactions: transactions,
      installments: installments,
      taxes: taxes,
    );
    return AesCipher.encryptVaultPayload(plainText: rawJson, password: password);
  }

  /// Yedek Dosyasını Doğrular ve Ayrıştırır (Düz Metin JSON veya AES-256 Şifreli Kasa)
  Map<String, dynamic> validateAndParseBackup(String rawContent, {String? password}) {
    String resolvedJson = rawContent.trim();

    // 1. Şifreli Kasa Formatı Kontrolü
    if (resolvedJson.startsWith('PARAIZ-SEC-VAULT-V2:')) {
      if (password == null || password.isEmpty) {
        throw const FormatException('VAULT_PASSWORD_REQUIRED: Bu yedek dosyası AES-256 ile şifrelenmiştir. Lütfen parolanızı giriniz.');
      }
      resolvedJson = AesCipher.decryptVaultPayload(vaultString: resolvedJson, password: password);
    }

    final dynamic decoded = jsonDecode(resolvedJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Geçersiz yedek dosyası: JSON formatı doğrulanamadı.');
    }

    if (decoded['app'] != 'ParaIz (MoneyTrace)' || !decoded.containsKey('data')) {
      throw const FormatException('Bu dosya geçerli bir Paraİz yedekleme arşivi değildir.');
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Yedek verisi bozuk veya eksik.');
    }

    return {
      'accounts': (data['accounts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      'statements': (data['statements'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      'transactions': (data['transactions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      'installments': (data['installments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      'tax_deductions': (data['tax_deductions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
    };
  }
}
