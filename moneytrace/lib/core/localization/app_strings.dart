// lib/core/localization/app_strings.dart

import 'package:flutter/material.dart';

class AppStrings {
  static final ValueNotifier<String> currentLocale = ValueNotifier<String>('tr');

  static bool get isTurkish => currentLocale.value == 'tr';

  /// Ayarlar > Dil'den çağrılır. Yalnız 'tr'/'en' kabul edilir; başka bir değer yok sayılır.
  static void setLocale(String langCode) {
    if (langCode != 'tr' && langCode != 'en') return;
    currentLocale.value = langCode;
  }

  static String get(String key) {
    final lang = currentLocale.value;
    return _localizedValues[lang]?[key] ?? _localizedValues['tr']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'tr': {
      'app_name': 'FinScout',
      'tagline': 'Ekstreni yükle, masraflarını kalem kalem gör',
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
      'select_doc_type_title': 'Ne yükleyeceksin?',
      'select_doc_type_subtitle': 'Bankanın internet ya da mobil şubesinden indirdiğin PDF',
      'doc_credit_card': 'Yapı Kredi kredi kartı ekstresi',
      'doc_credit_card_desc': 'Harcamalar, taksitler, faiz ve ücretler, son ödeme tarihi',
      'doc_payslip': 'Maaş bordrosu (deneme)',
      'doc_payslip_desc': 'Net maaş, gelir vergisi, damga vergisi, SGK kesintileri',
      'doc_bank_statement': 'Yapı Kredi vadesiz hesap dökümü',
      'doc_bank_statement_desc': 'Yakında: okuyucu örnek dökümle hazırlanıyor',
      'doc_other_banks': 'Diğer bankalar',
      'doc_other_banks_desc': 'Yakında; bankalar tek tek ekleniyor',
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
      'tagline': 'Upload your statement, see your expenses itemized',
      // Nav
      'nav_home': 'Home',
      'nav_cashflow': 'Wallet',
      'nav_analysis': 'Analysis',
      'nav_goals': 'Goals',
      'nav_assets': 'Assets',
      // Top bar & Profile
      'welcome': 'Welcome,',
      'guest_user': 'User',
      'profile_title': 'Personal Information',
      'profile_edit': 'Edit Profile',
      'profile_name': 'Full Name',
      'profile_email': 'Email / Contact',
      'profile_currency': 'Primary Currency',
      'profile_budget_target': 'Monthly Budget Target',
      'profile_joined_date': 'Join Date',
      'app_settings_btn': 'App Settings',
      'switch_account_btn': 'Switch Account',
      'logout_btn': 'Sign Out',
      // Dashboard
      'month_total': 'MONTH TOTAL',
      'total_expense': 'TOTAL EXPENSE',
      'total_income': 'TOTAL INCOME',
      'net_difference': 'NET DIFFERENCE: ',
      'recent_records': 'RECORDS',
      'record_count': 'Records',
      'no_transactions_title': 'No Transactions Yet',
      'no_transactions_subtitle': 'You can upload your bank statement or payslip using the button at the top right, or add a quick transaction.',
      'add_first_transaction': 'Add Your First Transaction',
      // PDF Upload & Dialog
      'upload_pdf_tooltip': 'Upload Document / Statement',
      'select_doc_type_title': 'What would you like to upload?',
      'select_doc_type_subtitle': "The PDF you downloaded from your bank's website or mobile app",
      'doc_credit_card': 'Yapı Kredi credit card statement',
      'doc_credit_card_desc': 'Purchases, installments, interest and fees, due date',
      'doc_payslip': 'Payslip (beta)',
      'doc_payslip_desc': 'Net salary, income tax, stamp duty, social security deductions',
      'doc_bank_statement': 'Yapı Kredi checking account statement',
      'doc_bank_statement_desc': 'Coming soon: reader is being built from a sample statement',
      'doc_other_banks': 'Other banks',
      'doc_other_banks_desc': 'Coming soon; banks are being added one by one',
      // Notifications
      'notifications_title': 'Notifications and Tips',
      'no_notifications': 'No notifications or tips yet.',
      'mark_all_read': 'Mark All as Read',
      'clear_all': 'Clear All',
      'mark_read': 'Read',
      'delete': 'Delete',
      // Settings
      'settings_title': 'Settings',
      'language_option': 'Language',
      'data_management': 'Data Management',
      'subscription_status': 'Subscription and Google Play',
      'delete_all_data': 'Reset and Delete All My Data',
      'delete_data_confirm_title': 'Delete All Your Data?',
      'delete_data_confirm_msg': 'This will permanently delete all your account, expense and profile data from your device. This action cannot be undone. Do you want to continue?',
      'confirm_delete': 'Yes, Delete All',
      'cancel': 'Cancel',
      'save': 'Save',
      // Onboarding
      'onboarding_welcome_title': 'Welcome to FinScout',
      'onboarding_welcome_subtitle': 'Tired of switching between accounts?\nTrack everything in one app — manage your debts, salary and extra income in a single place.',
      'marketing_motto': 'Tired of switching between accounts? Track everything in one app — manage your debts, salary and extra income in a single place.',
      'enter_your_name': 'Your Full Name',
      'enter_monthly_budget': 'Your Monthly Spending Target (TL)',
      'start_app_btn': 'Create My Account & Start',
    },
  };
}
