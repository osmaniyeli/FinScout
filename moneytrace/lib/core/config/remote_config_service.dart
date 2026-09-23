// lib/core/config/remote_config_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class RegionalModuleConfig {
  final bool isGloballyEnabled;
  final List<String> disabledCountries; // Örn: ['TR', 'DE']
  final String maintenanceTitle;
  final String maintenanceMessage;

  const RegionalModuleConfig({
    required this.isGloballyEnabled,
    this.disabledCountries = const [],
    this.maintenanceTitle = 'Özellik Bakımda',
    this.maintenanceMessage = 'Bu modülümüz planlı bakım çalışmasındadır.',
  });

  bool isEnabledForCountry(String userCountryCode) {
    if (!isGloballyEnabled) return false;
    final upperCountry = userCountryCode.toUpperCase();
    return !disabledCountries.contains(upperCountry);
  }

  factory RegionalModuleConfig.fromMap(Map<String, dynamic> map) {
    return RegionalModuleConfig(
      isGloballyEnabled: map['enabled'] as bool? ?? true,
      disabledCountries: (map['disabled_countries'] as List<dynamic>?)
              ?.map((e) => e.toString().toUpperCase())
              .toList() ??
          const [],
      maintenanceTitle: map['title'] as String? ?? 'Özellik Bakımda',
      maintenanceMessage: map['message'] as String? ??
          'Bu modülümüz planlı bakım çalışmasındadır.',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': isGloballyEnabled,
      'disabled_countries': disabledCountries,
      'title': maintenanceTitle,
      'message': maintenanceMessage,
    };
  }
}

class ThemeConfig {
  final String primaryColorHex;
  final String incomeColorHex;
  final String expenseColorHex;
  final String themePaletteName;
  final bool isDarkMode;

  const ThemeConfig({
    this.primaryColorHex = '#0052FF',
    this.incomeColorHex = '#00D084',
    this.expenseColorHex = '#FF2D55',
    this.themePaletteName = 'Elektrik Mavisi (Standart)',
    this.isDarkMode = false,
  });

