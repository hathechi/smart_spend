import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _useSystemThemeKey = 'useSystemTheme';
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _languageKey = 'language';
  static const String _telegramChatIdKey = 'telegram_chat_id';
  static const String _telegramBotTokenKey = 'telegram_bot_token';
  static const String _openAiApiKeyKey = 'openai_api_key';
  static const String _webhookUrlKey = 'webhook_url';

  late final SharedPreferences _prefs;
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

  SettingsService(this._prefs);

  Future<void> _loadSettings() async {
    _useSystemTheme = _prefs.getBool(_useSystemThemeKey) ?? true;
    _isDarkMode = _prefs.getBool(_isDarkModeKey) ?? false;
    _language = _prefs.getString(_languageKey) ?? 'vi';
    notifyListeners();
  }

  Future<void> initialize() async {
    _useSystemTheme = _prefs.getBool(_useSystemThemeKey) ?? true;
    _isDarkMode = _prefs.getBool(_isDarkModeKey) ?? false;
    _language = _prefs.getString(_languageKey) ?? 'vi';
    notifyListeners();
  }

  // Telegram Configuration
  Future<void> setTelegramConfig({
    required String chatId,
    required String botToken,
  }) async {
    await _prefs.setString(_telegramChatIdKey, chatId);
    await _prefs.setString(_telegramBotTokenKey, botToken);
  }

  String? getTelegramChatId() => _prefs.getString(_telegramChatIdKey);
  String? getTelegramBotToken() => _prefs.getString(_telegramBotTokenKey);

  // OpenAI API Key
  Future<void> setOpenAiApiKey(String apiKey) async {
    await _prefs.setString(_openAiApiKeyKey, apiKey);
  }

  String? getOpenAiApiKey() => _prefs.getString(_openAiApiKeyKey);

  // Webhook URL
  Future<void> setWebhookUrl(String url) async {
    await _prefs.setString(_webhookUrlKey, url);
  }

  String? getWebhookUrl() => _prefs.getString(_webhookUrlKey);

  // Clear all settings
  Future<void> clearAllSettings() async {
    await _prefs.remove(_telegramChatIdKey);
    await _prefs.remove(_telegramBotTokenKey);
    await _prefs.remove(_openAiApiKeyKey);
  }
}
