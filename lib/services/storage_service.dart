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

      print('Debug: Loading expenses - $expensesJson');
      final List<dynamic> decoded = jsonDecode(expensesJson);
      return decoded.map((json) => Expense.fromJson(json)).toList();
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