  ThemeConfig copyWith({
    String? primaryColorHex,
    String? incomeColorHex,
    String? expenseColorHex,
    String? themePaletteName,
    bool? isDarkMode,
  }) {
    return ThemeConfig(
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      incomeColorHex: incomeColorHex ?? this.incomeColorHex,
      expenseColorHex: expenseColorHex ?? this.expenseColorHex,
      themePaletteName: themePaletteName ?? this.themePaletteName,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  Map<String, dynamic> toMap() => {
        'primary_hex': primaryColorHex,
        'income_hex': incomeColorHex,
        'expense_hex': expenseColorHex,
        'palette_name': themePaletteName,
        'dark_mode': isDarkMode,
      };

  factory ThemeConfig.fromMap(Map<String, dynamic> map) => ThemeConfig(
        primaryColorHex: map['primary_hex'] as String? ?? '#0052FF',
        incomeColorHex: map['income_hex'] as String? ?? '#00D084',
        expenseColorHex: map['expense_hex'] as String? ?? '#FF2D55',
        themePaletteName:
            map['palette_name'] as String? ?? 'Elektrik Mavisi (Standart)',
        isDarkMode: map['dark_mode'] as bool? ?? false,
      );
}

class MenuConfig {
  final List<String> tabOrder;
  final Map<String, bool> visibleTabs;
  final int defaultTabIndex;

  const MenuConfig({
    this.tabOrder = const ['dashboard', 'cashflow', 'analysis', 'goals', 'assets'],
    this.visibleTabs = const {
      'dashboard': true,
      'cashflow': true,
      'analysis': true,
      'goals': true,
      'assets': true,
    },
    this.defaultTabIndex = 0,
  });

  MenuConfig copyWith({
    List<String>? tabOrder,
    Map<String, bool>? visibleTabs,
    int? defaultTabIndex,
  }) {
    return MenuConfig(
      tabOrder: tabOrder ?? this.tabOrder,
      visibleTabs: visibleTabs ?? this.visibleTabs,
      defaultTabIndex: defaultTabIndex ?? this.defaultTabIndex,
    );
  }

  Map<String, dynamic> toMap() => {
        'tab_order': tabOrder,
        'visible_tabs': visibleTabs,
        'default_tab_index': defaultTabIndex,
      };

  factory MenuConfig.fromMap(Map<String, dynamic> map) => MenuConfig(
        tabOrder: (map['tab_order'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const ['dashboard', 'cashflow', 'analysis', 'goals', 'assets'],
        visibleTabs: (map['visible_tabs'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as bool)) ??
            const {
              'dashboard': true,
              'cashflow': true,
              'analysis': true,
              'goals': true,
              'assets': true,
            },
        defaultTabIndex: map['default_tab_index'] as int? ?? 0,
      );
}

class ButtonConfig {
  final double borderRadius;
  final double elevation;
  final String fabPosition; // 'endFloat', 'centerDocked', 'hidden'
  final bool showQuickActions;

  const ButtonConfig({
    this.borderRadius = 14.0,
    this.elevation = 3.0,
    this.fabPosition = 'endFloat',
    this.showQuickActions = true,
  });

  ButtonConfig copyWith({
    double? borderRadius,
    double? elevation,
    String? fabPosition,
    bool? showQuickActions,
  }) {
    return ButtonConfig(
      borderRadius: borderRadius ?? this.borderRadius,
      elevation: elevation ?? this.elevation,
      fabPosition: fabPosition ?? this.fabPosition,
      showQuickActions: showQuickActions ?? this.showQuickActions,
    );
  }

  Map<String, dynamic> toMap() => {
        'border_radius': borderRadius,
        'elevation': elevation,
        'fab_position': fabPosition,
        'show_quick_actions': showQuickActions,
      };

  factory ButtonConfig.fromMap(Map<String, dynamic> map) => ButtonConfig(
        borderRadius: (map['border_radius'] as num?)?.toDouble() ?? 14.0,
        elevation: (map['elevation'] as num?)?.toDouble() ?? 3.0,
        fabPosition: map['fab_position'] as String? ?? 'endFloat',
        showQuickActions: map['show_quick_actions'] as bool? ?? true,
      );
}

class RemoteConfigService extends ChangeNotifier {
  static final RemoteConfigService instance = RemoteConfigService._internal();
  RemoteConfigService._internal();

  String _currentDeviceCountry = 'TR';
  String? _broadcastAlert;

  ThemeConfig _themeConfig = const ThemeConfig();
  MenuConfig _menuConfig = const MenuConfig();
  ButtonConfig _buttonConfig = const ButtonConfig();
  bool _isCleanDataMode = true; // Test modu için varsayılan olarak açık (0 kullanıcı verisi)
  String _appLanguage = 'tr'; // 'tr': Türkçe, 'en': English

  List<String> _banks = const [
    'Yapı Kredi', 'Garanti BBVA', 'Türkiye İş Bankası', 'Akbank', 'QNB Finansbank', 'Enpara.com', 'Ziraat Bankası', 'VakıfBank'
  ];
  List<Map<String, String>> _vehicleBrandsModels = const [
    {'brand': 'Renault', 'model': 'Clio', 'fuel_type': 'Benzin'},
    {'brand': 'Renault', 'model': 'Megane E-Tech', 'fuel_type': 'Elektrik'},
    {'brand': 'Fiat', 'model': 'Egea', 'fuel_type': 'Dizel'},
    {'brand': 'Fiat', 'model': '500e', 'fuel_type': 'Elektrik'},
    {'brand': 'Volkswagen', 'model': 'Golf', 'fuel_type': 'Benzin'},
    {'brand': 'Volkswagen', 'model': 'ID.4', 'fuel_type': 'Elektrik'},
    {'brand': 'Toyota', 'model': 'Corolla Hybrid', 'fuel_type': 'Hibrit'},
    {'brand': 'Tesla', 'model': 'Model Y', 'fuel_type': 'Elektrik'},
    {'brand': 'Togg', 'model': 'T10X', 'fuel_type': 'Elektrik'},
    {'brand': 'BMW', 'model': 'i4', 'fuel_type': 'Elektrik'},
    {'brand': 'Mercedes-Benz', 'model': 'EQA', 'fuel_type': 'Elektrik'},
  ];
  List<String> _housingTypes = const [
    'Kiracı (Standart Daire)', 'Mülk Sahibi (Daire)', 'Müstakil / Villa (Mülk)', 'Müstakil / Villa (Kira)', 'Lojman'
  ];
  List<String> _paymentMethods = const [
    'Nakit (Elden Nakit)', 'Kredi Kartı', 'Banka Kartı', 'Havale / EFT / FAST'
  ];
  List<String> _expenseCategories = const [
    'Oto Bakım & Sanayi Tamiri', 'Akaryakıt', 'Elektrikli Araç Şarj Bedeli', 'Market & Mutfak', 'Kira & Aidat', 'Faturalar', 'Sağlık', 'Yeme-İçme'
  ];
  List<String> _goalTypes = const [
    'Elektrikli Araç Satın Alma', 'Mevcut Aracı Yenileme', 'Ev Peşinatı Birikimi', 'Acil Durum Fonu', 'Yıllık Tatil Bütçesi'
  ];

  String get currentDeviceCountry => _currentDeviceCountry;
  String? get broadcastAlert => _broadcastAlert;

  ThemeConfig get themeConfig => _themeConfig;
  MenuConfig get menuConfig => _menuConfig;
  ButtonConfig get buttonConfig => _buttonConfig;
  bool get isCleanDataMode => _isCleanDataMode;
  String get appLanguage => _appLanguage;

  List<String> get banks => _banks;
  List<Map<String, String>> get vehicleBrandsModels => _vehicleBrandsModels;
  List<String> get housingTypes => _housingTypes;
  List<String> get paymentMethods => _paymentMethods;
  List<String> get expenseCategories => _expenseCategories;
  List<String> get goalTypes => _goalTypes;

  set currentDeviceCountry(String country) {
    _currentDeviceCountry = country.toUpperCase();
    notifyListeners();
  }


  void setAppLanguage(String lang) {
    _appLanguage = lang.toLowerCase() == 'en' ? 'en' : 'tr';
    notifyListeners();
  }

  void updateThemeConfig(ThemeConfig config) {
    _themeConfig = config;
    notifyListeners();
  }

  void updateMenuConfig(MenuConfig config) {
    _menuConfig = config;
    notifyListeners();
  }

  void updateButtonConfig(ButtonConfig config) {
    _buttonConfig = config;
    notifyListeners();
  }

  void setCleanDataMode(bool isClean) {
    _isCleanDataMode = isClean;
    notifyListeners();
  }

  // 12 MODÜLÜN ÜLKE & BÖLGE MATRİSLİ MERKEZİ ŞALTER LİSTESİ
  final Map<String, RegionalModuleConfig> _moduleConfigs = {
    'dashboard_summary': const RegionalModuleConfig(isGloballyEnabled: true),
    'statement_upload': const RegionalModuleConfig(isGloballyEnabled: true),
    'cashflow_projection': const RegionalModuleConfig(isGloballyEnabled: true),
    'goals_module': const RegionalModuleConfig(isGloballyEnabled: true),
    'assets_portfolio': const RegionalModuleConfig(isGloballyEnabled: true),
    'market_rates': const RegionalModuleConfig(isGloballyEnabled: true),
    'quick_entry': const RegionalModuleConfig(isGloballyEnabled: true),
    'family_budget': const RegionalModuleConfig(isGloballyEnabled: true),
    'tax_analytics': const RegionalModuleConfig(isGloballyEnabled: true),
    'scout_ai_coach': const RegionalModuleConfig(isGloballyEnabled: true),
    'newsletter_subscription': const RegionalModuleConfig(isGloballyEnabled: true),
    'market_news': const RegionalModuleConfig(isGloballyEnabled: true),
  };

  Map<String, RegionalModuleConfig> get allConfigs =>
      Map.unmodifiable(_moduleConfigs);

  bool isModuleActive(String moduleKey, {String? countryCode}) {
    final country = countryCode ?? _currentDeviceCountry;
    final config = _moduleConfigs[moduleKey];
    if (config == null) return true;
    return config.isEnabledForCountry(country);
  }

  String getMaintenanceTitle(String moduleKey) {
    return _moduleConfigs[moduleKey]?.maintenanceTitle ?? 'Özellik Bakımda';
  }

  String getMaintenanceMessage(String moduleKey) {
    return _moduleConfigs[moduleKey]?.maintenanceMessage ??
        'Bu modülümüz bölgenizde geçici bir bakım çalışmasındadır.';
  }

  void setModuleToggle({
    required String moduleKey,
    required bool isEnabled,
    List<String>? disabledCountries,
    String? title,
    String? message,
  }) {
    _moduleConfigs[moduleKey] = RegionalModuleConfig(
      isGloballyEnabled: isEnabled,
      disabledCountries: disabledCountries ??
          _moduleConfigs[moduleKey]?.disabledCountries ??
          const [],
      maintenanceTitle:
          title ?? _moduleConfigs[moduleKey]?.maintenanceTitle ?? 'Özellik Bakımda',
      maintenanceMessage: message ??
          _moduleConfigs[moduleKey]?.maintenanceMessage ??
          'Planlı bakım çalışması.',
    );
    notifyListeners();
  }

  void toggleCountryBlacklist(String moduleKey, String countryCode) {
    final current = _moduleConfigs[moduleKey];
    if (current == null) return;

    final upper = countryCode.toUpperCase();
    final list = List<String>.from(current.disabledCountries);

    if (list.contains(upper)) {
      list.remove(upper);
    } else {
      list.add(upper);
    }

    _moduleConfigs[moduleKey] = RegionalModuleConfig(
      isGloballyEnabled: current.isGloballyEnabled,
      disabledCountries: list,
      maintenanceTitle: current.maintenanceTitle,
      maintenanceMessage: current.maintenanceMessage,
    );
    notifyListeners();
  }

  void applyJsonMap(Map<String, dynamic> data) {
    if (data.containsKey('modules')) {
      final modulesMap = data['modules'] as Map<String, dynamic>;
      modulesMap.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          _moduleConfigs[key] = RegionalModuleConfig.fromMap(val);
        }
      });
    }
    if (data.containsKey('theme')) {
      _themeConfig = ThemeConfig.fromMap(data['theme'] as Map<String, dynamic>);
    }
    if (data.containsKey('menu')) {
      _menuConfig = MenuConfig.fromMap(data['menu'] as Map<String, dynamic>);
    }
    if (data.containsKey('button')) {
      _buttonConfig = ButtonConfig.fromMap(data['button'] as Map<String, dynamic>);
    }
    if (data.containsKey('clean_data_mode')) {
      _isCleanDataMode = data['clean_data_mode'] as bool? ?? true;
    }
    if (data.containsKey('app_language')) {
      _appLanguage = (data['app_language'] as String? ?? 'tr').toLowerCase() == 'en' ? 'en' : 'tr';
    }
    if (data.containsKey('dynamic_lists')) {
      final dynamicLists = data['dynamic_lists'] as Map<String, dynamic>;
      if (dynamicLists['banks'] is List) {
        _banks = List<String>.from(dynamicLists['banks']);
      }
      if (dynamicLists['vehicle_brands_models'] is List) {
        _vehicleBrandsModels = (dynamicLists['vehicle_brands_models'] as List)
            .map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList();
      }
      if (dynamicLists['housing_types'] is List) {
        _housingTypes = List<String>.from(dynamicLists['housing_types']);
      }
      if (dynamicLists['payment_methods'] is List) {
        _paymentMethods = List<String>.from(dynamicLists['payment_methods']);
      }
      if (dynamicLists['expense_categories'] is List) {
        _expenseCategories = List<String>.from(dynamicLists['expense_categories']);
      }
      if (dynamicLists['goal_types'] is List) {
        _goalTypes = List<String>.from(dynamicLists['goal_types']);
      }
    }
    notifyListeners();
  }

  void loadFromJsonString(String jsonStr) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      applyJsonMap(data);
    } catch (e) {
      debugPrint('RemoteConfig JSON ayrıştırma hatası: $e');
    }
  }

  Future<void> loadFromAsset({String assetPath = 'assets/config/remote_config.json'}) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      loadFromJsonString(jsonString);
    } catch (e) {
      debugPrint('RemoteConfig yerel asset okunamadı ($assetPath): $e');
    }
  }

  Future<void> fetchRemoteConfig({String? remoteConfigUrl}) async {
    if (remoteConfigUrl == null || remoteConfigUrl.isEmpty) return;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);

    try {
      final request = await client.getUrl(Uri.parse(remoteConfigUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        loadFromJsonString(body);
      }
    } catch (e) {
      debugPrint('RemoteConfig sunucu bağlantı hatası: $e');
    } finally {
      client.close();
    }
  }
}
