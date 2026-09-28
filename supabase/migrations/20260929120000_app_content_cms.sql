-- supabase/migrations/20260929120000_app_content_cms.sql
--
-- Canli icerik/metin sistemi (CMS) temeli: uygulama ici tum kullanici metinleri
-- (nav etiketleri, ayarlar basliklari, onboarding formlari, yukleme sheet'i vb.)
-- artik yonetim panelinden duzenlenebilir. Uygulama once bu tabloyu (arka planda, bir
-- kerelik) ceker ve yerelde onbellekler; tablo bos ya da erisilemezse sabit kodlu
-- TR/EN sozluge (lib/core/localization/app_strings.dart) duser.
--
-- RLS: anon dahil herkes SELECT yapabilir (UI metni, hassas veri degil; giris
-- oncesi de okunabilmeli). INSERT/UPDATE/DELETE hicbir role (anon/authenticated) acik
-- degil; yalniz service_role (RLS'i bypass eder) yazabilir -- panel bunu dogrudan
-- degil, supabase/functions/admin-update-content Edge Function'i uzerinden yapar.

create table public.app_content (
  key text primary key,
  tr text not null,
  en text not null,
  category text,
  updated_at timestamptz not null default now()
);

alter table public.app_content enable row level security;

create policy "app_content public read" on public.app_content
  for select to anon, authenticated
  using (true);

-- service_role RLS'i bypass eder (Supabase varsayilani); anon/authenticated icin
-- INSERT/UPDATE/DELETE policy'si yok = varsayilan olarak reddedilir. Tablo yetkilerini
-- de ayni ilkeyle daraltiyoruz (profiles_column_grants.sql ile ayni desen).
revoke all on public.app_content from anon, authenticated;
grant select on public.app_content to anon, authenticated;

-- Uygulamadaki mevcut sabit kodlu TR/EN sozlugun (app_strings.dart) tam bir kopyasi:
-- CMS'in ilk yayina cikisi kod ile 1:1 ayni metinle baslasin diye. Panelden duzenlenince
-- yalniz bu tablo degisir; app_strings.dart sozlugu her zaman yedek olarak kod icinde kalir.
insert into public.app_content (key, tr, en, category) values
  ('add_first_transaction', 'İlk İşlemini Ekle', 'Add Your First Transaction', 'dashboard'),
  ('app_name', 'FinScout', 'FinScout', 'general'),
  ('app_settings_btn', 'Uygulama Ayarları', 'App Settings', 'general'),
  ('cancel', 'İptal', 'Cancel', 'general'),
  ('clear_all', 'Tümünü Temizle', 'Clear All', 'notifications'),
  ('confirm_delete', 'Evet, Tümünü Sil', 'Yes, Delete All', 'settings'),
  ('data_management', 'Veri Yönetimi', 'Data Management', 'settings'),
  ('delete', 'Sil', 'Delete', 'notifications'),
  ('delete_all_data', 'Tüm Verilerimi Sıfırla ve Sil', 'Reset and Delete All My Data', 'settings'),
  ('delete_data_confirm_msg', 'Bu işlem tüm hesap, harcama ve profil verilerinizi cihazınızdan kalıcı olarak silecektir. Bu işlem geri alınamaz. Devam etmek istiyor musunuz?', 'This will permanently delete all your account, expense and profile data from your device. This action cannot be undone. Do you want to continue?', 'settings'),
  ('delete_data_confirm_title', 'Tüm Verileriniz Silinsin mi?', 'Delete All Your Data?', 'settings'),
  ('doc_bank_statement', 'Yapı Kredi vadesiz hesap dökümü', 'Yapı Kredi checking account statement', 'upload'),
  ('doc_bank_statement_desc', 'Yakında: okuyucu örnek dökümle hazırlanıyor', 'Coming soon: reader is being built from a sample statement', 'upload'),
  ('doc_credit_card', 'Yapı Kredi kredi kartı ekstresi', 'Yapı Kredi credit card statement', 'upload'),
  ('doc_credit_card_desc', 'Harcamalar, taksitler, faiz ve ücretler, son ödeme tarihi', 'Purchases, installments, interest and fees, due date', 'upload'),
  ('doc_other_banks', 'Diğer bankalar', 'Other banks', 'upload'),
  ('doc_other_banks_desc', 'Yakında; bankalar tek tek ekleniyor', 'Coming soon; banks are being added one by one', 'upload'),
  ('doc_payslip', 'Maaş bordrosu (deneme)', 'Payslip (beta)', 'upload'),
  ('doc_payslip_desc', 'Net maaş, gelir vergisi, damga vergisi, SGK kesintileri', 'Net salary, income tax, stamp duty, social security deductions', 'upload'),
  ('enter_monthly_budget', 'Aylık Harcama Hedefiniz (TL)', 'Your Monthly Spending Target (TL)', 'general'),
  ('enter_your_name', 'Adınız ve Soyadınız', 'Your Full Name', 'general'),
  ('guest_user', 'Kullanıcı', 'User', 'dashboard'),
  ('language_option', 'Dil Seçeneği', 'Language', 'settings'),
  ('logout_btn', 'Hesaptan Çıkış Yap', 'Sign Out', 'general'),
  ('mark_all_read', 'Tümünü Okundu Say', 'Mark All as Read', 'notifications'),
  ('mark_read', 'Okundu', 'Read', 'notifications'),
  ('marketing_motto', 'Hesaplar arasında gezinmekten sıkılmadın mı? Tek bir uygulama ile tüm hesaplarını takip et, borçlarını, maaşını ve ek gelirlerini tek hesapta takip et.', 'Tired of switching between accounts? Track everything in one app — manage your debts, salary and extra income in a single place.', 'general'),
  ('month_total', 'AYI TOPLAMI', 'MONTH TOTAL', 'dashboard'),
  ('nav_add_menu_analysis', 'Analiz', 'Analysis', 'nav'),
  ('nav_add_menu_assets', 'Varlık ekle', 'Add asset', 'nav'),
  ('nav_add_menu_cashflow', 'Cüzdana ekle', 'Add to wallet', 'nav'),
  ('nav_add_menu_dashboard', 'Ne eklemek istersin?', 'What would you like to add?', 'nav'),
  ('nav_add_menu_goals', 'Hedefler', 'Goals', 'nav'),
  ('nav_add_tooltip', 'Ekle', 'Add', 'nav'),
  ('nav_analysis', 'Analiz', 'Analysis', 'nav'),
  ('nav_assets', 'Varlıklar', 'Assets', 'nav'),
  ('nav_cashflow', 'Cüzdan', 'Wallet', 'nav'),
  ('nav_goals', 'Hedefler', 'Goals', 'nav'),
  ('nav_home', 'Ana Sayfa', 'Home', 'nav'),
  ('net_difference', 'NET FARK: ', 'NET DIFFERENCE: ', 'dashboard'),
  ('no_notifications', 'Henüz bir bildirim veya tavsiye bulunmuyor.', 'No notifications or tips yet.', 'notifications'),
  ('no_transactions_subtitle', 'Banka ekstrenizi veya maaş bordronuzu sağ üstteki butondan yükleyebilir ya da hızlı işlem ekleyebilirsiniz.', 'You can upload your bank statement or payslip using the button at the top right, or add a quick transaction.', 'dashboard'),
  ('no_transactions_title', 'Henüz İşlem Kaydı Bulunmuyor', 'No Transactions Yet', 'dashboard'),
  ('notifications_title', 'Bildirimler ve Tavsiyeler', 'Notifications and Tips', 'notifications'),
  ('onboarding_change_email_btn', 'E-postayı değiştir', 'Change email', 'onboarding'),
  ('onboarding_code_instructions', 'adresine gönderilen kodu gir. Gelen kutunda yoksa spam klasörüne bak.', 'Enter the code sent to that address. Check your spam folder if it''s not in your inbox.', 'onboarding'),
  ('onboarding_code_step_title', 'E-postanı Kontrol Et', 'Check Your Email', 'onboarding'),
  ('onboarding_email_field_label', 'E-posta Adresin *', 'Your Email Address *', 'onboarding'),
  ('onboarding_email_hint', 'ornek@eposta.com', 'example@email.com', 'onboarding'),
  ('onboarding_form_signin_chip', 'GİRİŞ YAP', 'SIGN IN', 'onboarding'),
  ('onboarding_form_signin_chip_subtitle', 'Kayıtlı cüzdanına ve kartlarına dön.', 'Return to your saved wallet and cards.', 'onboarding'),
  ('onboarding_form_signup_chip', 'KAYIT OL', 'SIGN UP', 'onboarding'),
  ('onboarding_form_signup_chip_subtitle', 'FinScout ile bütçeni kontrol altına al.', 'Take control of your budget with FinScout.', 'onboarding'),
  ('onboarding_google_btn', 'Google ile Devam Et', 'Continue with Google', 'onboarding'),
  ('onboarding_name_field_label', 'Adınız veya Kullanıcı Adınız *', 'Your Name or Username *', 'onboarding'),
  ('onboarding_name_hint', 'Örn: Ahmet Yılmaz', 'e.g. John Smith', 'onboarding'),
  ('onboarding_no_account_btn', 'Hesabın yok mu? Kayıt ol', 'Don''t have an account? Sign up', 'onboarding'),
  ('onboarding_or_email_divider', 'veya e-posta ile', 'or with email', 'onboarding'),
  ('onboarding_resend_code_btn', 'Kodu tekrar gönder', 'Resend code', 'onboarding'),
  ('onboarding_send_code_btn', 'Doğrulama Kodu Gönder', 'Send Verification Code', 'onboarding'),
  ('onboarding_send_signin_code_btn', 'Giriş Kodu Gönder', 'Send Sign-In Code', 'onboarding'),
  ('onboarding_signin_prompt_subtitle', 'Mevcut cüzdanına ve profiline hemen giriş yap.', 'Sign in to your existing wallet and profile right away.', 'onboarding'),
  ('onboarding_signin_prompt_title', 'Zaten hesabın var mı?', 'Already have an account?', 'onboarding'),
  ('onboarding_signin_subtitle', 'Hesabının e-postasını gir; giriş kodunu gönderelim.', 'Enter your account''s email; we''ll send you a sign-in code.', 'onboarding'),
  ('onboarding_signin_title', 'E-posta ile Giriş', 'Sign In with Email', 'onboarding'),
  ('onboarding_signup_form_subtitle', 'Ekstrelerini yükledikçe bankaların ve kartların otomatik tanınır.', 'As you upload statements, your banks and cards are recognized automatically.', 'onboarding'),
  ('onboarding_signup_form_title', 'Hesap Bilgilerinizi Belirleyin', 'Set Up Your Account', 'onboarding'),
  ('onboarding_signup_prompt_subtitle', 'Bütçeni akıllıca yönetmek için hemen profilini oluştur.', 'Create your profile now to manage your budget smartly.', 'onboarding'),
  ('onboarding_signup_prompt_title', 'Yeni misin?', 'New here?', 'onboarding'),
  ('onboarding_toggle_signin_btn', 'GİRİŞ YAP', 'SIGN IN', 'onboarding'),
  ('onboarding_toggle_signup_btn', 'KAYIT OL', 'SIGN UP', 'onboarding'),
  ('onboarding_verify_btn', 'Doğrula ve Devam Et', 'Verify and Continue', 'onboarding'),
  ('onboarding_welcome_subtitle', 'Hesaplar arasında gezinmekten sıkılmadın mı?
Tek bir uygulama ile tüm hesaplarını takip et, borçlarını, maaşını ve ek gelirlerini tek hesapta yönet.', 'Tired of switching between accounts?
Track everything in one app — manage your debts, salary and extra income in a single place.', 'onboarding'),
  ('onboarding_welcome_title', 'FinScout''a Hoş Geldiniz', 'Welcome to FinScout', 'onboarding'),
  ('profile_budget_target', 'Aylık Bütçe Hedefi', 'Monthly Budget Target', 'profile'),
  ('profile_currency', 'Ana Para Birimi', 'Primary Currency', 'profile'),
  ('profile_edit', 'Profili Düzenle', 'Edit Profile', 'profile'),
  ('profile_email', 'E-posta / İletişim', 'Email / Contact', 'profile'),
  ('profile_joined_date', 'Kayıt Tarihi', 'Join Date', 'profile'),
  ('profile_name', 'Ad Soyad', 'Full Name', 'profile'),
  ('profile_title', 'Kişisel Bilgiler', 'Personal Information', 'profile'),
  ('recent_records', 'KAYITLAR', 'RECORDS', 'dashboard'),
  ('record_count', 'Kayıt', 'Records', 'dashboard'),
  ('save', 'Kaydet', 'Save', 'general'),
  ('select_doc_type_subtitle', 'Bankanın internet ya da mobil şubesinden indirdiğin PDF', 'The PDF you downloaded from your bank''s website or mobile app', 'upload'),
  ('select_doc_type_title', 'Ne yükleyeceksin?', 'What would you like to upload?', 'upload'),
  ('settings_active_plan_label', 'AKTİF PLANINIZ', 'YOUR CURRENT PLAN', 'settings'),
  ('settings_appbar_title', 'Ayarlar & Tercihler', 'Settings & Preferences', 'settings'),
  ('settings_bank_current_prefix', 'Şu an: ', 'Currently: ', 'settings'),
  ('settings_bank_header', 'BANKA', 'BANK', 'settings'),
  ('settings_bank_not_selected', 'Henüz seçilmedi', 'Not selected yet', 'settings'),
  ('settings_change_btn', 'Değiştir', 'Change', 'settings'),
  ('settings_connected_bank_label', 'Bağlı Banka', 'Connected Bank', 'settings'),
  ('settings_danger_zone_header', 'TEHLİKELİ BÖLGE / VERİLERİ SIFIRLA', 'DANGER ZONE / RESET DATA', 'settings'),
  ('settings_delete_account_subtitle', 'Uygulamadan ya da e-postayla silme yolları', 'Ways to delete from the app or by email', 'settings'),
  ('settings_delete_account_title', 'Hesap ve veri silme', 'Delete account and data', 'settings'),
  ('settings_explore_premium_btn', 'Premium Avantajlarını Keşfet', 'Explore Premium Benefits', 'settings'),
  ('settings_family_subtitle', 'Premium hakkını en fazla 4 kişiyle paylaş; veriler paylaşılmaz', 'Share your Premium with up to 4 people; data is never shared', 'settings'),
  ('settings_family_title', 'Aile', 'Family', 'settings'),
  ('settings_google_play_assurance', 'Google Play Store Güvencesiyle', 'Backed by Google Play Store', 'settings'),
  ('settings_language_note', 'Artık Ana Sayfa, Profil, Bildirimler, Ayarlar, alt gezinme, Kayıt Ol/Giriş Yap ekranları ve belge yükleme bu dile geçer; uygulamanın geri kalanı Türkçe kalır.', 'Home, Profile, Notifications, Settings, bottom navigation, the Sign Up/Sign In screens and document upload now switch language; the rest of the app stays in Turkish.', 'settings'),
  ('settings_licenses_subtitle', 'Uygulamada kullanılan kütüphaneler', 'Libraries used in the app', 'settings'),
  ('settings_licenses_title', 'Açık kaynak lisansları', 'Open-source licenses', 'settings'),
  ('settings_manage_plan_btn', 'Planı Değiştir veya Yönet', 'Change or Manage Plan', 'settings'),
  ('settings_manage_sub_subtitle', 'Google Play abonelik sayfası açılır', 'Opens the Google Play subscription page', 'settings'),
  ('settings_manage_sub_title', 'Aboneliği yönet / iptal et', 'Manage / cancel subscription', 'settings'),
  ('settings_privacy_policy_subtitle', 'Hangi verinin nerede tutulduğu', 'What data is kept and where', 'settings'),
  ('settings_privacy_policy_title', 'Gizlilik politikası', 'Privacy policy', 'settings'),
  ('settings_reset_all_btn', 'Tüm Verilerimi Sıfırla ve Hesabı Sil', 'Reset All My Data and Delete Account', 'settings'),
  ('settings_reset_all_subtitle', 'Hesaplar, ekstreler, harcamalar, hedefler ve profil cihazınızdan tamamen silinir.', 'Accounts, statements, expenses, goals and profile will be permanently deleted from your device.', 'settings'),
  ('settings_reset_all_title', 'Tüm Verilerimi Sıfırla ve Sil', 'Reset and Delete All My Data', 'settings'),
  ('settings_security_header', 'GÜVENLİK', 'SECURITY', 'settings'),
  ('settings_select_btn', 'Seç', 'Select', 'settings'),
  ('settings_subscription_privacy_header', 'ABONELİK VE GİZLİLİK', 'SUBSCRIPTION AND PRIVACY', 'settings'),
  ('settings_title', 'Ayarlar', 'Settings', 'settings'),
  ('start_app_btn', 'Hesabımı Oluştur & Başla', 'Create My Account & Start', 'general'),
  ('subscription_status', 'Abonelik ve Google Play', 'Subscription and Google Play', 'settings'),
  ('switch_account_btn', 'Hesap Değiştir', 'Switch Account', 'general'),
  ('tagline', 'Ekstreni yükle, masraflarını kalem kalem gör', 'Upload your statement, see your expenses itemized', 'general'),
  ('total_expense', 'TOPLAM GİDER', 'TOTAL EXPENSE', 'dashboard'),
  ('total_income', 'TOPLAM GELİR', 'TOTAL INCOME', 'dashboard'),
  ('upload_batch_progress_suffix', 'belge okunuyor', 'documents being read', 'upload'),
  ('upload_chip_credit_card', 'Yapı Kredi Kart', 'Yapı Kredi Card', 'upload'),
  ('upload_chip_payslip', 'Maaş Bordrosu (deneme)', 'Payslip (beta)', 'upload'),
  ('upload_doc_type_label', 'Yüklenecek belge türü:', 'Document type to upload:', 'upload'),
  ('upload_pdf_tooltip', 'Belge / Ekstre Yükle', 'Upload Document / Statement', 'upload'),
  ('upload_pick_different_btn', 'Farklı Belge Seç', 'Choose Different Document', 'upload'),
  ('upload_privacy_badge', 'Gizlilik Korumalı', 'Privacy Protected', 'upload'),
  ('upload_processing_single', 'Belge okunuyor, kişisel bilgiler maskeleniyor…', 'Reading document, personal info is being masked…', 'upload'),
  ('upload_sheet_subtitle', 'Ekstre bu telefonda okunur, sunucuya gönderilmez', 'Statement is read on this phone, never sent to a server', 'upload'),
  ('upload_sheet_title', 'Ekstre / Bordro Yükle', 'Upload Statement / Payslip', 'upload'),
  ('upload_view_plans_btn', 'Planları Gör', 'View Plans', 'upload'),
  ('welcome', 'Hoş Geldin,', 'Welcome,', 'dashboard');
