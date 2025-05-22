import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Expense {
  final int? id;
  final double amount;
  final String purpose;
  final String? description;
  final DateTime date;
  final DateTime createdAt;

  Expense({
    this.id,
    required this.amount,
    required this.purpose,
    this.description,
    required this.date,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'purpose': purpose,
      'description': description,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: map['amount'] as double,
      purpose: map['purpose'] as String,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Expense copyWith({
    int? id,
    double? amount,
    String? purpose,
    String? description,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      purpose: purpose ?? this.purpose,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
