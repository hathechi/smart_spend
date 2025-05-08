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
    return Expense(
      id: json['id'],
      amount: json['amount'].toDouble(),
      description: json['description'],
      purpose: json['purpose'],
      date: DateTime.parse(json['date']),
    );
  }
}
