import 'dart:async';
import 'package:smart_spend/services/ai_analysis_service.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      _runAnalysis();
      // Lên lịch chạy lại mỗi 24 giờ
      _timer = Timer.periodic(const Duration(hours: 24), (_) {
        _runAnalysis();
      });
    });
  }

  Future<void> _runAnalysis() async {
    await _aiAnalysisService.analyzeAndSendReport();
    try {
      await _storageService.sendExpensesToWebhook(_settingsService);
    } catch (e) {
      print('Error sending expenses to webhook: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
