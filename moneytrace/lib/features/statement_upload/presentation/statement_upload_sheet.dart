// lib/features/statement_upload/presentation/statement_upload_sheet.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/parser/services/pdf_extractor_service.dart';
import '../../../core/parser/services/statement_orchestrator.dart';
import '../../../core/parser/models/parsed_models.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/security/security_guard.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/services/notification_service.dart';
import '../../subscription/presentation/subscription_plans_sheet.dart';
import '../services/batch_upload_tally.dart';

class StatementUploadSheet extends StatefulWidget {
  final VoidCallback? onImportSuccess;
  final String? documentTypeHint;
  final String? documentTypeTitle;

  const StatementUploadSheet({
    super.key,
    this.onImportSuccess,
    this.documentTypeHint,
    this.documentTypeTitle,
  });

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
  bool _errorIsQuota = false;
  String? _selectedFileName;
  String? _fileHash;
  StatementDocumentResult? _parsedResult;
  late String _selectedDocType;

  // Toplu yükleme ilerlemesi ve sonuç özeti
  int _batchTotal = 0;
  int _batchDone = 0;
  String? _batchCurrent;
  List<String>? _batchReport;

  @override
  void initState() {
    super.initState();
    _selectedDocType = widget.documentTypeHint ?? 'CREDIT_CARD';
  }

