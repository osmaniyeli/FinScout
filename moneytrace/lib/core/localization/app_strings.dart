// lib/core/localization/app_strings.dart

import 'package:flutter/material.dart';

class AppStrings {
  static final ValueNotifier<String> currentLocale = ValueNotifier<String>('tr');

  static bool get isTurkish => currentLocale.value == 'tr';

  /// Uygulama tek dilli (Türkçe). Eski profillerde kayıtlı 'en' değeri yok sayılır.
  static void setLocale(String langCode) {
    currentLocale.value = 'tr';
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
      'doc_payslip': 'Maaş bordrosu',
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
      'export_excel': 'Excel Olarak Dışa Aktar (.csv)',
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
  };
}
