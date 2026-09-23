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
import '../../../core/services/notification_service.dart';
import '../../wallets/presentation/wallet_selection_sheet.dart';
import 'statement_smart_wizard.dart';
import 'custom_field_mapping_sheet.dart';

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

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onImportSuccess,
    String? documentTypeHint,
    String? documentTypeTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatementUploadSheet(
        onImportSuccess: onImportSuccess,
        documentTypeHint: documentTypeHint,
        documentTypeTitle: documentTypeTitle,
      ),
    );
  }

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
    final quota = UserProfileService.instance
        .checkUploadQuota(documentTypeHint: _selectedDocType);
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

      // 20 Maddelik Güvenlik Kuralı #13: File Upload Validation & Derin Zararlı Taraması
      final malwareScan = SecurityGuard.instance.scanPdfForMalware(bytes);
      if (!malwareScan.isSafe) {
        setState(() {
          _errorMessage =
              'Güvenlik Kalkanı: Belgede potansiyel zararlı içerik/exploit algılandı! (${malwareScan.threatsDetected.first})';
        });
        return;
      }

      if (!SecurityGuard.instance.validatePdfFile(bytes: bytes)) {
        setState(() {
          _errorMessage =
              'Güvenlik Reddi: Geçersiz veya bozuk PDF formatı! Dosya başlığı "%PDF-" doğrulanmalıdır.';
        });
        return;
      }

      setState(() {
        _isProcessing = true;
        _selectedFileName = file.name;
      });

      // 1. PDF düzeni ve SHA256 çıkarımı (PDFium, tamamen cihaz üzerinde; şifreliyse parola sorulur)
      final extracted = await _extractWithPassword(bytes);
      if (extracted == null) {
        setState(() => _isProcessing = false);
        return;
      }
      _fileHash = extracted.sha256Hash;

      // 2. Mükerrer Ekstre Kontrolü
      final alreadyImported =
          await _repository.isStatementAlreadyImported(extracted.sha256Hash);
      if (alreadyImported) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              'Bu ekstre belgesi daha önce cüzdanınıza aktarılmış! Mükerrer kayıt önlendi.';
        });
        return;
      }

      // 3. Deterministik Orkestratör ile İşleme (Belge türü ipucuyla)
      final docResult = await _orchestrator.processDocument(
        layout: extracted.layout,
        documentTypeHint: _selectedDocType,
        userRules: await _repository.loadUserCategoryRules(),
      );

      setState(() {
        _isProcessing = false;
        _parsedResult = docResult;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage =
            'Belge işlenirken bir hata oluştu: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  /// Şifreli ekstrelerde (bankalar genelde TCKN veya doğum tarihi tabanlı parola kullanır) parola ister.
  /// Kullanıcı vazgeçerse null döner. Parola hiçbir yerde saklanmaz.
  Future<ExtractedPdfDocument?> _extractWithPassword(Uint8List bytes) async {
    String? password;
    var wrong = false;
    while (true) {
      try {
        return await PdfExtractorService.extract(bytes, password: password);
      } on PdfPasswordRequiredException catch (e) {
        wrong = e.wasPasswordWrong;
        if (!mounted) return null;
        password = await _askPdfPassword(wrong: wrong);
        if (password == null) return null;
      }
    }
  }

  Future<String?> _askPdfPassword({required bool wrong}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Şifreli Ekstre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wrong
                  ? 'Parola hatalı. Lütfen tekrar deneyin.'
                  : 'Bu ekstre bankanız tarafından şifrelenmiş. PDF parolasını girin (parola kaydedilmez).',
              style: TextStyle(fontSize: 12, color: wrong ? AppColors.expenseRed : AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'PDF parolası',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Aç')),
        ],
      ),
    );
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
      final saved = await _repository.saveStatementResult(
        result: _parsedResult!,
        fileSha256: _fileHash!,
        fileName: _selectedFileName,
        targetWalletId: selectedWallet.id,
      );

      // Kota kullanımını kaydet
      await UserProfileService.instance.recordDocumentUpload(_selectedDocType);

      // Yeni son ödeme tarihi / talimat varsa hatırlatıcı kur (ilk seferde bildirim izni istenir)
      if (_parsedResult!.summary.dueDate != null || _parsedResult!.summary.scheduledPayments.isNotEmpty) {
        try {
          await NotificationService.instance.requestPermission();
          await NotificationService.instance.syncUpcomingPayments(await _repository.getUpcomingPayments());
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onImportSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.incomeGreen,
            content: Text(
              '${_parsedResult!.institution} ekstresi "${selectedWallet.name}" cüzdanına aktarıldı: '
              '${saved.inserted} yeni işlem'
              '${saved.skippedDuplicates > 0 ? ', ${saved.skippedDuplicates} mükerrer işlem atlandı' : ''}.',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded,
                        size: 14, color: AppColors.actionPrimary),
                    SizedBox(width: 4),
                    Text(
                      'Gizlilik Korumalı',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.actionPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Madde: Belge Türü Seçimi (Ekstre / Bordro / Kredi Kartı)
          if (_parsedResult == null && !_isProcessing) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Yüklenecek Belge Türü:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                TextButton.icon(
                  onPressed: () {
                    CustomFieldMappingSheet.show(context);
                  },
                  icon: const Icon(Icons.alt_route_rounded,
                      size: 14, color: Color(0xFF2563EB)),
                  label: const Text('Şablon / Alan Eşle',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDocTypeChip('CHECKING', 'Hesap Ekstresi',
                    Icons.account_balance_rounded),
                const SizedBox(width: 8),
                _buildDocTypeChip(
                    'PAYSLIP', 'Maaş Bordrosu', Icons.work_outline_rounded),
                const SizedBox(width: 8),
                _buildDocTypeChip(
                    'CREDIT_CARD', 'Kredi Kartı', Icons.credit_card_rounded),
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
                  CircularProgressIndicator(
                      strokeWidth: 3, color: AppColors.actionPrimary),
                  SizedBox(height: 16),
                  Text(
                    'Belge ayrıştırılıyor ve PII maskeleniyor...',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.expenseRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.expenseRed,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        CustomFieldMappingSheet.show(context);
                      },
                      icon: const Icon(Icons.tune_rounded,
                          size: 16, color: Color(0xFF0F172A)),
                      label: const Text(
                          'Bu Banka İçin Alan Eşleştirmesi (Mapping) Tanımla',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A))),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      'Farklı Belge Seç',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'İncele & Cüzdana Aktar',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: Colors.white),
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
              border: Border.all(
                  color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
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
                  child: const Icon(Icons.upload_file_rounded,
                      size: 26, color: AppColors.actionPrimary),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Veya Dokunarak Dosya Seçin',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
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
                    child: const Icon(Icons.account_balance_rounded,
                        size: 20, color: AppColors.actionPrimary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.institution,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        '${result.documentType} • ${result.accountIdentifier}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${result.records.length} İşlem Bulundu',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.incomeGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReconciliationBanner(result),
          if (result.summary.dueDate != null || result.summary.statementBalanceCents != null) ...[
            const SizedBox(height: 8),
            _buildPaymentScheduleRow(result.summary),
          ],
          const Divider(height: 24, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric(
                  'Gider',
                  CurrencyNormalizer.formatCents(result.totalDebitCents),
                  AppColors.expenseRed),
              _buildMiniMetric(
                  'Gelir',
                  CurrencyNormalizer.formatCents(result.totalCreditCents),
                  AppColors.incomeGreen),
              if (result.totalTaxCents > 0)
                _buildMiniMetric(
                    'Vergi/Harç',
                    CurrencyNormalizer.formatCents(result.totalTaxCents),
                    AppColors.tax),
            ],
          ),
        ],
      ),
    );
  }

  /// Bankanın kendi beyanıyla (dönem toplamları / bakiye zinciri) karşılaştırma sonucu
  Widget _buildReconciliationBanner(StatementDocumentResult result) {
    final rec = result.reconciliation;
    final (Color bg, Color fg, IconData icon, String text) = !rec.isVerifiable
        ? (const Color(0xFFF1F5F9), AppColors.textSecondary, Icons.info_outline_rounded,
            'Bu belgede banka toplamı bulunmadığı için otomatik doğrulama yapılamadı.')
        : rec.isBalanced
            ? (const Color(0xFFECFDF5), AppColors.incomeGreen, Icons.verified_rounded,
                'Bankanın beyan ettiği toplamlarla kuruşu kuruşuna doğrulandı.')
            : (const Color(0xFFFEF2F2), AppColors.expenseRed, Icons.warning_amber_rounded,
                'Dikkat: ${rec.issues.join(' • ')}');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11.5, color: fg, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildPaymentScheduleRow(StatementSummary summary) {
    String date(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    final parts = <String>[
      if (summary.statementBalanceCents != null)
        'Dönem borcu ${CurrencyNormalizer.formatCents(summary.statementBalanceCents!)}',
      if (summary.minimumPaymentCents != null)
        'Asgari ${CurrencyNormalizer.formatCents(summary.minimumPaymentCents!)}',
      if (summary.dueDate != null) 'Son ödeme ${date(summary.dueDate!)}',
    ];
    return Row(
      children: [
        const Icon(Icons.event_rounded, size: 16, color: AppColors.actionPrimary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(parts.join(' • '),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: color)),
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
            color:
                isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFCBD5E1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected
                      ? AppColors.actionPrimary
                      : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.actionPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
