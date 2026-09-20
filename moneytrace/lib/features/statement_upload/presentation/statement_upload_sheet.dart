// lib/features/statement_upload/presentation/statement_upload_sheet.dart

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/parser/services/pdf_extractor_service.dart';
import '../../../core/parser/services/statement_orchestrator.dart';
import '../../../core/parser/models/parsed_models.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/security/security_guard.dart';
import '../../../core/widgets/interactive_file_upload_button.dart';
import '../../../core/services/user_profile_service.dart';
import '../../wallets/presentation/wallet_selection_sheet.dart';
import '../../wallets/models/wallet.dart';
import 'statement_smart_wizard.dart';

class StatementUploadSheet extends StatefulWidget {
  final VoidCallback? onImportSuccess;
  final String? documentTypeHint;
  final String? documentTypeTitle;

  const StatementUploadSheet({
    Key? key,
    this.onImportSuccess,
    this.documentTypeHint,
    this.documentTypeTitle,
  }) : super(key: key);

  @override
  State<StatementUploadSheet> createState() => _StatementUploadSheetState();
}

class _StatementUploadSheetState extends State<StatementUploadSheet> {
  final StatementOrchestrator _orchestrator = StatementOrchestrator();
  final TransactionRepository _repository = TransactionRepository();

  bool _isProcessing = false;
  String? _errorMessage;
  String? _selectedFileName;
  String? _fileHash;
  StatementDocumentResult? _parsedResult;
  late String _selectedDocType;

  @override
  void initState() {
    super.initState();
    _selectedDocType = widget.documentTypeHint ?? 'CHECKING';
  }

  Future<void> _pickAndProcessPdf() async {
    setState(() {
      _errorMessage = null;
      _parsedResult = null;
    });

    // 10. Madde: Aylık Kota ve Limit Kontrolü
    final quota = UserProfileService.instance.checkUploadQuota(documentTypeHint: _selectedDocType);
    if (!quota.canUpload) {
      setState(() {
        _errorMessage = quota.reason;
      });
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Web & Mobile uyumlu bayt okuma
      );

      if (result == null || result.files.isEmpty) {
        return; // Kullanıcı seçim yapmadı
      }

      final file = result.files.first;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        setState(() {
          _errorMessage = 'Dosya verisi okunamadı. Lütfen tekrar deneyin.';
        });
        return;
      }

      // 20 Maddelik Güvenlik Kuralı #13: File Upload Validation (Magic Byte & Boyut)
      if (!SecurityGuard.instance.validatePdfFile(bytes: bytes)) {
        setState(() {
          _errorMessage = 'Güvenlik Reddi: Geçersiz veya bozuk PDF formatı! Dosya başlığı "%PDF-" doğrulanmalıdır.';
        });
        return;
      }

      setState(() {
        _isProcessing = true;
        _selectedFileName = file.name;
      });

      // 1. PDF Metin ve SHA256 Çıkarımı (Yerel)
      final extracted = PdfExtractorService.extractTextFromBytes(bytes);
      _fileHash = extracted.sha256Hash;

