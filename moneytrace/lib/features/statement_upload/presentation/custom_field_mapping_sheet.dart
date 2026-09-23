// lib/features/statement_upload/presentation/custom_field_mapping_sheet.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/parser/models/bank_mapping_template.dart';
import '../../../core/parser/services/custom_field_mapping_service.dart';

class CustomFieldMappingSheet extends StatefulWidget {
  final String? initialText;
  final Function(BankMappingTemplate savedTemplate)? onTemplateSaved;

  const CustomFieldMappingSheet({
    Key? key,
    this.initialText,
    this.onTemplateSaved,
  }) : super(key: key);

  static Future<BankMappingTemplate?> show(
    BuildContext context, {
    String? initialText,
    Function(BankMappingTemplate savedTemplate)? onTemplateSaved,
  }) {
    return showModalBottomSheet<BankMappingTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomFieldMappingSheet(
        initialText: initialText,
        onTemplateSaved: onTemplateSaved,
      ),
    );
  }

  @override
  State<CustomFieldMappingSheet> createState() =>
      _CustomFieldMappingSheetState();
}

class _CustomFieldMappingSheetState extends State<CustomFieldMappingSheet> {
  final _bankNameController = TextEditingController(text: 'Fibabanka');
  final _templateNameController =
      TextEditingController(text: 'Fibabanka FAST Dekont Şablonu');
  late TextEditingController _rawTextController;

  // Tespit edilen ham etiketler ve değerleri
  Map<String, String> _detectedFields = {};

  // Eşleştirilen Alanlar
  String? _selectedAmountField;
  String? _selectedDateField;
  String? _selectedDescField;
  String? _selectedRecipientField;
  String _selectedTxType = 'EXPENSE'; // EXPENSE, INCOME, TRANSFER

  // Hazır Dekont Örnekleri
  static const String _sampleFibabankaText = '''
FİBABANKA A.Ş. FAST PARA TRANSFERİ DEKONTU
Dekont No: FB-2026-981240
İşlem Tarihi: 18.09.2026 14:32:10
Gönderen Hesap: TR12 0010 3000 0000 1234 5678 90
Alıcı Adı: Ahmet Yılmaz
Alıcı IBAN: TR98 0006 2000 0000 9876 5432 10
İşlem Tutarı: 2.750,00 TL
Masraf / Komisyon: 0,00 TL
Kalan Bakiye: 34.250,00 TL
Açıklama: Eylül Ayı Daire Kira Bedeli
İşlem Durumu: Başarılı / Gerçekleşti
''';

  static const String _sampleKuveytTurkText = '''
KUVEYT TÜRK KATILIM BANKASI
HESAP DETAYI VE İŞLEM DEKONTU
İşlem Tarihi: 15.09.2026
Tutar: 1.200,00 TL
Hesap Bakiyesi: 18.400,00 TL
Alıcı Ünvanı / Adı: Enerjisa Elektrik Dağıtım A.Ş.
Açıklama: Fatura Ödemesi Abone No 98124
Kanal: Mobil Şube
''';

  @override
  void initState() {
    super.initState();
    _rawTextController =
        TextEditingController(text: widget.initialText ?? _sampleFibabankaText);
    _parseRawTextAndExtractFields();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _templateNameController.dispose();
    _rawTextController.dispose();
    super.dispose();
  }

  void _parseRawTextAndExtractFields() {
    final fields = CustomFieldMappingService.instance
        .extractCandidateFields(_rawTextController.text);
    setState(() {
      _detectedFields = fields;

      // Otomatik varsayılan alan eşleme tahmini
      _selectedAmountField = _findBestMatchKey(
          ['işlem tutarı:', 'tutar:', 'gönderilen tutar:', 'tutar']);
      _selectedDateField =
          _findBestMatchKey(['işlem tarihi:', 'tarih:', 'tarih / saat:']);
      _selectedDescField =
          _findBestMatchKey(['açıklama:', 'işlem açıklaması:']);
      _selectedRecipientField = _findBestMatchKey(
          ['alıcı adı:', 'alıcı:', 'alıcı ünvanı / adı:', 'karşı taraf:']);
    });
  }

