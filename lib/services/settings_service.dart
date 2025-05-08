import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _useSystemThemeKey = 'useSystemTheme';
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _languageKey = 'language';

  late SharedPreferences _prefs;
  bool _useSystemTheme = true;
  bool _isDarkMode = false;
  String _language = 'vi';

  bool get useSystemTheme => _useSystemTheme;
  bool get isDarkMode => _isDarkMode;
  String get language => _language;

  set useSystemTheme(bool value) {
    _useSystemTheme = value;
    _prefs.setBool(_useSystemThemeKey, value);
    notifyListeners();
  }

  set isDarkMode(bool value) {
    _isDarkMode = value;
    _prefs.setBool(_isDarkModeKey, value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    await _prefs.setString(_languageKey, value);
    notifyListeners();
  }

  ThemeMode get themeMode {
    if (_useSystemTheme) return ThemeMode.system;
    return _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _useSystemTheme = _prefs.getBool(_useSystemThemeKey) ?? true;
    _isDarkMode = _prefs.getBool(_isDarkModeKey) ?? false;
    _language = _prefs.getString(_languageKey) ?? 'vi';
    notifyListeners();
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _useSystemTheme = _prefs.getBool(_useSystemThemeKey) ?? true;
    _isDarkMode = _prefs.getBool(_isDarkModeKey) ?? false;
    _language = _prefs.getString(_languageKey) ?? 'vi';
    notifyListeners();
  }
}