      // 2. Mükerrer Ekstre Kontrolü
      final alreadyImported = await _repository.isStatementAlreadyImported(extracted.sha256Hash);
      if (alreadyImported) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Bu ekstre belgesi daha önce cüzdanınıza aktarılmış! Mükerrer kayıt önlendi.';
        });
        return;
      }

      // 3. Deterministik Orkestratör ile İşleme (Belge türü ipucuyla)
      final docResult = await _orchestrator.processDocument(
        rawPdfText: extracted.text,
        documentTypeHint: _selectedDocType,
      );

      setState(() {
        _isProcessing = false;
        _parsedResult = docResult;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Belge işlenirken bir hata oluştu: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  Future<void> _startSmartImportWizard() async {
    if (_parsedResult == null || _fileHash == null) return;

    // 1. Kullanıcıya yönelik akıllı kararlar diyaloğunu aç
    final decision = await showDialog<SmartWizardDecisionResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatementSmartWizardDialog(
        result: _parsedResult!,
        salaryDayOfMonth: 15, // Varsayılan 15'i maaş günü
      ),
    );

    if (decision == null) {
      return; // Kullanıcı iptal etti
    }

    // 2. Madde: Cüzdan Seçimi Diyaloğu
    final selectedWallet = await WalletSelectionSheet.show(
      context,
      title: 'İşlemler Hangi Cüzdana Aktarılsın?',
    );

    if (selectedWallet == null) {
      return; // Cüzdan seçilmedi
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Kararları uygulayarak veritabanına ve seçilen cüzdana kaydet
      await _repository.saveStatementResult(
        result: _parsedResult!,
        fileSha256: _fileHash!,
        fileName: _selectedFileName,
        targetWalletId: selectedWallet.id,
      );

      // Kota kullanımını kaydet
      await UserProfileService.instance.recordDocumentUpload(_selectedDocType);

      if (mounted) {
        Navigator.pop(context);
        widget.onImportSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.incomeGreen,
            content: Text(
              '${_parsedResult!.institution} ekstresi "${selectedWallet.name}" cüzdanına başarıyla aktarıldı! (${_parsedResult!.records.length} işlem)',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Veritabanına kaydedilirken hata: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Başlık ve Güvenlik Rozeti
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Ekstre / Bordro Yükle',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Cihazda %100 Güvenli & Çevrimdışı Ayrıştırma',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded, size: 14, color: AppColors.actionPrimary),
                    SizedBox(width: 4),
                    Text(
                      'Gizlilik Korumalı',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.actionPrimary),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 16),

          // 1. Madde: Belge Türü Seçimi (Ekstre / Bordro / Kredi Kartı)
          if (_parsedResult == null && !_isProcessing) ...[
            const Text(
              'Yüklenecek Belge Türü:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDocTypeChip('CHECKING', 'Hesap Ekstresi', Icons.account_balance_rounded),
                const SizedBox(width: 8),
                _buildDocTypeChip('PAYSLIP', 'Maaş Bordrosu', Icons.work_outline_rounded),
                const SizedBox(width: 8),
                _buildDocTypeChip('CREDIT_CARD', 'Kredi Kartı', Icons.credit_card_rounded),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Yükleme Alanı veya Önizleme
          if (_isProcessing)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: const [
                  CircularProgressIndicator(strokeWidth: 3, color: AppColors.actionPrimary),
                  SizedBox(height: 16),
                  Text(
                    'Belge ayrıştırılıyor ve PII maskeleniyor...',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
            )
          else if (_parsedResult == null)
            _buildUploadPlaceholder()
          else
            _buildPreviewArea(),

          // Hata Mesajı
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.expenseRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: AppColors.expenseRed, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Aksiyon Butonları
          if (_parsedResult != null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickAndProcessPdf,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      'Farklı Belge Seç',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startSmartImportWizard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.actionPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.checklist_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'İncele & Cüzdana Aktar',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      children: [
        // Video 3: Morflayan Dosya Yükleme Butonu (Idle -> % Progress -> Checkmark)
        InteractiveFileUploadButton(
          fileName: _selectedFileName ?? 'Banka_Ekstre_veya_Bordro.pdf',
          uploadLabel: 'PDF Belgesi Seç & Tara',
          successLabel: 'Ayrıştırma Başarılı',
          onUploadAction: _pickAndProcessPdf,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickAndProcessPdf,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.upload_file_rounded, size: 26, color: AppColors.actionPrimary),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Veya Dokunarak Dosya Seçin',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enpara, Yapı Kredi veya Kurumsal Bordro PDF\'i',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewArea() {
    final result = _parsedResult!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded, size: 20, color: AppColors.actionPrimary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.institution,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${result.documentType} • ${result.accountIdentifier}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${result.records.length} İşlem Bulundu',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.incomeGreen),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric('Gider', CurrencyNormalizer.formatCents(result.totalDebitCents), AppColors.expenseRed),
              _buildMiniMetric('Gelir', CurrencyNormalizer.formatCents(result.totalCreditCents), AppColors.incomeGreen),
              if (result.totalTaxCents > 0)
                _buildMiniMetric('Vergi/Harç', CurrencyNormalizer.formatCents(result.totalTaxCents), AppColors.tax),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildDocTypeChip(String typeKey, String label, IconData icon) {
    final isSelected = _selectedDocType == typeKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDocType = typeKey;
            _errorMessage = null;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? AppColors.actionPrimary : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.actionPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
