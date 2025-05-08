import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smart_spend/models/expense.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/services/telegram_service.dart';
import 'package:intl/intl.dart';

class AIAnalysisService {
  final StorageService _storageService;
  final TelegramService _telegramService;
  final GenerativeModel _model;
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  AIAnalysisService(this._storageService, this._telegramService)
      : _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        );

  String _sanitizeText(String text) {
    // Chỉ loại bỏ các ký tự có thể gây lỗi, giữ lại emoji và các ký tự an toàn
    return text
        .replaceAll('*', '')
        .replaceAll('_', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('`', '')
        .replaceAll('~', '')
        .replaceAll('>', '')
        .replaceAll('<', '')
        .replaceAll('&', 'và')
        .replaceAll('#', '')
        .replaceAll('+', '')
        .replaceAll('=', '')
        .replaceAll('|', '')
        .replaceAll('{', '')
        .replaceAll('}', '');
  }

  Future<void> analyzeAndSendReport() async {
    try {
      final expenses = await _storageService.getExpenses();
      if (expenses.isEmpty) {
        await _telegramService
            .sendMessage('📊 Không có dữ liệu chi tiêu để phân tích');
        return;
      }

      // Làm sạch dữ liệu chi tiêu
      final sanitizedExpenses = expenses
          .map((e) =>
              '💰 ${_currencyFormat.format(e.amount)} cho ${_sanitizeText(e.purpose)} vào ${DateFormat('dd/MM/yyyy').format(e.date)}')
          .join('\n');

      final prompt = '''
Hey bạn! Mình sẽ phân tích chi tiêu của bạn một cách ngắn gọn và vui vẻ nhé! 😊

$sanitizedExpenses

Hãy cho mình biết:
1. 💰 Tổng chi tiêu và khoản chi lớn nhất
2. 🎯 Danh mục chi nhiều nhất
3. 💡 Một gợi ý tiết kiệm đơn giản

Trả lời ngắn gọn, vui vẻ và sử dụng emoji nhé! Không cần phân tích quá chi tiết đâu 😉
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final analysis = response.text;

      if (analysis != null) {
        // Làm sạch kết quả phân tích trước khi gửi
        final sanitizedAnalysis = _sanitizeText(analysis);

        final formattedMessage = '''
📊 <b>Báo cáo chi tiêu thân thiện</b>

$sanitizedAnalysis

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