  Future<void> _pickAndProcessPdf() async {
    setState(() {
      _errorMessage = null;
      _errorIsQuota = false;
      _parsedResult = null;
      _batchReport = null;
    });

    // 10. Madde: Aylık Kota ve Limit Kontrolü (ön kontrol; kesin düşüm kayıtta sunucuda yapılır)
    await UserProfileService.instance.refreshUploadUsage();
    if (!mounted) return;
    final quota = UserProfileService.instance
        .checkUploadQuota(documentTypeHint: _selectedDocType);
    if (!quota.canUpload && !UserProfileService.instance.inBackfillWindow) {
      setState(() {
        _errorMessage = quota.reason;
        _errorIsQuota = true;
      });
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        // Toplu seçimde tüm dosyaları belleğe almamak için mobilde yoldan okunur
        withData: kIsWeb,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return; // Kullanıcı seçim yapmadı ya da sayfa kapandı
      }

      if (result.files.length > 1) {
        await _processBatch(result.files);
        return;
      }

      final file = result.files.first;
      final bytes = await _readBytes(file);
      if (!mounted) return;
      if (bytes == null) {
        setState(() {
          _errorMessage = 'Dosya verisi okunamadı. Lütfen tekrar deneyin.';
        });
        return;
      }

      setState(() {
        _isProcessing = true;
        _selectedFileName = file.name;
      });

      final prepared = await _prepareDocument(bytes);
      if (!mounted) return;
      if (prepared.cancelled) {
        setState(() => _isProcessing = false);
        return;
      }
      if (prepared.error != null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = prepared.error;
        });
        return;
      }
      _fileHash = prepared.hash;
      setState(() {
        _isProcessing = false;
        _parsedResult = prepared.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage =
            'Belge işlenirken bir hata oluştu: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  Future<Uint8List?> _readBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    if (file.path == null) return null;
    return File(file.path!).readAsBytes();
  }

  /// Tek bir PDF'i doğrular, okur ve ayrıştırır; kaydetmez. Hata metni kullanıcıya gösterilecek biçimdedir.
  /// [rememberedPassword]: toplu yüklemede önceki dosyada çalışan parola önce sessizce denenir.
  Future<_PreparedDocument> _prepareDocument(Uint8List bytes,
      {String? rememberedPassword}) async {
    // 20 Maddelik Güvenlik Kuralı #13: File Upload Validation & Derin Zararlı Taraması
    final malwareScan = SecurityGuard.instance.scanPdfForMalware(bytes);
    if (!malwareScan.isSafe) {
      return _PreparedDocument.failed(
          'Belgede zararlı olabilecek içerik algılandı (${malwareScan.threatsDetected.first}).');
    }
    if (!SecurityGuard.instance.validatePdfFile(bytes: bytes)) {
      return const _PreparedDocument.failed('Geçersiz veya bozuk PDF dosyası.');
    }

    // 1. PDF düzeni ve SHA256 çıkarımı (PDFium, tamamen cihaz üzerinde; şifreliyse parola sorulur)
    final extracted =
        await _extractWithPassword(bytes, rememberedPassword: rememberedPassword);
    if (extracted == null) return _PreparedDocument.cancel;
    final (document, password) = extracted;

    // 2. Mükerrer Ekstre Kontrolü
    if (await _repository.isStatementAlreadyImported(document.sha256Hash)) {
      return const _PreparedDocument.failed(
          'Bu belge daha önce aktarılmış. Aynı belge ikinci kez eklenmedi.',
          duplicate: true);
    }

    // 3. Deterministik Orkestratör ile İşleme (Belge türü ipucuyla)
    final docResult = await _orchestrator.processDocument(
      layout: document.layout,
      documentTypeHint: _selectedDocType,
      userRules: await _repository.loadUserCategoryRules(),
    );

    // Aynı hesabın aynı dönemi (yeniden indirilmiş aynı ekstre) ikinci kez aktarılmasın
    if (await _repository.isSamePeriodAlreadyImported(docResult)) {
      return const _PreparedDocument.failed(
          'Bu hesabın bu dönemine ait belge daha önce aktarılmış. Aynı dönem ikinci kez eklenmedi.',
          duplicate: true);
    }
    return _PreparedDocument(
        result: docResult, hash: document.sha256Hash, password: password);
  }

  /// Kotayı sunucuda düşer ve kaydeder. Kota yoksa ya da sunucuya ulaşılamazsa kayıt yapılmaz.
  Future<(StatementSaveResult?, DocumentQuotaResult)> _consumeAndSave(
      StatementDocumentResult result, String hash, String? fileName) async {
    // Kota, seçilen çipe göre değil belgeden algılanan türe göre kontrol edilir ve sayılır
    final isBackfill =
        UserProfileService.instance.isFreeBackfill(result.periodEnd);
    final quota = await UserProfileService.instance
        .consumeUpload(result.documentType, isBackfill: isBackfill);
    if (!quota.canUpload) return (null, quota);
    final saved = await _repository.saveStatementResult(
      result: result,
      fileSha256: hash,
      fileName: fileName,
    );
    return (saved, quota);
  }

  /// Birden fazla PDF: sırayla okunur ve kaydedilir. Toplamıyla tutmayanlar sonda tek bir onayla (K11)
  /// kaydedilir; kota biterse kalanlar kaydedilmez ve özet listede yazılır. Sayfa toplu yükleme sürerken
  /// kapatılırsa kalan belgeler işlenmez; o ana kadar kaydedilenler için hatırlatıcı ve yenileme yine yapılır.
  Future<void> _processBatch(List<PlatformFile> files) async {
    setState(() {
      _isProcessing = true;
      _batchTotal = files.length;
      _batchDone = 0;
    });

    final tally = BatchUploadTally(files.length);
    final unbalanced = <(String, _PreparedDocument)>[];
    var hasPaymentInfo = false;
    String? password;
    DocumentQuotaResult? stopQuota;

    /// true: kaydedildi ya da mükerrer çıktı; false: kota/bağlantı durdurdu ([stopQuota]).
    Future<bool> save(String name, _PreparedDocument doc) async {
      final result = doc.result!;
      // Aynı toplu seçimdeki iki kopya ya da aynı dönemin iki ekstresi: ilki kaydedildikten sonra
      // ikincisi için kota harcanmaz (dosya özeti UNIQUE olduğundan kayıt da hata verirdi).
      if (await _repository.isStatementAlreadyImported(doc.hash!) ||
          await _repository.isSamePeriodAlreadyImported(result)) {
        tally.addDuplicate();
        return true;
      }
      final (saved, quota) = await _consumeAndSave(result, doc.hash!, name);
      if (saved == null) {
        stopQuota = quota;
        return false;
      }
      tally.addSaved(saved.inserted);
      if (result.summary.dueDate != null ||
          result.summary.scheduledPayments.isNotEmpty) {
        hasPaymentInfo = true;
      }
      return true;
    }

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      if (!mounted) break;
      setState(() {
        _batchDone = i;
        _batchCurrent = file.name;
      });
      try {
        final bytes = await _readBytes(file);
        if (bytes == null) {
          tally.addFailure(file.name, 'dosya okunamadı');
          continue;
        }
        final doc = await _prepareDocument(bytes, rememberedPassword: password);
        if (doc.cancelled) {
          tally.addFailure(file.name, 'parola girilmedi, atlandı');
          continue;
        }
        if (doc.error != null) {
          if (doc.duplicate) {
            tally.addDuplicate();
          } else {
            tally.addFailure(file.name, doc.error!);
          }
          continue;
        }
        password = doc.password ?? password;
        final rec = doc.result!.reconciliation;
        if (rec.isVerifiable && !rec.isBalanced) {
          unbalanced.add((file.name, doc));
          continue;
        }
        if (!await save(file.name, doc)) {
          // Bu belge, sonrakiler ve onay bekleyen tutmayanlar kaydedilmedi
          tally.stop(stopQuota!.reason,
              isNetworkError: stopQuota!.isNetworkError,
              remaining: files.length - i + unbalanced.length);
          unbalanced.clear();
          break;
        }
      } catch (e) {
        tally.addFailure(file.name, e.toString().replaceAll('Exception: ', ''));
      }
    }

    if (!tally.isStopped && unbalanced.isNotEmpty && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${unbalanced.length} belge toplamıyla tutmuyor'),
          content: SingleChildScrollView(
            child: Text([
              for (final (name, doc) in unbalanced)
                '• $name: ${doc.result!.reconciliation.issues.join(' ')}',
              '',
              'Yine de kaydedersen bu belgelerin işlemleri "doğrulanmadı" işaretiyle görünür ve toplamlar yanlış olabilir.',
            ].join('\n')),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Bunları atla')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yine de kaydet')),
          ],
        ),
      );
      for (final (j, (name, doc)) in unbalanced.indexed) {
        if (ok != true || !mounted) {
          tally.addFailure(name, 'toplamı tutmadığı için kaydedilmedi');
          continue;
        }
        try {
          if (!await save(name, doc)) {
            tally.stop(stopQuota!.reason,
                isNetworkError: stopQuota!.isNetworkError,
                remaining: unbalanced.length - j);
            break;
          }
        } catch (e) {
          tally.addFailure(name, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }

    if (hasPaymentInfo) {
      try {
        await NotificationService.instance.requestPermission();
        await NotificationService.instance
            .syncUpcomingPayments(await _repository.getUpcomingPayments());
      } catch (_) {}
    }

    // Sayfa kapanmış olsa da kaydedilenler için çağıran ekran yenilensin
    if (tally.saved > 0) widget.onImportSuccess?.call();
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _batchTotal = 0;
      _batchCurrent = null;
      _errorIsQuota = tally.isStopped && !tally.stopIsNetworkError;
      _errorMessage = tally.stopReason;
      _batchReport = tally.summaryLines();
    });
  }

  /// Şifreli ekstrelerde (bankalar genelde TCKN veya doğum tarihi tabanlı parola kullanır) parola ister.
  /// Kullanıcı vazgeçerse null döner. Parola hiçbir yerde saklanmaz; toplu yüklemede yalnız o yükleme
  /// boyunca bellekte kalır ve sonraki şifreli dosyada önce o denenir.
  Future<(ExtractedPdfDocument, String?)?> _extractWithPassword(Uint8List bytes,
      {String? rememberedPassword}) async {
    String? password;
    var triedRemembered = false;
    while (true) {
      try {
        return (
          await PdfExtractorService.extract(bytes, password: password),
          password
        );
      } on PdfPasswordRequiredException catch (e) {
        if (!triedRemembered && rememberedPassword != null) {
          triedRemembered = true;
          password = rememberedPassword;
          continue;
        }
        if (!mounted) return null;
        password = await _askPdfPassword(
            wrong: e.wasPasswordWrong && password != rememberedPassword);
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
        title: const Text('Şifreli Ekstre',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wrong
                  ? 'Parola hatalı. Lütfen tekrar deneyin.'
                  : 'Bu ekstre bankanız tarafından şifrelenmiş. PDF parolasını girin (parola kaydedilmez).',
              style: TextStyle(
                  fontSize: 12,
                  color:
                      wrong ? AppColors.expenseRed : AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'PDF parolası',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Aç')),
        ],
      ),
    );
  }

  /// Masraf satırı sayısı (faiz, ücret, vergi) — kayıt sonrası özet ve önizleme için
  static int _feeCount(StatementDocumentResult r) => r.records
      .where((x) =>
          x.kind == TransactionKind.interestFee ||
          x.kind == TransactionKind.tax)
      .length;
  static int _feeCents(StatementDocumentResult r) => r.records
      .where((x) =>
          x.kind == TransactionKind.interestFee ||
          x.kind == TransactionKind.tax)
      .fold(
          0,
          (sum, x) =>
              sum +
              (x.type == ParsedTransactionType.debit
                  ? x.billingAmountCents
                  : -x.billingAmountCents));

  Future<void> _saveStatement() async {
    if (_parsedResult == null || _fileHash == null) return;

    // Bankanın toplamıyla tutmayan ekstre: kaydetmeden önce açık onay (K11)
    final rec = _parsedResult!.reconciliation;
    if (rec.isVerifiable && !rec.isBalanced) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ekstre bankanın toplamıyla tutmuyor'),
          content: Text(
              '${rec.issues.join('\n')}\n\nYine de kaydedersen işlemler "doğrulanmadı" işaretiyle görünür ve toplamlar yanlış olabilir.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yine de kaydet')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final (saved, quota) =
          await _consumeAndSave(_parsedResult!, _fileHash!, _selectedFileName);
      if (!mounted) return;
      if (saved == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = quota.reason;
          _errorIsQuota = !quota.isNetworkError;
        });
        return;
      }

      // Yeni son ödeme tarihi / talimat varsa hatırlatıcı kur (ilk seferde bildirim izni istenir)
      if (_parsedResult!.summary.dueDate != null ||
          _parsedResult!.summary.scheduledPayments.isNotEmpty) {
        try {
          await NotificationService.instance.requestPermission();
          await NotificationService.instance
              .syncUpcomingPayments(await _repository.getUpcomingPayments());
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onImportSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.incomeGreen,
            content: Text(
              '${_parsedResult!.institution}: ${saved.inserted} işlem · '
              '${_feeCount(_parsedResult!)} masraf · '
              '${_parsedResult!.records.where((x) => x.installment != null).length} taksit kaydedildi'
              '${saved.skippedDuplicates > 0 ? ' (${saved.skippedDuplicates} işlem zaten vardı)' : ''}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    'Ekstre bu telefonda okunur, sunucuya gönderilmez',
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
            const Text(
              'Yüklenecek belge türü:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            // İlk faz: Yapı Kredi kart ekstresi ve bordro. Vadesiz okuyucu örnek dökümle eklenecek.
            Row(
              children: [
                _buildDocTypeChip('CREDIT_CARD', 'Yapı Kredi Kart',
                    Icons.credit_card_rounded),
                const SizedBox(width: 8),
                _buildDocTypeChip(
                    'PAYSLIP', 'Maaş Bordrosu', Icons.work_outline_rounded),
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
              child: _batchTotal > 1
                  ? Column(
                      children: [
                        LinearProgressIndicator(
                          value: _batchDone / _batchTotal,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(6),
                          color: AppColors.actionPrimary,
                          backgroundColor: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${_batchDone + 1} / $_batchTotal belge okunuyor',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        if (_batchCurrent != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _batchCurrent!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    )
                  : const Column(
                      children: [
                        CircularProgressIndicator(
                            strokeWidth: 3, color: AppColors.actionPrimary),
                        SizedBox(height: 16),
                        Text(
                          'Belge okunuyor, kişisel bilgiler maskeleniyor…',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
            )
          else if (_batchReport != null)
            _buildBatchReport()
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
                  if (_errorIsQuota) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => SubscriptionPlansSheet.show(context),
                        icon: const Icon(Icons.workspace_premium_rounded,
                            size: 16, color: Color(0xFF0F172A)),
                        label: const Text('Planları Gör',
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
                    onPressed: _saveStatement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.actionPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_alt_rounded,
                            size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Kaydet',
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

  /// Toplu yükleme sonucu: kaç belge kaydedildi, hangileri neden kaydedilmedi.
  Widget _buildBatchReport() {
    final lines = _batchReport!;
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
            children: [
              const Icon(Icons.task_alt_rounded,
                  size: 20, color: AppColors.incomeGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(lines.first,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
            ],
          ),
          if (lines.length > 1) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines.skip(1))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(line,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickAndProcessPdf,
                  child: const Text('Başka belge ekle'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.actionPrimary),
                  child: const Text('Bitti',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dosya seçici: dokununca sistem dosya seçicisi açılır (Android'in seçicisi ek izin istemez).
  /// Birden fazla PDF seçilebilir; hepsi sırayla okunup kaydedilir.
  Widget _buildUploadPlaceholder() {
    return InkWell(
      onTap: _pickAndProcessPdf,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Column(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: Icon(Icons.upload_file_rounded,
                    size: 26, color: AppColors.actionPrimary),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'PDF Seç',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            SizedBox(height: 4),
            Text(
              'Kredi kartı ekstresi veya maaş bordrosu. Birden fazla dosyayı birlikte seçebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
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
                        '${switch (result.documentType) {
                          'CREDIT_CARD' => 'Kredi kartı',
                          'PAYSLIP' => 'Maaş bordrosu',
                          _ => 'Vadesiz hesap'
                        }}'
                        '${result.accountIdentifier.isNotEmpty ? ' • ${result.accountIdentifier}' : ''}',
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
          if (result.summary.dueDate != null ||
              result.summary.statementBalanceCents != null) ...[
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
              if (_feeCount(result) > 0)
                _buildMiniMetric(
                    'Masraf (${_feeCount(result)} kalem)',
                    CurrencyNormalizer.formatCents(_feeCents(result)),
                    AppColors.tax),
              if (result.totalTaxCents > 0)
                _buildMiniMetric(
                    'Bordro kesintisi',
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
        ? (
            const Color(0xFFF1F5F9),
            AppColors.textSecondary,
            Icons.info_outline_rounded,
            'Bu belgede banka toplamı bulunmadığı için otomatik doğrulama yapılamadı.'
          )
        : rec.isBalanced
            ? (
                const Color(0xFFECFDF5),
                AppColors.incomeGreen,
                Icons.verified_rounded,
                'Bankanın dönem toplamlarıyla eşleşti.'
              )
            : (
                const Color(0xFFFEF2F2),
                AppColors.expenseRed,
                Icons.warning_amber_rounded,
                'Dikkat: ${rec.issues.join(' • ')}'
              );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 11.5, color: fg, fontWeight: FontWeight.w600))),
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
        const Icon(Icons.event_rounded,
            size: 16, color: AppColors.actionPrimary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(parts.join(' • '),
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
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

/// Kaydetmeye hazır, ayrıştırılmış tek belge ya da neden hazırlanamadığı.
class _PreparedDocument {
  final StatementDocumentResult? result;
  final String? hash;
  final String? password;
  final String? error;
  final bool duplicate;
  final bool cancelled;

  const _PreparedDocument({this.result, this.hash, this.password})
      : error = null,
        duplicate = false,
        cancelled = false;

  const _PreparedDocument.failed(String message, {this.duplicate = false})
      : error = message,
        result = null,
        hash = null,
        password = null,
        cancelled = false;

  const _PreparedDocument._cancelled()
      : result = null,
        hash = null,
        password = null,
        error = null,
        duplicate = false,
        cancelled = true;

  static const cancel = _PreparedDocument._cancelled();
}
