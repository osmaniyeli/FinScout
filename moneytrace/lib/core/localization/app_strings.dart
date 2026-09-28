// lib/core/localization/app_strings.dart

import 'package:flutter/material.dart';

class AppStrings {
  static final ValueNotifier<String> currentLocale =
      ValueNotifier<String>('tr');

  static bool get isTurkish => currentLocale.value == 'tr';

  /// Ayarlar > Dil'den çağrılır. Yalnız 'tr'/'en' kabul edilir; başka bir değer yok sayılır.
  static void setLocale(String langCode) {
    if (langCode != 'tr' && langCode != 'en') return;
    currentLocale.value = langCode;
  }

  /// Supabase `app_content` tablosundan gelen (ve yerelde önbelleklenen) canlı metin geçersiz
  /// kılmaları. bkz. AppContentService. Sabit kodlu [_localizedValues] her zaman yedek olarak kalır;
  /// bu harita boşsa ya da bir anahtar burada yoksa [get] otomatik olarak sabit sözlüğe düşer.
  static final Map<String, Map<String, String>> _overrides = {
    'tr': <String, String>{},
    'en': <String, String>{},
  };

  /// Supabase satırlarını (veya önbellek dosyasından okunan aynı biçimdeki JSON listesini) uygular.
  /// Her satır `{'key': ..., 'tr': ..., 'en': ...}` biçiminde olmalı; eksik/boş alanlar yok sayılır.
  static void applyOverrides(List<dynamic> rows) {
    for (final row in rows) {
      if (row is! Map) continue;
      final key = row['key']?.toString();
      if (key == null || key.isEmpty) continue;
      final tr = row['tr']?.toString();
      final en = row['en']?.toString();
      if (tr != null && tr.isNotEmpty) _overrides['tr']![key] = tr;
      if (en != null && en.isNotEmpty) _overrides['en']![key] = en;
    }
  }

  /// Yalnız testler için: modüller arası test sızıntısını önlemek üzere geçersiz kılmaları temizler.
  @visibleForTesting
  static void clearOverridesForTest() {
    _overrides['tr']!.clear();
    _overrides['en']!.clear();
  }

