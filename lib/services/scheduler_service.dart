import 'dart:async';
import 'package:smart_spend/services/ai_analysis_service.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_spend/services/notification_service.dart';

class SchedulerService {
  final AIAnalysisService _aiAnalysisService;
  final StorageService _storageService = StorageService();
  late final SettingsService _settingsService;
  Timer? _timer;

  SchedulerService(this._aiAnalysisService, SharedPreferences prefs) {
    _settingsService = SettingsService(prefs);
  }

  void startScheduler() {
    // Tính thời gian đến 12h đêm tiếp theo
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = nextMidnight.difference(now);

    // Lên lịch chạy báo cáo
    _timer = Timer(timeUntilMidnight, () {
      print('SchedulerService: Gửi báo cáo AI tự động (lúc 12h đêm)');
      _runAnalysis();
      // Lên lịch chạy lại mỗi 24 giờ
      _timer = Timer.periodic(const Duration(hours: 24), (_) {
        print('SchedulerService: Gửi báo cáo AI tự động (định kỳ 24h)');
        _runAnalysis();
      });
    });
  }

  Future<void> _runAnalysis() async {
    try {
      print('SchedulerService: Bắt đầu gửi báo cáo AI...');
      await _aiAnalysisService.analyzeAndSendReport();
      print('SchedulerService: Gửi báo cáo AI thành công!');
      await NotificationService().showNotification(
        title: 'Báo cáo AI',
        body: 'Gửi báo cáo AI thành công!',
      );
    } catch (e) {
      print('SchedulerService: Lỗi khi gửi báo cáo AI: $e');
      await NotificationService().showNotification(
        title: 'Báo cáo AI',
        body: 'Lỗi gửi báo cáo AI: $e',
      );
    }
    try {
      print('SchedulerService: Bắt đầu gửi webhook...');
      await _storageService.sendExpensesToWebhook(_settingsService);
      print('SchedulerService: Gửi webhook thành công!');
      await NotificationService().showNotification(
        title: 'Webhook',
        body: 'Gửi webhook thành công!',
      );
    } catch (e) {
      print('SchedulerService: Lỗi khi gửi webhook: $e');
      await NotificationService().showNotification(
        title: 'Webhook',
        body: 'Lỗi gửi webhook: $e',
      );
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
