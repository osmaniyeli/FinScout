// lib/core/parser/enrichment/transaction_classifier.dart

import '../models/parsed_models.dart';
import '../util/tr_statement_text.dart';

/// Bankadan bağımsız işlem türü sınıflandırıcı.
/// Parser zaten bir tür belirlediyse ona dokunmaz; yalnızca `TransactionKind.other` kayıtları çözer.
class TransactionClassifier {
  TransactionClassifier._();

  static const _cardPayment = [
    'ODEME-INTERNET', 'ODEME - INTERNET', 'OTOMATIK TAHSILAT', 'HESAPTAN ODEME', 'KART ODEMESI',
    'KREDI KARTI ODEMESI', 'BORC ODEME', 'MOBIL ODEME', 'SUBEDEN ODEME', 'ATM ODEME', 'ODEMENIZ ICIN TESEKKUR',
  ];
  static const _interestFee = [
    'DONEM FAIZI', 'GECIKME FAIZI', 'AKDI FAIZ', 'ALISVERIS FAIZI', 'NAKIT AVANS FAIZI', 'KART UCRETI',
    'YILLIK UYELIK', 'UYELIK UCRETI', 'ISLEM UCRETI', 'HESAP ISLETIM', 'KART AIDATI', 'EKSTRE UCRETI', 'SMS UCRETI',
  ];
  static const _tax = ['BSMV', 'KKDF', 'MOTORLU TASITLAR', 'VERGI DAIRESI', 'GELIR IDARESI', 'VERGI-', 'DAMGA VERGISI'];
  static const _cash = ['NAKIT CEKIM', 'NAKIT AVANS', 'ATM NAKIT', 'PARA CEKME'];
  static const _refund = ['IADE', 'IPTAL', 'REFUND'];
  static const _salary = ['MAAS', 'UCRET ODEMESI', 'PERSONEL ODEMESI', 'SALARY'];
  static const _bill = ['FATURA', 'ABONE NO'];
  static const _transfer = ['HAVALE', 'EFT', 'FAST', 'GIDEN TRANSFER', 'GELEN TRANSFER', 'VIRMAN'];
  static const _loan = ['KREDI TAKSIT', 'IHTIYAC KREDI', 'TASIT KREDI', 'KONUT KREDI'];

  static TransactionKind classify(ParsedRecord record, {required bool isCardStatement}) {
    if (record.kind != TransactionKind.other) return record.kind;

    final text = TrStatementText.fold(record.rawDescription);
    bool has(List<String> keys) => keys.any(text.contains);
    final isCredit = record.type == ParsedTransactionType.credit;

    if (has(_tax)) return TransactionKind.tax;
    if (has(_interestFee)) return TransactionKind.interestFee;
    if (has(_cash)) return TransactionKind.cashAdvance;
    if (isCardStatement && isCredit && has(_cardPayment)) return TransactionKind.cardPayment;
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
