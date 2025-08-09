import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _unitsKey = 'units';
  static const String _languageKey = 'language';
  static const String _defaultLatKey = 'default_lat';
  static const String _defaultLonKey = 'default_lon';
  static const String _defaultNameKey = 'default_name';
  static const String _alertWindKey = 'alert_wind';
  static const String _alertPrecipKey = 'alert_precip';
  static const String _notificationsKey = 'notifications';
  static const String _cacheEnabledKey = 'cache_enabled';
  static const String _cacheExpiryKey = 'cache_expiry';

  // Units
  static const String unitsMetric = 'metric';
  static const String unitsImperial = 'imperial';

  // Languages
  static const String languageEnglish = 'en';
  static const String languageRussian = 'ru';
  static const String languageAuto = 'auto';

  // Default values
  static const String defaultUnits = unitsMetric;
  static const String defaultLanguage = languageAuto;
  static const double defaultLat = 59.93;
  static const double defaultLon = 30.31;
  static const String defaultName = 'Saint Petersburg';
  static const double defaultAlertWind = 10.0;
  static const double defaultAlertPrecip = 1.0;
  static const bool defaultNotifications = true;
  static const bool defaultCacheEnabled = true;
  static const int defaultCacheExpiry = 30; // minutes

  late SharedPreferences _prefs;

  // Singleton pattern
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Units
  String get units => _prefs.getString(_unitsKey) ?? defaultUnits;
  Future<void> setUnits(String units) async {
    await _prefs.setString(_unitsKey, units);
  }

  // Language
  String get language => _prefs.getString(_languageKey) ?? defaultLanguage;
  Future<void> setLanguage(String language) async {
    await _prefs.setString(_languageKey, language);
  }

  // Default location
  double get defaultLatitude => _prefs.getDouble(_defaultLatKey) ?? defaultLat;
  double get defaultLongitude => _prefs.getDouble(_defaultLonKey) ?? defaultLon;
  String get defaultLocationName => _prefs.getString(_defaultNameKey) ?? defaultName;

  Future<void> setDefaultLocation(double lat, double lon, String name) async {
    await _prefs.setDouble(_defaultLatKey, lat);
    await _prefs.setDouble(_defaultLonKey, lon);
    await _prefs.setString(_defaultNameKey, name);
  }

  // Alert thresholds
  double get alertWindThreshold => _prefs.getDouble(_alertWindKey) ?? defaultAlertWind;
  double get alertPrecipThreshold => _prefs.getDouble(_alertPrecipKey) ?? defaultAlertPrecip;

  Future<void> setAlertThresholds(double wind, double precip) async {
    await _prefs.setDouble(_alertWindKey, wind);
    await _prefs.setDouble(_alertPrecipKey, precip);
  }

  // Notifications
  bool get notificationsEnabled => _prefs.getBool(_notificationsKey) ?? defaultNotifications;
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_notificationsKey, enabled);
  }

  // Cache settings
  bool get cacheEnabled => _prefs.getBool(_cacheEnabledKey) ?? defaultCacheEnabled;
  int get cacheExpiryMinutes => _prefs.getInt(_cacheExpiryKey) ?? defaultCacheExpiry;

  Future<void> setCacheSettings(bool enabled, int expiryMinutes) async {
    await _prefs.setBool(_cacheEnabledKey, enabled);
    await _prefs.setInt(_cacheExpiryKey, expiryMinutes);
  }

  // Utility methods
  String getTemperatureUnit() {
    return units == unitsMetric ? '°C' : '°F';
  }

  String getWindSpeedUnit() {
    return units == unitsMetric ? 'm/s' : 'mph';
  }

  String getPrecipitationUnit() {
    return units == unitsMetric ? 'mm' : 'in';
  }

  String getPressureUnit() {
    return units == unitsMetric ? 'hPa' : 'inHg';
  }

  // Clear all settings
  Future<void> clearAll() async {
    await _prefs.clear();
  }

  // Export settings as Map
  Map<String, dynamic> exportSettings() {
    return {
      'units': units,
      'language': language,
      'default_location': {
        'lat': defaultLatitude,
        'lon': defaultLongitude,
        'name': defaultLocationName,
      },
      'alert_thresholds': {
        'wind': alertWindThreshold,
        'precip': alertPrecipThreshold,
      },
      'notifications': notificationsEnabled,
      'cache': {
        'enabled': cacheEnabled,
        'expiry_minutes': cacheExpiryMinutes,
      },
    };
  }

  // Import settings from Map
  Future<void> importSettings(Map<String, dynamic> settings) async {
    if (settings['units'] != null) await setUnits(settings['units']);
    if (settings['language'] != null) await setLanguage(settings['language']);
    
    if (settings['default_location'] != null) {
      final location = settings['default_location'] as Map<String, dynamic>;
      await setDefaultLocation(
        location['lat'] ?? defaultLat,
        location['lon'] ?? defaultLon,
        location['name'] ?? defaultName,
      );
    }
    
    if (settings['alert_thresholds'] != null) {
      final thresholds = settings['alert_thresholds'] as Map<String, dynamic>;
      await setAlertThresholds(
        thresholds['wind'] ?? defaultAlertWind,
        thresholds['precip'] ?? defaultAlertPrecip,
      );
    }
    
    if (settings['notifications'] != null) {
      await setNotificationsEnabled(settings['notifications']);
    }
    
    if (settings['cache'] != null) {
      final cache = settings['cache'] as Map<String, dynamic>;
      await setCacheSettings(
        cache['enabled'] ?? defaultCacheEnabled,
        cache['expiry_minutes'] ?? defaultCacheExpiry,
      );
    }
  }
}

