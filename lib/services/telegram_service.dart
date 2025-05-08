import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smart_spend/models/expense.dart';

class TelegramService {
  final String _botToken;
  final String _chatId;
  final String _baseUrl;

  TelegramService({
    required String botToken,
    required String chatId,
  })  : _botToken = botToken,
        _chatId = chatId,
        _baseUrl = 'https://api.telegram.org/bot$botToken';

  Future<void> sendDailyReport(List<Expense> expenses) async {
    final total = expenses.fold(0.0, (sum, expense) => sum + expense.amount);

    final message = '''
📊 Báo cáo chi tiêu ngày ${DateTime.now().toString().split(' ')[0]}

💰 Tổng chi tiêu: ${total.toStringAsFixed(0)}đ

📝 Chi tiết:
${expenses.map((e) => '- ${e.description}: ${e.amount.toStringAsFixed(0)}đ').join('\n')}
''';

    await sendMessage(message);
  }

  Future<void> sendMessage(String message,
      {String parseMode = 'Markdown'}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sendMessage'),
        body: {
          'chat_id': _chatId,
          'text': message,
          'parse_mode': parseMode,
        },
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception('Failed to send message: ${error['description']}');
      }
    } catch (e) {
      print('Error sending Telegram message: $e');
      rethrow;
    }
  }
}
