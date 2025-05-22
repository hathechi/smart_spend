import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smart_spend/models/expense.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/services/telegram_service.dart';
import 'package:intl/intl.dart';
import 'package:smart_spend/services/settings_service.dart';

class AIAnalysisService {
  final StorageService _storageService;
  final TelegramService _telegramService;
  final SettingsService _settingsService;
  final GenerativeModel _model;
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  AIAnalysisService(
    this._storageService,
    this._telegramService,
    this._settingsService,
  ) : _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: _settingsService.getOpenAiApiKey() ??
              dotenv.env['GEMINI_API_KEY'] ??
              '',
        );

  String _sanitizeText(String text) {
    return text.replaceAll(RegExp(r'[^\w\s]'), '');
  }

  Future<void> analyzeAndSendReport() async {
    try {
      final expenses = await _storageService.getExpenses();
      if (expenses.isEmpty) {
        await _telegramService
            .sendMessage('📊 Không có dữ liệu chi tiêu để phân tích');
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thisMonth = DateTime(now.year, now.month);

      // Lọc chi tiêu hôm nay
      final todayExpenses = expenses.where((e) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        return d == today;
      }).toList();

      // Lọc chi tiêu tháng này
      final monthExpenses = expenses.where((e) {
        return e.date.year == now.year && e.date.month == now.month;
      }).toList();

      // Làm sạch dữ liệu chi tiêu hôm nay
      final sanitizedTodayExpenses = todayExpenses.isNotEmpty
          ? todayExpenses
              .map((e) =>
                  '💰 ${_currencyFormat.format(e.amount)} cho ${_sanitizeText(e.purpose)} vào ${DateFormat('HH:mm').format(e.date)}')
              .join('\n')
          : 'Không có chi tiêu nào trong ngày.';

      // Làm sạch dữ liệu chi tiêu tháng này
      final sanitizedMonthExpenses = monthExpenses.isNotEmpty
          ? monthExpenses
              .map((e) =>
                  '💰 ${_currencyFormat.format(e.amount)} cho ${_sanitizeText(e.purpose)} vào ${DateFormat('dd/MM').format(e.date)}')
              .join('\n')
          : 'Không có chi tiêu nào trong tháng.';

      final prompt = '''
Hey bạn! Đây là báo cáo chi tiêu cuối ngày của bạn. Hãy phân tích thật ngắn gọn, vui vẻ và dùng emoji nhé! 😊

---

📅 Báo cáo chi tiêu NGÀY ${DateFormat('dd/MM/yyyy').format(today)}:
$sanitizedTodayExpenses

Hãy cho mình biết:
1. 💰 Tổng chi tiêu hôm nay và khoản chi lớn nhất hôm nay
2. 🎯 Danh mục chi nhiều nhất hôm nay
3. 💡 Một gợi ý tiết kiệm đơn giản cho ngày hôm nay

---

📆 Báo cáo TỔNG KẾT THÁNG ${DateFormat('MM/yyyy').format(thisMonth)} (tính đến hết hôm nay):
$sanitizedMonthExpenses

Hãy cho mình biết:
1. 💰 Tổng chi tiêu tháng này
2. 💰 Khoản chi lớn nhất tháng
3. 🎯 Danh mục chi nhiều nhất tháng
4. 📈 So sánh chi tiêu hôm nay với trung bình ngày trong tháng
5. 💡 Một gợi ý tiết kiệm cho tháng này

Trả lời ngắn gọn, vui vẻ và sử dụng emoji nhé! Không cần phân tích quá chi tiết đâu 😉
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final analysis = response.text;

      if (analysis != null) {
        // Gửi nguyên văn kết quả phân tích từ AI, không sanitize để giữ dấu tiếng Việt, emoji, định dạng
        final formattedMessage = '''
📊 <b>Báo cáo chi tiêu cuối ngày</b>

$analysis

⏰ <i>Giờ gửi: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}</i>
''';

        await _telegramService.sendMessage(formattedMessage, parseMode: 'HTML');
      }
    } catch (e) {
      print('Error in AI analysis: $e');
      await _telegramService.sendMessage(
          '❌ Oops! Có chút trục trặc khi phân tích chi tiêu của bạn: $e');
    }
  }

  Future<String> generateReminderMessage(String prompt) async {
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "Đừng quên ghi chú chi tiêu nhé!";
    } catch (e) {
      print('Error in AI reminder: $e');
      return "Đừng quên ghi chú chi tiêu nhé!";
    }
  }
}
