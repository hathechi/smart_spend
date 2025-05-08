import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_spend/models/expense.dart';

class StorageService {
  static const String _expensesKey = 'expenses';

  Future<void> saveExpense(Expense expense) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenses = await getExpenses();
      expenses.add(expense);

      final expensesJson = expenses.map((e) => e.toJson()).toList();
      print('Debug: Saving expenses - ${jsonEncode(expensesJson)}');

      final success =
          await prefs.setString(_expensesKey, jsonEncode(expensesJson));
      if (!success) {
        throw Exception('Failed to save expenses to SharedPreferences');
      }
      print('Debug: Expenses saved successfully');
    } catch (e) {
      print('Debug: Error in saveExpense - $e');
      rethrow;
    }
  }

  Future<List<Expense>> getExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expensesJson = prefs.getString(_expensesKey);

      if (expensesJson == null) {
        print('Debug: No expenses found in storage');
        return [];
      }

      print('Debug: Raw expenses data - $expensesJson');

      dynamic decoded;
      try {
        decoded = jsonDecode(expensesJson);
        print('Debug: Decoded JSON type - ${decoded.runtimeType}');
      } catch (e) {
        print('Debug: Error decoding JSON - $e');
        return [];
      }

      if (decoded is! List) {
        print(
            'Debug: Invalid data format - expected List but got ${decoded.runtimeType}');
        return [];
      }

      final List<Expense> expenses = [];
      for (var item in decoded) {
        try {
          if (item is! Map<String, dynamic>) {
            print('Debug: Invalid expense item type - ${item.runtimeType}');
            print('Debug: Invalid expense item - $item');
            continue;
          }
          final expense = Expense.fromJson(item);
          expenses.add(expense);
        } catch (e) {
          print('Debug: Error parsing expense item - $e');
          print('Debug: Problematic item - $item');
          continue;
        }
      }

      print('Debug: Successfully loaded ${expenses.length} expenses');
      return expenses;
    } catch (e) {
      print('Debug: Error in getExpenses - $e');
      return [];
    }
  }

  Future<List<Expense>> getExpensesByDate(DateTime date) async {
    final expenses = await getExpenses();
    return expenses.where((expense) {
      return expense.date.year == date.year &&
          expense.date.month == date.month &&
          expense.date.day == date.day;
    }).toList();
  }

  Future<void> deleteExpense(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenses = await getExpenses();
      expenses.removeWhere((expense) => expense.id == id);

      final expensesJson = expenses.map((e) => e.toJson()).toList();
      final success =
          await prefs.setString(_expensesKey, jsonEncode(expensesJson));
      if (!success) {
        throw Exception('Failed to delete expense from SharedPreferences');
      }
    } catch (e) {
      print('Debug: Error in deleteExpense - $e');
      rethrow;
    }
  }
}
