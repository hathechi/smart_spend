import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import 'database_helper.dart';

class MigrationService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _expensesKey = 'expenses';

  Future<void> migrateExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expensesJson = prefs.getString(_expensesKey);

      if (expensesJson == null) {
        print('No expenses to migrate');
        return;
      }

      final List<dynamic> decoded = jsonDecode(expensesJson);
      int migratedCount = 0;

      for (var item in decoded) {
        try {
          if (item is! Map<String, dynamic>) continue;

          // Convert old expense format to new format
          final expense = Expense(
            amount: (item['amount'] is num)
                ? (item['amount'] as num).toDouble()
                : double.tryParse(item['amount'].toString()) ?? 0.0,
            purpose: item['purpose'] as String? ?? '',
            description: item['description'] as String?,
            date: DateTime.tryParse(item['date'] as String? ?? '') ??
                DateTime.now(),
          );

          await _dbHelper.insertExpense(expense);
          migratedCount++;
        } catch (e) {
          print('Error migrating expense: $e');
          continue;
        }
      }

      print('Successfully migrated $migratedCount expenses');

      // Clear old data after successful migration
      await prefs.remove(_expensesKey);
    } catch (e) {
      print('Error during migration: $e');
      rethrow;
    }
  }
}