  String? _findBestMatchKey(List<String> candidates) {
    for (final candidate in candidates) {
      for (final key in _detectedFields.keys) {
        if (key.toLowerCase().contains(candidate.toLowerCase())) {
          return key;
        }
      }
    }
    return _detectedFields.keys.isNotEmpty ? _detectedFields.keys.first : null;
  }

  void _applySampleText(String bankName, String templateName, String text) {
    setState(() {
      _bankNameController.text = bankName;
      _templateNameController.text = templateName;
      _rawTextController.text = text;
    });
    _parseRawTextAndExtractFields();
  }

  void _saveMappingTemplate() async {
    final bankName = _bankNameController.text.trim();
    final templateName = _templateNameController.text.trim();

    if (bankName.isEmpty || templateName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.expenseRed,
          content: Text('Lütfen banka adı ve şablon adını doldurun.'),
        ),
      );
      return;
    }

    if (_selectedAmountField == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.expenseRed,
          content: Text('Lütfen belgedeki "Tutar (Amount)" alanını seçin.'),
        ),
      );
      return;
    }

    final newTemplate = BankMappingTemplate(
      id: 'template_${DateTime.now().millisecondsSinceEpoch}',
      bankName: bankName,
      templateName: templateName,
      documentType: 'RECEIPT',
      amountField: _selectedAmountField!,
      dateField: _selectedDateField,
      descriptionField: _selectedDescField,
      recipientField: _selectedRecipientField,
      defaultTransactionType: _selectedTxType,
      matchKeywords: [bankName.toUpperCase(), 'DEKONT'],
    );

    await CustomFieldMappingService.instance.saveTemplate(newTemplate);

    if (widget.onTemplateSaved != null) {
      widget.onTemplateSaved!(newTemplate);
    }

    if (mounted) {
      Navigator.of(context).pop(newTemplate);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF059669),
          content: Text(
              '"$templateName" şablonu kaydedildi! Artık bu bankanın dekontları hatasız okunacak.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Canlı önizleme için tutar hesaplama
    final amountValStr = _selectedAmountField != null
        ? _detectedFields[_selectedAmountField] ?? '0,00 TL'
        : '0,00 TL';
    final previewCents = CurrencyNormalizer.toMinorUnits(amountValStr);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Başlık ve Açıklama
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.alt_route_rounded,
                    color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Banka Dekont & Ekstre Eşleme',
                      style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      'Körü körüne okuma yerine alanları birebir eşleştirin.',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // İçerik Kaydırma Alanı
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hızlı Örnek Seçimi
                  const Text('Hazır Banka Örnekleri:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickSampleChip('Fibabanka FAST', () {
                          _applySampleText('Fibabanka',
                              'Fibabanka FAST Dekontu', _sampleFibabankaText);
                        }),
                        const SizedBox(width: 8),
                        _buildQuickSampleChip('Kuveyt Türk Dekont', () {
                          _applySampleText(
                              'Kuveyt Türk',
                              'Kuveyt Türk Para Transferi',
                              _sampleKuveytTurkText);
                        }),
                        const SizedBox(width: 8),
                        _buildQuickSampleChip('Metni Temizle / Yapıştır', () {
                          _applySampleText(
                              'Yeni Banka', 'Özel Dekont Şablonu', '');
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Banka Adı & Şablon Adı
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _bankNameController,
                          decoration: InputDecoration(
                            labelText: 'Banka Adı *',
                            labelStyle: const TextStyle(fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _templateNameController,
                          decoration: InputDecoration(
                            labelText: 'Şablon Adı *',
                            labelStyle: const TextStyle(fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Ham Dekont Metni Alanı
                  const Text('Dekont / Ekstre Metni:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _rawTextController,
                    maxLines: 5,
                    style: const TextStyle(
                        fontSize: 11.5, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText:
                          'Dekont veya ekstre metnini buraya yapıştırın...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                    onChanged: (_) => _parseRawTextAndExtractFields(),
                  ),
                  const SizedBox(height: 18),

                  // ==========================================
                  // ALAN EŞLEŞTİRME KARTI (Mapping Box)
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.check_circle_outline_rounded,
                                color: Color(0xFF16A34A), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'ALAN EŞLEŞTİRME (MAPPING)',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Uygulamadaki alanların belgedeki hangi satıra denk geldiğini belirleyin:',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF166534)),
                        ),
                        const SizedBox(height: 14),

                        // 1. TUTAR ALANI EŞLEMESİ (EN KRİTİK ALAN)
                        _buildMappingDropdown(
                          title: 'Tutar (Amount) Hangi Alanda? *',
                          icon: Icons.payments_outlined,
                          selectedValue: _selectedAmountField,
                          onChanged: (val) =>
                              setState(() => _selectedAmountField = val),
                          highlightColor: const Color(0xFF16A34A),
                        ),
                        const SizedBox(height: 12),

                        // 2. İŞLEM TARİHİ EŞLEMESİ
                        _buildMappingDropdown(
                          title: 'İşlem Tarihi (Date) Hangi Alanda?',
                          icon: Icons.calendar_today_rounded,
                          selectedValue: _selectedDateField,
                          onChanged: (val) =>
                              setState(() => _selectedDateField = val),
                        ),
                        const SizedBox(height: 12),

                        // 3. ALICI / KARŞI TARAF
                        _buildMappingDropdown(
                          title: 'Alıcı / Gönderen Adı Hangi Alanda?',
                          icon: Icons.person_outline_rounded,
                          selectedValue: _selectedRecipientField,
                          onChanged: (val) =>
                              setState(() => _selectedRecipientField = val),
                        ),
                        const SizedBox(height: 12),

                        // 4. AÇIKLAMA ALANI
                        _buildMappingDropdown(
                          title: 'İşlem Açıklaması Hangi Alanda?',
                          icon: Icons.description_outlined,
                          selectedValue: _selectedDescField,
                          onChanged: (val) =>
                              setState(() => _selectedDescField = val),
                        ),
                        const SizedBox(height: 12),

                        // 5. İŞLEM YÖNÜ (Gider vs Gelir)
                        const Text(
                          'Varsayılan İşlem Türü',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildTxTypeButton(
                                'Gider / Transfer',
                                'EXPENSE',
                                Icons.arrow_outward_rounded,
                                AppColors.expenseRed),
                            const SizedBox(width: 8),
                            _buildTxTypeButton(
                                'Gelir / Yatırma',
                                'INCOME',
                                Icons.arrow_downward_rounded,
                                AppColors.incomeGreen),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ==========================================
                  // CANLI DOĞRULAMA & ÖNİZLEME KARTI
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 10,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CANLI EŞLEŞTİRME ÖNİZLEMESİ',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF38BDF8),
                                  letterSpacing: 0.5),
                            ),
                            Icon(Icons.visibility_outlined,
                                color: Color(0xFF38BDF8), size: 16),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Algılanan Tutar:',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF94A3B8))),
                            Text(
                              CurrencyNormalizer.formatCents(previewCents),
                              style: AppTheme.numericStyle.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF34D399)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Algılanan Tarih:',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF94A3B8))),
                            Text(
                              _selectedDateField != null
                                  ? (_detectedFields[_selectedDateField] ??
                                      'Bugün')
                                  : 'Belirtilmedi',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Karşı Taraf / Açıklama:',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF94A3B8))),
                            Expanded(
                              child: Text(
                                _selectedRecipientField != null
                                    ? (_detectedFields[
                                            _selectedRecipientField] ??
                                        '-')
                                    : '-',
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Şablonu Kaydet Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveMappingTemplate,
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: const Text('Şablonu Kaydet ve Eşlemeyi Kullan',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSampleChip(String label, VoidCallback onTap) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A))),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildMappingDropdown({
    required String title,
    required IconData icon,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    Color? highlightColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon,
                size: 14, color: highlightColor ?? const Color(0xFF475569)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: highlightColor ?? const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlightColor != null
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFCBD5E1),
              width: highlightColor != null ? 1.5 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _detectedFields.containsKey(selectedValue)
                  ? selectedValue
                  : null,
              hint: const Text('Belgeden bir alan seçin...',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              isExpanded: true,
              items: _detectedFields.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Text(entry.key,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTxTypeButton(
      String label, String value, IconData icon, Color color) {
    final isSelected = _selectedTxType == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTxType = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected ? color : const Color(0xFFCBD5E1),
                width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isSelected ? color : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
