// lib/core/parser/enrichment/transaction_classifier.dart

import '../models/parsed_models.dart';
import '../util/tr_statement_text.dart';

/// Bankadan bağımsız işlem türü sınıflandırıcı.
/// Parser zaten bir tür belirlediyse ona dokunmaz; yalnızca `TransactionKind.other` kayıtları çözer.
///
/// Anahtarlar kelime başından eşleşir: "FAST" "BREAKFAST" içinde yakalanmaz ama Türkçe ekler
/// ("HAVALESI", "FAIZI") yakalanır.
class TransactionClassifier {
  TransactionClassifier._();

  static const _cardPayment = [
    'ODEME-INTERNET', 'ODEME - INTERNET', 'OTOMATIK TAHSILAT', 'HESAPTAN ODEME', 'KART ODEMESI',
    'KREDI KARTI ODEMESI', 'BORC ODEME', 'MOBIL ODEME', 'SUBEDEN ODEME', 'ATM ODEME', 'ODEMENIZ ICIN TESEKKUR',
  ];
  // Vadesiz hesaptan kart borcuna giden ödeme (borç satırı). Harcama zaten kart ekstresinde sayıldı.
  static const _cardPaymentFromChecking = [
    'KREDI KARTI ODEME', 'KREDI KARTI BORC', 'KART BORCU ODEME', 'KART BORC ODEME', 'KK ODEME', 'KK BORC',
  ];
  // Faiz ve banka ücretleri. Transferden ÖNCE kontrol edilir: "EFT ÜCRETİ" masraftır, transfer değil.
  static const _interestFee = [
    'DONEM FAIZI', 'GECIKME FAIZI', 'AKDI FAIZ', 'ALISVERIS FAIZI', 'NAKIT AVANS FAIZI', 'KMH FAIZI',
    'KREDILI MEVDUAT', 'KART UCRETI', 'YILLIK UYELIK', 'UYELIK UCRETI', 'YILLIK UCRET', 'KART AIDATI',
    'ISLEM UCRETI', 'HESAP ISLETIM', 'EKSTRE UCRETI', 'GECMIS EKSTRE', 'SMS UCRETI', 'NAKIT AVANS UCRETI',
    'NAKIT CEKIM UCRETI', 'FATURA ODEME UCRETI', 'EFT UCRETI', 'EFT MASRAFI', 'FAST UCRETI', 'FAST MASRAFI',
    'HAVALE UCRETI', 'HAVALE MASRAFI', 'SWIFT UCRETI', 'SWIFT MASRAFI', 'MASRAF', 'KOMISYON',
  ];
  static const _tax = [
    'BSMV', 'KKDF', 'MOTORLU TASITLAR', 'VERGI DAIRESI', 'GELIR IDARESI', 'VERGI-', 'DAMGA VERGISI',
    'STOPAJ', 'GV KESINTISI',
  ];
  static const _cash = ['NAKIT CEKIM', 'NAKIT AVANS', 'ATM NAKIT', 'PARA CEKME'];
  static const _refund = ['IADE', 'IPTAL', 'REFUND'];
  static const _salary = ['MAAS', 'UCRET ODEMESI', 'PERSONEL ODEMESI', 'SALARY'];
  static const _bill = ['FATURA', 'ABONE NO'];
  static const _transfer = ['HAVALE', 'EFT', 'FAST', 'GIDEN TRANSFER', 'GELEN TRANSFER', 'VIRMAN'];
  static const _loan = ['KREDI TAKSIT', 'IHTIYAC KREDI', 'TASIT KREDI', 'KONUT KREDI'];

  static final Map<String, RegExp> _patterns = {};

  /// Anahtar kelime başında mı? (önünde harf/rakam yok)
  static bool _hasKey(String text, String key) =>
      _patterns.putIfAbsent(key, () => RegExp('(?<![A-Z0-9])${RegExp.escape(key)}')).hasMatch(text);

  static TransactionKind classify(ParsedRecord record, {required bool isCardStatement}) {
    if (record.kind != TransactionKind.other) return record.kind;

    final text = TrStatementText.fold(record.rawDescription);
    bool has(List<String> keys) => keys.any((k) => _hasKey(text, k));
    final isCredit = record.type == ParsedTransactionType.credit;

    if (has(_tax)) return TransactionKind.tax;
    if (has(_interestFee)) return TransactionKind.interestFee;
    if (has(_cash)) return TransactionKind.cashAdvance;
    if (isCardStatement && isCredit && has(_cardPayment)) return TransactionKind.cardPayment;
    if (!isCardStatement && !isCredit && has(_cardPaymentFromChecking)) return TransactionKind.cardPayment;
    if (isCredit && has(_refund)) return TransactionKind.refund;
    if (isCredit && has(_salary)) return TransactionKind.salary;
    if (has(_loan)) return TransactionKind.loanPayment;
    if (has(_bill)) return TransactionKind.billPayment;
    if (has(_transfer)) return isCredit ? TransactionKind.transferIn : TransactionKind.transferOut;

    if (isCardStatement) {
      // Kart ekstresinde "+" tutar: ödeme kalıbı yoksa iade/iptal kabul edilir
      return isCredit ? TransactionKind.refund : TransactionKind.purchase;
    }
    return isCredit ? TransactionKind.transferIn : TransactionKind.purchase;
  }
}
