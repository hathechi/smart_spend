import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderConfig {
  final List<TimeOfDay> times;
  final DateTime startDate;
  final bool enabled;
  final int? intervalHours;

  ReminderConfig({
    required this.times,
    required this.startDate,
    required this.enabled,
    this.intervalHours,
  });

  Map<String, dynamic> toJson() => {
        'times':
            times.map((t) => {'hour': t.hour, 'minute': t.minute}).toList(),
        'startDate': startDate.toIso8601String(),
        'enabled': enabled,
        'intervalHours': intervalHours,
      };

  factory ReminderConfig.fromJson(Map<String, dynamic> json) => ReminderConfig(
        times: (json['times'] as List)
            .map((t) => TimeOfDay(hour: t['hour'], minute: t['minute']))
            .toList(),
        startDate: DateTime.parse(json['startDate']),
        enabled: json['enabled'] ?? true,
        intervalHours: json['intervalHours'],
      );
}

class ReminderService {
  static const _key = 'reminder_config';

  Future<void> saveConfig(ReminderConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }

  Future<ReminderConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return null;
    return ReminderConfig.fromJson(jsonDecode(data));
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
