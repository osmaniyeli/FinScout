// lib/core/localization/app_strings.dart

import 'package:flutter/material.dart';

class AppStrings {
  static final ValueNotifier<String> currentLocale = ValueNotifier<String>('tr');

  static bool get isTurkish => currentLocale.value == 'tr';

  static void setLocale(String langCode) {
    if (langCode == 'tr' || langCode == 'en') {
      currentLocale.value = langCode;
    }
  }

  static String get(String key) {
    final lang = currentLocale.value;
    return _localizedValues[lang]?[key] ?? _localizedValues['tr']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'tr': {
      'app_name': 'FinScout',
      'tagline': 'Harcama Zekası ve Deterministik Finans Motoru',
      // Nav
      'nav_home': 'Ana Sayfa',
      'nav_cashflow': 'Cüzdan',
      'nav_analysis': 'Analiz',
      'nav_goals': 'Hedefler',
      'nav_assets': 'Varlıklar',
      // Top bar & Profile
      'welcome': 'Hoş Geldin,',
      'guest_user': 'Kullanıcı',
      'profile_title': 'Kişisel Bilgiler',
      'profile_edit': 'Profili Düzenle',
      'profile_name': 'Ad Soyad',
      'profile_email': 'E-posta / İletişim',
      'profile_currency': 'Ana Para Birimi',
      'profile_budget_target': 'Aylık Bütçe Hedefi',
      'profile_joined_date': 'Kayıt Tarihi',
      'app_settings_btn': 'Uygulama Ayarları',
      'switch_account_btn': 'Hesap Değiştir',
      'logout_btn': 'Hesaptan Çıkış Yap',
      // Dashboard
      'month_total': 'AYI TOPLAMI',
      'total_expense': 'TOPLAM GİDER',
      'total_income': 'TOPLAM GELİR',
      'net_difference': 'NET FARK: ',
      'recent_records': 'KAYITLAR',
      'record_count': 'Kayıt',
      'no_transactions_title': 'Henüz İşlem Kaydı Bulunmuyor',
      'no_transactions_subtitle': 'Banka ekstrenizi veya maaş bordronuzu sağ üstteki butondan yükleyebilir ya da hızlı işlem ekleyebilirsiniz.',
      'add_first_transaction': 'İlk İşlemini Ekle',
      // PDF Upload & Dialog
      'upload_pdf_tooltip': 'Belge / Ekstre Yükle',
      'select_doc_type_title': 'Yüklenecek Belge Türünü Seçin',
      'select_doc_type_subtitle': 'Doğru kategorizasyon için yükleyeceğiniz belgenin türünü belirleyin:',
      'doc_credit_card': 'Kredi Kartı / Hesap Özeti (Ekstre)',
      'doc_credit_card_desc': 'Yapı Kredi, Enpara vb. kredi kartı ekstreleri',
      'doc_payslip': 'Maaş Bordrosu',
      'doc_payslip_desc': 'Aylık net maaş, prim ve vergi kesintileri dökümü',
      'doc_bank_statement': 'Banka Hesap Hareketi',
      'doc_bank_statement_desc': 'Vadesiz TL/Döviz hesap hareket dökümleri',
      'doc_invoice': 'Fatura / Makbuz',
      'doc_invoice_desc': 'Elektrik, su, doğalgaz veya alışveriş faturaları',
      // Notifications
      'notifications_title': 'Bildirimler ve Tavsiyeler',
      'no_notifications': 'Henüz bir bildirim veya tavsiye bulunmuyor.',
      'mark_all_read': 'Tümünü Okundu Say',
      'clear_all': 'Tümünü Temizle',
      'mark_read': 'Okundu',
      'delete': 'Sil',
      // Settings
      'settings_title': 'Ayarlar',
      'language_option': 'Dil Seçeneği',
      'data_management': 'Veri Yönetimi',
      'export_excel': 'Excel Olarak Dışa Aktar (.csv)',
      'export_backup': 'Sistem Yedeği Al (.json)',
      'restore_backup': 'Yedekten Geri Yükle',
      'subscription_status': 'Abonelik ve Google Play',
      'delete_all_data': 'Tüm Verilerimi Sıfırla ve Sil',
      'delete_data_confirm_title': 'Tüm Verileriniz Silinsin mi?',
      'delete_data_confirm_msg': 'Bu işlem tüm hesap, harcama ve profil verilerinizi cihazınızdan kalıcı olarak silecektir. Bu işlem geri alınamaz. Devam etmek istiyor musunuz?',
      'confirm_delete': 'Evet, Tümünü Sil',
      'cancel': 'İptal',
      'save': 'Kaydet',
      // Onboarding
      'onboarding_welcome_title': 'FinScout\'a Hoş Geldiniz',
      'onboarding_welcome_subtitle': 'Hesaplar arasında gezinmekten sıkılmadın mı?\nTek bir uygulama ile tüm hesaplarını takip et, borçlarını, maaşını ve ek gelirlerini tek hesapta yönet.',
      'marketing_motto': 'Hesaplar arasında gezinmekten sıkılmadın mı? Tek bir uygulama ile tüm hesaplarını takip et, borçlarını, maaşını ve ek gelirlerini tek hesapta takip et.',
      'enter_your_name': 'Adınız ve Soyadınız',
      'enter_monthly_budget': 'Aylık Harcama Hedefiniz (TL)',
      'start_app_btn': 'Hesabımı Oluştur & Başla',
    },
    'en': {
      'app_name': 'FinScout',
      'tagline': 'Expense Intelligence & Deterministic Finance Engine',
      // Nav
      'nav_home': 'Home',
      'nav_cashflow': 'Wallet',
      'nav_analysis': 'Analytics',
      'nav_goals': 'Goals',
      'nav_assets': 'Assets',
      // Top bar & Profile
      'welcome': 'Welcome,',
      'guest_user': 'User',
      'profile_title': 'Personal Information',
      'profile_edit': 'Edit Profile',
      'profile_name': 'Full Name',
      'profile_email': 'Email / Contact',
      'profile_currency': 'Main Currency',
      'profile_budget_target': 'Monthly Budget Target',
      'profile_joined_date': 'Member Since',
      'app_settings_btn': 'App Settings',
      'switch_account_btn': 'Switch Account',
      'logout_btn': 'Log Out',
      // Dashboard
      'month_total': 'TOTAL',
      'total_expense': 'TOTAL EXPENSES',
      'total_income': 'TOTAL INCOME',
      'net_difference': 'NET DIFF: ',
      'recent_records': 'TRANSACTIONS',
      'record_count': 'Records',
      'no_transactions_title': 'No Transactions Found',
      'no_transactions_subtitle': 'Upload your bank statement or payslip from the top-right button, or add transactions manually.',
      'add_first_transaction': 'Add First Transaction',
      // PDF Upload & Dialog
      'upload_pdf_tooltip': 'Upload Document / Statement',
      'select_doc_type_title': 'Select Document Type',
      'select_doc_type_subtitle': 'Choose the document category for precise categorization:',
      'doc_credit_card': 'Credit Card Statement',
      'doc_credit_card_desc': 'Monthly card statements and breakdowns',
      'doc_payslip': 'Salary Payslip',
      'doc_payslip_desc': 'Net salary, bonuses, and tax deductions',
      'doc_bank_statement': 'Bank Account Statement',
      'doc_bank_statement_desc': 'Checking / savings account activity log',
      'doc_invoice': 'Invoice / Receipt',
      'doc_invoice_desc': 'Utilities, energy, or retail receipts',
      // Notifications
      'notifications_title': 'Notifications & Insights',
      'no_notifications': 'No notifications or insights yet.',
      'mark_all_read': 'Mark All as Read',
      'clear_all': 'Clear All',
      'mark_read': 'Read',
      'delete': 'Delete',
      // Settings
      'settings_title': 'Settings',
      'language_option': 'Language',
      'data_management': 'Data Management',
      'export_excel': 'Export as Excel (.csv)',
      'export_backup': 'Backup System (.json)',
      'restore_backup': 'Restore from Backup',
      'subscription_status': 'Subscription & Google Play',
      'delete_all_data': 'Reset & Delete All Data',
      'delete_data_confirm_title': 'Delete All Data?',
      'delete_data_confirm_msg': 'This will permanently remove all accounts, statements, and profile data from your device. This cannot be undone. Are you sure?',
      'confirm_delete': 'Yes, Delete Everything',
      'cancel': 'Cancel',
      'save': 'Save',
      // Onboarding
      'onboarding_welcome_title': 'Welcome to FinScout',
      'onboarding_welcome_subtitle': 'Tired of switching between bank apps?\nTrack all your cards, debts, salary, and extra income in one place.',
      'marketing_motto': 'Tired of switching between bank apps? Track all your accounts, debts, salary, and extra income in a single app.',
      'enter_your_name': 'Your Full Name',
      'enter_monthly_budget': 'Monthly Budget Target',
      'start_app_btn': 'Create Account & Begin',
    },
  };
}