  static String get(String key) {
    final lang = currentLocale.value;
    return _overrides[lang]?[key] ??
        _localizedValues[lang]?[key] ??
        _localizedValues['tr']?[key] ??
        key;
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
      'no_transactions_subtitle':
          'Banka ekstrenizi veya maaş bordronuzu sağ üstteki butondan yükleyebilir ya da hızlı işlem ekleyebilirsiniz.',
      'add_first_transaction': 'İlk İşlemini Ekle',
      // PDF Upload & Dialog
      'upload_pdf_tooltip': 'Belge / Ekstre Yükle',
      'select_doc_type_title': 'Ne yükleyeceksin?',
      'select_doc_type_subtitle':
          'Bankanın internet ya da mobil şubesinden indirdiğin PDF',
      'doc_credit_card': 'Yapı Kredi kredi kartı ekstresi',
      'doc_credit_card_desc':
          'Harcamalar, taksitler, faiz ve ücretler, son ödeme tarihi',
      'doc_payslip': 'Maaş bordrosu (deneme)',
      'doc_payslip_desc':
          'Net maaş, gelir vergisi, damga vergisi, SGK kesintileri',
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
      'delete_data_confirm_msg':
          'Bu işlem tüm hesap, harcama ve profil verilerinizi cihazınızdan kalıcı olarak silecektir. Bu işlem geri alınamaz. Devam etmek istiyor musunuz?',
      'confirm_delete': 'Evet, Tümünü Sil',
      'cancel': 'İptal',
      'save': 'Kaydet',
      // Onboarding
      'onboarding_welcome_title': 'FinScout\'a Hoş Geldiniz',
      'onboarding_welcome_subtitle':
          'Hesaplar arasında gezinmekten sıkılmadın mı?\nTek bir uygulama ile tüm hesaplarını takip et, borçlarını, maaşını ve ek gelirlerini tek hesapta yönet.',
      'marketing_motto':
          'Hesaplar arasında gezinmekten sıkılmadın mı? Tek bir uygulama ile tüm hesaplarını takip et, borçlarını, maaşını ve ek gelirlerini tek hesapta takip et.',
      'enter_your_name': 'Adınız ve Soyadınız',
      'enter_monthly_budget': 'Aylık Harcama Hedefiniz (TL)',
      'start_app_btn': 'Hesabımı Oluştur & Başla',
      // Nav — alt gezinme + hızlı ekleme menüsü (main_navigation_scaffold.dart)
      'nav_add_tooltip': 'Ekle',
      'nav_add_menu_dashboard': 'Ne eklemek istersin?',
      'nav_add_menu_cashflow': 'Cüzdana ekle',
      'nav_add_menu_analysis': 'Analiz',
      'nav_add_menu_goals': 'Hedefler',
      'nav_add_menu_assets': 'Varlık ekle',
      // Settings — settings_screen.dart
      'settings_appbar_title': 'Ayarlar & Tercihler',
      'settings_active_plan_label': 'AKTİF PLANINIZ',
      'settings_google_play_assurance': 'Google Play Store Güvencesiyle',
      'settings_manage_plan_btn': 'Planı Değiştir veya Yönet',
      'settings_explore_premium_btn': 'Premium Avantajlarını Keşfet',
      'settings_subscription_privacy_header': 'ABONELİK VE GİZLİLİK',
      'settings_family_title': 'Aile',
      'settings_family_subtitle':
          'Premium hakkını en fazla 4 kişiyle paylaş; veriler paylaşılmaz',
      'settings_manage_sub_title': 'Aboneliği yönet / iptal et',
      'settings_manage_sub_subtitle': 'Google Play abonelik sayfası açılır',
      'settings_privacy_policy_title': 'Gizlilik politikası',
      'settings_privacy_policy_subtitle': 'Hangi verinin nerede tutulduğu',
      'settings_delete_account_title': 'Hesap ve veri silme',
      'settings_delete_account_subtitle':
          'Uygulamadan ya da e-postayla silme yolları',
      'settings_licenses_title': 'Açık kaynak lisansları',
      'settings_licenses_subtitle': 'Uygulamada kullanılan kütüphaneler',
      'settings_language_note':
          'Artık Ana Sayfa, Profil, Bildirimler, Ayarlar, alt gezinme, Kayıt Ol/Giriş Yap ekranları ve belge yükleme bu dile geçer; uygulamanın geri kalanı Türkçe kalır.',
      'settings_bank_header': 'BANKA',
      'settings_connected_bank_label': 'Bağlı Banka',
      'settings_bank_current_prefix': 'Şu an: ',
      'settings_bank_not_selected': 'Henüz seçilmedi',
      'settings_change_btn': 'Değiştir',
      'settings_select_btn': 'Seç',
      'settings_security_header': 'GÜVENLİK',
      'settings_danger_zone_header': 'TEHLİKELİ BÖLGE / VERİLERİ SIFIRLA',
      'settings_reset_all_title': 'Tüm Verilerimi Sıfırla ve Sil',
      'settings_reset_all_subtitle':
          'Hesaplar, ekstreler, harcamalar, hedefler ve profil cihazınızdan tamamen silinir.',
      'settings_reset_all_btn': 'Tüm Verilerimi Sıfırla ve Hesabı Sil',
      // Onboarding — onboarding_screen.dart (Kayıt Ol / Giriş Yap formları)
      'onboarding_toggle_signin_btn': 'GİRİŞ YAP',
      'onboarding_toggle_signup_btn': 'KAYIT OL',
      'onboarding_signin_prompt_title': 'Zaten hesabın var mı?',
      'onboarding_signin_prompt_subtitle':
          'Mevcut cüzdanına ve profiline hemen giriş yap.',
      'onboarding_form_signup_chip': 'KAYIT OL',
      'onboarding_form_signup_chip_subtitle':
          'FinScout ile bütçeni kontrol altına al.',
      'onboarding_signup_prompt_title': 'Yeni misin?',
      'onboarding_signup_prompt_subtitle':
          'Bütçeni akıllıca yönetmek için hemen profilini oluştur.',
      'onboarding_form_signin_chip': 'GİRİŞ YAP',
      'onboarding_form_signin_chip_subtitle':
          'Kayıtlı cüzdanına ve kartlarına dön.',
      'onboarding_signup_form_title': 'Hesap Bilgilerinizi Belirleyin',
      'onboarding_signup_form_subtitle':
          'Ekstrelerini yükledikçe bankaların ve kartların otomatik tanınır.',
      'onboarding_name_field_label': 'Adınız veya Kullanıcı Adınız *',
      'onboarding_name_hint': 'Örn: Ahmet Yılmaz',
      'onboarding_email_field_label': 'E-posta Adresin *',
      'onboarding_email_hint': 'ornek@eposta.com',
      'onboarding_send_code_btn': 'Doğrulama Kodu Gönder',
      'onboarding_signin_title': 'E-posta ile Giriş',
      'onboarding_signin_subtitle':
          'Hesabının e-postasını gir; giriş kodunu gönderelim.',
      'onboarding_send_signin_code_btn': 'Giriş Kodu Gönder',
      'onboarding_no_account_btn': 'Hesabın yok mu? Kayıt ol',
      'onboarding_google_btn': 'Google ile Devam Et',
      'onboarding_or_email_divider': 'veya e-posta ile',
      'onboarding_code_step_title': 'E-postanı Kontrol Et',
      'onboarding_code_instructions':
          'adresine gönderilen kodu gir. Gelen kutunda yoksa spam klasörüne bak.',
      'onboarding_verify_btn': 'Doğrula ve Devam Et',
      'onboarding_change_email_btn': 'E-postayı değiştir',
      'onboarding_resend_code_btn': 'Kodu tekrar gönder',
      // Statement upload — statement_upload_sheet.dart
      'upload_sheet_title': 'Ekstre / Bordro Yükle',
      'upload_sheet_subtitle':
          'Ekstre bu telefonda okunur, sunucuya gönderilmez',
      'upload_privacy_badge': 'Gizlilik Korumalı',
      'upload_doc_type_label': 'Yüklenecek belge türü:',
      'upload_chip_credit_card': 'Yapı Kredi Kart',
      'upload_chip_payslip': 'Maaş Bordrosu (deneme)',
      'upload_batch_progress_suffix': 'belge okunuyor',
      'upload_processing_single':
          'Belge okunuyor, kişisel bilgiler maskeleniyor…',
      'upload_pick_different_btn': 'Farklı Belge Seç',
      'upload_view_plans_btn': 'Planları Gör',
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
      'no_transactions_subtitle':
          'You can upload your bank statement or payslip using the button at the top right, or add a quick transaction.',
      'add_first_transaction': 'Add Your First Transaction',
      // PDF Upload & Dialog
      'upload_pdf_tooltip': 'Upload Document / Statement',
      'select_doc_type_title': 'What would you like to upload?',
      'select_doc_type_subtitle':
          "The PDF you downloaded from your bank's website or mobile app",
      'doc_credit_card': 'Yapı Kredi credit card statement',
      'doc_credit_card_desc':
          'Purchases, installments, interest and fees, due date',
      'doc_payslip': 'Payslip (beta)',
      'doc_payslip_desc':
          'Net salary, income tax, stamp duty, social security deductions',
      'doc_bank_statement': 'Yapı Kredi checking account statement',
      'doc_bank_statement_desc':
          'Coming soon: reader is being built from a sample statement',
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
      'delete_data_confirm_msg':
          'This will permanently delete all your account, expense and profile data from your device. This action cannot be undone. Do you want to continue?',
      'confirm_delete': 'Yes, Delete All',
      'cancel': 'Cancel',
      'save': 'Save',
      // Onboarding
      'onboarding_welcome_title': 'Welcome to FinScout',
      'onboarding_welcome_subtitle':
          'Tired of switching between accounts?\nTrack everything in one app — manage your debts, salary and extra income in a single place.',
      'marketing_motto':
          'Tired of switching between accounts? Track everything in one app — manage your debts, salary and extra income in a single place.',
      'enter_your_name': 'Your Full Name',
      'enter_monthly_budget': 'Your Monthly Spending Target (TL)',
      'start_app_btn': 'Create My Account & Start',
      // Nav
      'nav_add_tooltip': 'Add',
      'nav_add_menu_dashboard': 'What would you like to add?',
      'nav_add_menu_cashflow': 'Add to wallet',
      'nav_add_menu_analysis': 'Analysis',
      'nav_add_menu_goals': 'Goals',
      'nav_add_menu_assets': 'Add asset',
      // Settings
      'settings_appbar_title': 'Settings & Preferences',
      'settings_active_plan_label': 'YOUR CURRENT PLAN',
      'settings_google_play_assurance': 'Backed by Google Play Store',
      'settings_manage_plan_btn': 'Change or Manage Plan',
      'settings_explore_premium_btn': 'Explore Premium Benefits',
      'settings_subscription_privacy_header': 'SUBSCRIPTION AND PRIVACY',
      'settings_family_title': 'Family',
      'settings_family_subtitle':
          'Share your Premium with up to 4 people; data is never shared',
      'settings_manage_sub_title': 'Manage / cancel subscription',
      'settings_manage_sub_subtitle': 'Opens the Google Play subscription page',
      'settings_privacy_policy_title': 'Privacy policy',
      'settings_privacy_policy_subtitle': 'What data is kept and where',
      'settings_delete_account_title': 'Delete account and data',
      'settings_delete_account_subtitle':
          'Ways to delete from the app or by email',
      'settings_licenses_title': 'Open-source licenses',
      'settings_licenses_subtitle': 'Libraries used in the app',
      'settings_language_note':
          'Home, Profile, Notifications, Settings, bottom navigation, the Sign Up/Sign In screens and document upload now switch language; the rest of the app stays in Turkish.',
      'settings_bank_header': 'BANK',
      'settings_connected_bank_label': 'Connected Bank',
      'settings_bank_current_prefix': 'Currently: ',
      'settings_bank_not_selected': 'Not selected yet',
      'settings_change_btn': 'Change',
      'settings_select_btn': 'Select',
      'settings_security_header': 'SECURITY',
      'settings_danger_zone_header': 'DANGER ZONE / RESET DATA',
      'settings_reset_all_title': 'Reset and Delete All My Data',
      'settings_reset_all_subtitle':
          'Accounts, statements, expenses, goals and profile will be permanently deleted from your device.',
      'settings_reset_all_btn': 'Reset All My Data and Delete Account',
      // Onboarding
      'onboarding_toggle_signin_btn': 'SIGN IN',
      'onboarding_toggle_signup_btn': 'SIGN UP',
      'onboarding_signin_prompt_title': 'Already have an account?',
      'onboarding_signin_prompt_subtitle':
          'Sign in to your existing wallet and profile right away.',
      'onboarding_form_signup_chip': 'SIGN UP',
      'onboarding_form_signup_chip_subtitle':
          'Take control of your budget with FinScout.',
      'onboarding_signup_prompt_title': 'New here?',
      'onboarding_signup_prompt_subtitle':
          'Create your profile now to manage your budget smartly.',
      'onboarding_form_signin_chip': 'SIGN IN',
      'onboarding_form_signin_chip_subtitle':
          'Return to your saved wallet and cards.',
      'onboarding_signup_form_title': 'Set Up Your Account',
      'onboarding_signup_form_subtitle':
          'As you upload statements, your banks and cards are recognized automatically.',
      'onboarding_name_field_label': 'Your Name or Username *',
      'onboarding_name_hint': 'e.g. John Smith',
      'onboarding_email_field_label': 'Your Email Address *',
      'onboarding_email_hint': 'example@email.com',
      'onboarding_send_code_btn': 'Send Verification Code',
      'onboarding_signin_title': 'Sign In with Email',
      'onboarding_signin_subtitle':
          "Enter your account's email; we'll send you a sign-in code.",
      'onboarding_send_signin_code_btn': 'Send Sign-In Code',
      'onboarding_no_account_btn': "Don't have an account? Sign up",
      'onboarding_google_btn': 'Continue with Google',
      'onboarding_or_email_divider': 'or with email',
      'onboarding_code_step_title': 'Check Your Email',
      'onboarding_code_instructions':
          "Enter the code sent to that address. Check your spam folder if it's not in your inbox.",
      'onboarding_verify_btn': 'Verify and Continue',
      'onboarding_change_email_btn': 'Change email',
      'onboarding_resend_code_btn': 'Resend code',
      // Statement upload
      'upload_sheet_title': 'Upload Statement / Payslip',
      'upload_sheet_subtitle':
          'Statement is read on this phone, never sent to a server',
      'upload_privacy_badge': 'Privacy Protected',
      'upload_doc_type_label': 'Document type to upload:',
      'upload_chip_credit_card': 'Yapı Kredi Card',
      'upload_chip_payslip': 'Payslip (beta)',
      'upload_batch_progress_suffix': 'documents being read',
      'upload_processing_single':
          'Reading document, personal info is being masked…',
      'upload_pick_different_btn': 'Choose Different Document',
      'upload_view_plans_btn': 'View Plans',
    },
  };
}
