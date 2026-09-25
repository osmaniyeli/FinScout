// DOSYA ADI: 17_UI_statement_upload_sheet.dart
// HEDEF DİZİN: lib/features/statement_parser/presentation/17_UI_statement_upload_sheet.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../services/04_PARSER_bank_detector.dart';
import '../services/statement_orchestrator.dart';
import '../parsers/15_PARSER_generic_payslip.dart';
import '../data/12_REPO_transaction_repository.dart';
import '../../subscription_manager/services/11_SUBSCRIPTION_quota_enforcer.dart';

class StatementUploadSheet extends StatefulWidget {
  final TransactionRepository repository;
  final bool isProUser;
  final int currentMonthUploads;
  final VoidCallback onUploadSuccess;

  const StatementUploadSheet({
    Key? key,
    required this.repository,
    required this.isProUser,
    required this.currentMonthUploads,
    required this.onUploadSuccess,
  }) : super(key: key);

  @override
  State<StatementUploadSheet> createState() => _StatementUploadSheetState();
}

class _StatementUploadSheetState extends State<StatementUploadSheet> {
  bool _isProcessing = false;
  String _statusText = 'Banka ekstresi veya maaş bordrosu seçin';

  Future<void> _pickAndProcessPdf() async {
    try {
      // 1. Kota Uygunluk Denetimi
      QuotaEnforcer.verifyUploadEligibility(
        isProUser: widget.isProUser,
        uploadsThisMonth: widget.currentMonthUploads,
      );

      // 2. Cihazdan PDF Seçimi
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        return; // Kullanıcı dosya seçimini iptal etti
      }

      setState(() {
        _isProcessing = true;
        _statusText = 'Belge taranıyor ve kişisel veriler maskeleniyor...';
      });

      final Uint8List fileBytes = result.files.single.bytes!;
      final String fileSha256 = sha256.convert(fileBytes).toString();

      // 3. Vektörel Metin Katmanını RAM'de Oku (On-Device)
      final PdfDocument document = PdfDocument(inputBytes: fileBytes);
      final String extractedText = PdfTextExtractor(document).extractText();
      document.dispose(); // RAM'deki ham PDF belgesini hemen yok et

      // 4. Parmak İzi Tespiti (Banka mı, Bordro mu?)
      final detection = BankDetector.identify(extractedText);

      if (detection.documentType == DocumentType.payslip) {
        // Bordro Akışı
        final payslipResult = GenericPayslipParser().parse(extractedText);
        final payslipRecord = payslipResult.toParsedRecord();

        await widget.repository.saveParsedStatement(
          fileSha256: fileSha256,
          institutionName: 'Kurumsal Bordro',
          accountType: 'PAYSLIP',
          periodStart: payslipResult.periodDate.toIso8601String().split('T')[0],
          periodEnd: payslipResult.periodDate.toIso8601String().split('T')[0],
          records: [payslipRecord],
        );
      } else {
        // Banka Hesabı veya Kredi Kartı Akışı
        final orchestrator = StatementOrchestrator();
        final records = await orchestrator.processDocument(rawPdfText: extractedText);

        if (records.isEmpty) {
          throw Exception('Belgede geçerli harcama veya işlem satırı bulunamadı.');
        }

        final periodDateStr = records.first.date.toIso8601String().split('T')[0];

        await widget.repository.saveParsedStatement(
          fileSha256: fileSha256,
          institutionName: detection.institution.name,
          accountType: detection.documentType == DocumentType.creditCard ? 'CREDIT_CARD' : 'CHECKING',
          periodStart: periodDateStr,
          periodEnd: records.last.date.toIso8601String().split('T')[0],
          records: records,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onUploadSuccess();
      }
    } on QuotaExceededException catch (e) {
      _showPaywallDialog(e.message);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Hata: $e';
      });
    }
  }

  void _showPaywallDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🦉 İzci: Kotan Doldu!'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () {
              Navigator.pop(ctx);
              // Google Play Billing satın alma akışını tetikle
            },
            child: const Text('Pro\'ya Geç (7 Gün Ücretsiz)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ekstre veya Bordro Analizi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _statusText,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator(color: Colors.black87))
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2022),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text('Cihazdan PDF Seç', style: TextStyle(color: Colors.white, fontSize: 16)),
              onPressed: _pickAndProcessPdf,
            ),
          const SizedBox(height: 12),
          const Text(
            '🔒 TCKN, kart numarası ve adres gibi kişisel verileriniz telefonunuzdan dışarı çıkmaz.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}