import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import 'database_helper.dart';
import 'package:http/http.dart' as http;
import 'package:smart_spend/services/settings_service.dart';

class StorageService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _settingsKey = 'settings';

  // Expense operations
  Future<void> saveExpense(Expense expense) async {
    await _dbHelper.insertExpense(expense);
  }

  Future<List<Expense>> getExpenses() async {
    return await _dbHelper.getExpenses();
  }

  Future<List<Expense>> getExpensesByDateRange(
      DateTime start, DateTime end) async {
    return await _dbHelper.getExpensesByDateRange(start, end);
  }

  Future<void> updateExpense(Expense expense) async {
    await _dbHelper.updateExpense(expense);
  }

  Future<void> deleteExpense(int id) async {
    await _dbHelper.deleteExpense(id);
  }

  Future<void> insertExpenses(List<Expense> expenses) async {
    for (final expense in expenses) {
      await _dbHelper.insertExpense(expense);
    }
  }

  // Settings operations (still using SharedPreferences)
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, settings.toString());
  }

  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsStr = prefs.getString(_settingsKey);
    if (settingsStr == null) return {};
    // Parse settings string to Map
    return {}; // TODO: Implement proper parsing
  }

  // Migration helper
  Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = prefs.getString('expenses');
    if (expensesJson != null) {
      // TODO: Implement migration from JSON to SQLite
      // This will be implemented in the next step
    }
  }

  Future<void> sendExpensesToWebhook(SettingsService settingsService) async {
    final webhookUrl = settingsService.getWebhookUrl();
    if (webhookUrl == null || webhookUrl.isEmpty) {
      throw Exception('Webhook URL is not set');
    }
    final expenses = await getExpenses();
    final data = expenses.map((e) => e.toMap()).toList();
    final response = await http.post(
      Uri.parse(webhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'expenses': data}),
    );

    print(jsonEncode({'expenses': data}));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to send data to webhook: \\n${response.body}');
    }
  }

  Future<void> deleteAllExpenses() async {
    await _dbHelper.deleteAllExpenses();
  }
}
