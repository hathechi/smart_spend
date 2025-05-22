import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smart_spend/models/expense.dart';
import 'package:smart_spend/services/settings_service.dart';

class TelegramService {
  final SettingsService _settingsService;
  String? _botToken;
  String? _chatId;

  TelegramService(this._settingsService) {
    _loadConfig();
  }

  void _loadConfig() {
    _botToken = _settingsService.getTelegramBotToken() ??
        dotenv.env['TELEGRAM_BOT_TOKEN'];
    _chatId =
        _settingsService.getTelegramChatId() ?? dotenv.env['TELEGRAM_CHAT_ID'];
  }

  Future<bool> testConnection() async {
    if (_botToken == null || _chatId == null) {
      return false;
    }

    try {
      final url = Uri.parse('https://api.telegram.org/bot$_botToken/getMe');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['ok'] == true) {
          // Test gửi tin nhắn
          final testMessage =
              '🔔 Test kết nối thành công!\nBot: ${data['result']['username']}';
          await sendMessage(testMessage);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error testing Telegram connection: $e');
      return false;
    }
  }

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

  Future<void> sendMessage(String message, {String? parseMode}) async {
    if (_botToken == null || _chatId == null) {
      print('Telegram configuration not found');
      return;
    }

    final url = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');
    try {
      final body = {
        'chat_id': _chatId,
        'text': message,
      };

      if (parseMode != null) {
        body['parse_mode'] = parseMode;
      }

      final response = await http.post(url, body: body);

      if (response.statusCode != 200) {
        print('Failed to send Telegram message: ${response.body}');
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      print('Error sending Telegram message: $e');
      throw Exception('Error sending message: $e');
    }
  }
}
