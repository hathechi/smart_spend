import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:smart_spend/services/reminder_service.dart';
import 'package:smart_spend/services/ai_analysis_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReminderNotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final ReminderService _reminderService = ReminderService();
  final AIAnalysisService _aiService;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

  ReminderNotificationService(this._aiService) {
    // Khởi tạo timezone cho Việt Nam (GMT+7)
    tz_data.initializeTimeZones();
    final vietnam = tz.getLocation('Asia/Ho_Chi_Minh');
    tz.setLocalLocation(vietnam);
  }

  Future<void> scheduleAllReminders() async {
    print('Reminder: Starting to schedule all reminders...');
    final config = await _reminderService.loadConfig();
    await _notifications.cancelAll();

    if (config == null || !config.enabled) {
      print('Reminder: Config is null or disabled');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    print('Reminder: Current time: ${_dateFormat.format(now)}');
    print('Reminder: Start date: ${_dateFormat.format(config.startDate)}');

    if (config.startDate.isAfter(now)) {
      print('Reminder: Start date is in the future, skipping scheduling');
      return;
    }

    if (config.intervalHours != null && config.intervalHours! > 0) {
      print(
          'Reminder: Scheduling interval reminders every ${config.intervalHours} hours');
      await scheduleIntervalReminder(config.intervalHours!);
    } else {
      print(
          'Reminder: Scheduling fixed time reminders: ${config.times.map((t) => '${t.hour}:${t.minute}').join(', ')}');
      for (int i = 0; i < config.times.length; i++) {
        final time = config.times[i];
        print(
            'Reminder: Scheduling fixed time reminder at ${time.hour}:${time.minute}');
        await _scheduleReminder(i, time, useMatchDateTimeComponents: false);
      }
    }
  }

  Future<void> scheduleIntervalReminder(int intervalHours) async {
    final now = tz.TZDateTime.now(tz.local);
    print('Reminder: Current timezone time: ${_dateFormat.format(now)}');

    // Tính toán thời gian bắt đầu (00:00 của ngày hôm sau nếu đã qua 21:00)
    var startDate = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    if (now.hour >= 21) {
      startDate = startDate.add(const Duration(days: 1));
      print(
          'Reminder: Scheduling for next day starting at ${_dateFormat.format(startDate)}');
    }

    for (int i = 0; i < 24; i += intervalHours) {
      final scheduled = tz.TZDateTime(
          tz.local, startDate.year, startDate.month, startDate.day, i, 0);
      print('Reminder: Checking interval time $i:00');

      if (scheduled.isAfter(now)) {
        print(
            'Reminder: Scheduling interval notification for ${_dateFormat.format(scheduled)}');
        try {
          await _notifications.zonedSchedule(
            2000 + i,
            'Nhắc nhở chi tiêu',
            await _getAiMessage(TimeOfDay(hour: i, minute: 0)),
            scheduled,
            const NotificationDetails(
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
              android: AndroidNotificationDetails(
                'reminder_channel',
                'Reminders',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            androidAllowWhileIdle: true,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
          print(
              'Reminder: Successfully scheduled interval notification for ${_dateFormat.format(scheduled)} (ID: ${2000 + i})');
        } catch (e) {
          print('Reminder: Error scheduling interval notification: $e');
        }
      } else {
        print('Reminder: Skipping past interval time $i:00');
      }
    }

    // In ra danh sách các notification đã lên lịch
    final pendingNotifications =
        await _notifications.pendingNotificationRequests();
    print(
        'Reminder: Total pending notifications: ${pendingNotifications.length}');
    for (var notification in pendingNotifications) {
      print(
          'Reminder: Pending notification - ID: ${notification.id}, Title: ${notification.title}');
    }
  }

  Future<void> _scheduleReminder(int id, TimeOfDay time,
      {bool useMatchDateTimeComponents = false}) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);

    print(
        'Reminder: Calculating next instance for ${time.hour}:${time.minute}');
    print(
        'Reminder: Initial scheduled date: ${_dateFormat.format(scheduledDate)}');

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      print(
          'Reminder: Adjusted to next day: ${_dateFormat.format(scheduledDate)}');
    }

    print(
        'Reminder: Scheduling fixed time reminder for ${_dateFormat.format(scheduledDate)}');

    try {
      // Lấy danh sách các notification đã được lên lịch
      final pendingNotifications =
          await _notifications.pendingNotificationRequests();
      print(
          'Reminder: Current pending notifications: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        print(
            'Reminder: Pending notification - ID: ${notification.id}, Title: ${notification.title}');
      }

      await _notifications.zonedSchedule(
        id,
        'Nhắc nhở chi tiêu',
        await _getAiMessage(time),
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents:
            useMatchDateTimeComponents ? DateTimeComponents.time : null,
      );
      print(
          'Reminder: Successfully scheduled fixed time reminder for ${_dateFormat.format(scheduledDate)}');

      // Kiểm tra lại sau khi lên lịch
      final updatedPendingNotifications =
          await _notifications.pendingNotificationRequests();
      print(
          'Reminder: Updated pending notifications: ${updatedPendingNotifications.length}');
      for (var notification in updatedPendingNotifications) {
        print(
            'Reminder: Pending notification - ID: ${notification.id}, Title: ${notification.title}');
      }
    } catch (e) {
      print('Reminder: Error scheduling reminder: $e');
    }
  }

  Future<String> _getAiMessage(TimeOfDay time) async {
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final prompt = '''
Hãy tạo một thông báo nhắc nhở ghi chú chi tiêu ngắn gọn và vui vẻ cho khung giờ $timeStr.
Yêu cầu:
- Ngắn gọn (tối đa 2 câu)
- Vui vẻ, hài hước
- Sử dụng emoji
- Không quá trang trọng
- Không cần giải thích dài dòng

Ví dụ:
"Hey! Đã đến giờ ghi chú chi tiêu rồi nè! 💰 Đừng để tiền bay mất nhé! 😉"
''';
    print('Reminder: Generating AI message for time $timeStr');
    return await _aiService.generateReminderMessage(prompt);
  }

  Future<void> testScheduleReminder(TimeOfDay time) async {
    print('Reminder: Testing reminder for time ${time.hour}:${time.minute}');
    await _scheduleReminder(999, time, useMatchDateTimeComponents: false);
  }

  Future<void> testScheduleReminderNow() async {
    final now = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    print(
        'Reminder: Scheduling test notification for ${_dateFormat.format(now)}');

    try {
      await _notifications.zonedSchedule(
        1000,
        'Test Notification',
        'Đây là thông báo test',
        now,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('Reminder: Successfully scheduled test notification');
    } catch (e) {
      print('Reminder: Error scheduling test notification: $e');
    }
  }

  // Thêm hàm test mới để đặt reminder trong 1 phút
  Future<void> testScheduleReminderInOneMinute() async {
    final now = tz.TZDateTime.now(tz.local);
    final oneMinuteLater = now.add(const Duration(minutes: 1));
    print(
        'Reminder: Scheduling reminder for 1 minute later: ${_dateFormat.format(oneMinuteLater)}');

    try {
      await _notifications.zonedSchedule(
        1001,
        'Nhắc nhở chi tiêu',
        'Đây là thông báo test trong 1 phút',
        oneMinuteLater,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('Reminder: Successfully scheduled reminder for 1 minute later');
    } catch (e) {
      print('Reminder: Error scheduling reminder: $e');
    }
  }
}
