// test/pdf_corpus_probe_test.dart
//
// Gerçek banka ekstreleri üzerinde uçtan uca ayrıştırma + mutabakat kontrolü.
// Kişisel PDF'ler repoya girmez; yalnızca yerelde ortam değişkeniyle çalışır:
//
//   $env:PDF_CORPUS_DIR = "D:\FinScout\Örnek PDF"
//   $env:PDF_DUMP_DIR   = "<isteğe bağlı: düzen metni ve işlem dökümünün yazılacağı klasör>"
//   flutter test test/pdf_corpus_probe_test.dart
//
// Başarı ölçütü: her belge ayrıştırılır ve banka beyanı (dönem toplamları / bakiye zinciri)
// bulunan her belgede ayrıştırılan işlemler bu beyanla kuruşu kuruşuna tutar.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/parser/enrichment/category_engine.dart';
import 'package:moneytrace/core/parser/models/parsed_models.dart';
import 'package:moneytrace/core/parser/services/pdf_extractor_service.dart';
import 'package:moneytrace/core/parser/services/statement_orchestrator.dart';
import 'package:moneytrace/core/security/pii_redactor.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;

void main() {
  final corpusDir = Platform.environment['PDF_CORPUS_DIR'];
  final dumpDir = Platform.environment['PDF_DUMP_DIR'];

  test('Gerçek ekstre korpusu uçtan uca ayrıştırılır ve bankayla mutabık kalır', () async {
    await pdfrxInitialize();
    final dictionary = File('assets/dictionaries/merchant_sectors_tr.json');
    if (dictionary.existsSync()) CategoryEngine.instance.loadDictionary(dictionary.readAsStringSync());

    final files = Directory(corpusDir!)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final orchestrator = StatementOrchestrator();
    final failures = <String>[];
    var total = 0, uncategorized = 0;

    for (final file in files) {
      final name = file.path.split(Platform.pathSeparator).last;
      final extracted = await PdfExtractorService.extract(await file.readAsBytes());
      if (dumpDir != null) {
        File('$dumpDir/$name.txt').writeAsStringSync(PiiRedactor.redact(extracted.text));
      }

      try {
        final result = await orchestrator.processDocument(layout: extracted.layout);
        final rec = result.reconciliation;
        final general = result.records.where((r) => r.categoryId == 'cat_general').length;
        total += result.records.length;
        uncategorized += general;
        final status = !rec.isVerifiable ? 'NOCHK' : (rec.isBalanced ? 'OK   ' : 'MISMATCH');
        // ignore: avoid_print
        print('$status $name | ${result.institution} ${result.documentType} | ${result.records.length} işlem '
            '| borç ${result.totalDebitCents / 100} | alacak ${result.totalCreditCents / 100} | kategorisiz $general'
            '${rec.issues.isEmpty ? '' : '\n        ${rec.issues.join('\n        ')}'}');
        if (rec.isVerifiable && !rec.isBalanced) failures.add(name);

        if (dumpDir != null) {
          final sb = StringBuffer()
            ..writeln('Özet: kesim=${result.summary.statementDate} sonÖdeme=${result.summary.dueDate} '
                'dönemBorcu=${result.summary.statementBalanceCents} asgari=${result.summary.minimumPaymentCents} '
                'planlı=${result.summary.scheduledPayments.map((p) => '${p.date}:${p.amountCents}').join(',')}');
          for (final r in result.records) {
            sb.writeln('${r.date.toIso8601String().substring(0, 10)} ${r.type == ParsedTransactionType.debit ? '-' : '+'}'
                '${r.billingAmountCents / 100}\t${r.kind.name}\t${r.categoryId}\t${r.sector ?? ''}\t'
                '${r.counterparty} | ${r.cleanMerchant}'
                '${r.installment == null ? '' : ' [taksit ${r.installment!.currentInstallment}/${r.installment!.totalInstallment}]'}'
                '${r.originalCurrency == null ? '' : ' [${r.originalAmountCents! / 100} ${r.originalCurrency}]'}');
          }
          File('$dumpDir/$name.records.txt').writeAsStringSync(sb.toString());
        }
      } catch (e) {
        failures.add(name);
        // ignore: avoid_print
        print('FAIL $name | $e');
      }
    }

    // ignore: avoid_print
    print('Toplam $total işlem, kategorisiz $uncategorized '
        '(%${(uncategorized * 100 / (total == 0 ? 1 : total)).toStringAsFixed(1)})');
    expect(failures, isEmpty, reason: 'Ayrıştırılamayan veya bankayla tutmayan ekstreler: $failures');
  }, skip: corpusDir == null ? 'PDF_CORPUS_DIR tanımlı değil' : false, timeout: const Timeout(Duration(minutes: 5)));
}
