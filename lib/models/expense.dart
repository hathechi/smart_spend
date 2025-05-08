import 'package:flutter/material.dart';

class Expense {
  final String id;
  final double amount;
  final String description;
  final String purpose;
  final DateTime date;

  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.purpose,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'purpose': purpose,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String? ?? '';
      final amount = (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount'].toString()) ?? 0.0;
      final description = json['description'] as String? ?? '';
      final purpose = json['purpose'] as String? ?? '';
      final dateStr =
          json['date'] as String? ?? DateTime.now().toIso8601String();

      return Expense(
        id: id,
        amount: amount,
        description: description,
        purpose: purpose,
        date: DateTime.tryParse(dateStr) ?? DateTime.now(),
      );
    } catch (e) {
      print('Error parsing Expense from JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}
