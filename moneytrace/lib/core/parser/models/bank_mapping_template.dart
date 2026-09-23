// lib/core/parser/models/bank_mapping_template.dart

/// Kullanıcı veya yönetici tarafından tanımlanan deterministik dekont & ekstre alan eşleme şablonu.
/// Körü körüne regex tahmini yapmak yerine, belgedeki etiketleri doğrudan FinScout şemasıyla eşleştirir.
class BankMappingTemplate {
  final String id;
  final String bankName;
  final String templateName;
  final String
      documentType; // 'RECEIPT' (Dekont), 'STATEMENT' (Ekstre), 'PAYSLIP' (Bordro)

  // Kaynak Belgedeki Etiket/Kolon Eşleştirmeleri
  final String
      amountField; // Örn: 'İşlem Tutarı:', 'Tutar:', 'Gönderilen Tutar:'
  final String? dateField; // Örn: 'İşlem Tarihi:', 'Tarih:', 'Valör:'
  final String? descriptionField; // Örn: 'Açıklama:', 'İşlem Açıklaması:'
  final String? recipientField; // Örn: 'Alıcı:', 'Alıcı Adı:', 'Karşı Taraf:'
  final String? feeField; // Örn: 'Masraf / Komisyon:', 'BSMV:'
  final String? balanceField; // Örn: 'Kalan Bakiye:', 'Hesap Bakiyesi:'

  // Varsayılan Alan Değerleri
  final String defaultTransactionType; // 'EXPENSE', 'INCOME', 'TRANSFER'
  final String defaultCategory; // 'diger', 'fatura', 'kira', 'finans'
  final List<String>
      matchKeywords; // Belgenin bu şablona ait olduğunu doğrulayan anahtar kelimeler

  const BankMappingTemplate({
    required this.id,
    required this.bankName,
    required this.templateName,
    this.documentType = 'RECEIPT',
    required this.amountField,
    this.dateField,
    this.descriptionField,
    this.recipientField,
    this.feeField,
    this.balanceField,
    this.defaultTransactionType = 'EXPENSE',
    this.defaultCategory = 'diger',
    this.matchKeywords = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_name': bankName,
      'template_name': templateName,
      'document_type': documentType,
      'amount_field': amountField,
      'date_field': dateField,
      'description_field': descriptionField,
      'recipient_field': recipientField,
      'fee_field': feeField,
      'balance_field': balanceField,
      'default_transaction_type': defaultTransactionType,
      'default_category': defaultCategory,
      'match_keywords': matchKeywords,
    };
  }

  factory BankMappingTemplate.fromJson(Map<String, dynamic> json) {
    return BankMappingTemplate(
      id: json['id'] as String,
      bankName: json['bank_name'] as String? ?? 'Bilinmeyen Banka',
      templateName: json['template_name'] as String? ?? 'Özel Şablon',
      documentType: json['document_type'] as String? ?? 'RECEIPT',
      amountField: json['amount_field'] as String? ?? 'Tutar',
      dateField: json['date_field'] as String?,
      descriptionField: json['description_field'] as String?,
      recipientField: json['recipient_field'] as String?,
      feeField: json['fee_field'] as String?,
      balanceField: json['balance_field'] as String?,
      defaultTransactionType:
          json['default_transaction_type'] as String? ?? 'EXPENSE',
      defaultCategory: json['default_category'] as String? ?? 'diger',
      matchKeywords: (json['match_keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
