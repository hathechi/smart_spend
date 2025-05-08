import 'dart:io';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smart_spend/services/ai_analysis_service.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/services/telegram_service.dart';
import 'package:smart_spend/services/notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final storageService = StorageService();
      final telegramService = TelegramService(
        botToken: dotenv.env['TELEGRAM_BOT_TOKEN'] ?? '',
        chatId: dotenv.env['TELEGRAM_CHAT_ID'] ?? '',
      );
      final aiAnalysisService =
          AIAnalysisService(storageService, telegramService);

      await aiAnalysisService.analyzeAndSendReport();
      return true;
    } catch (e) {
      print('Error in background task: $e');
      return false;
    }
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      await Workmanager().initialize(callbackDispatcher);
    }
  }

  static Future<void> scheduleDailyReport() async {
    if (Platform.isAndroid) {
      await Workmanager().registerPeriodicTask(
        'daily_report',
        'sendDailyReport',
        frequency: const Duration(hours: 24),
        initialDelay: _getInitialDelay(),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
    } else if (Platform.isIOS) {
      await NotificationService().scheduleDailyNotification();
    }
  }

  static Duration _getInitialDelay() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    return nextMidnight.difference(now);
  }
}
