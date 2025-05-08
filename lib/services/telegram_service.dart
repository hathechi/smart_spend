import 'package:http/http.dart' as http;
import 'package:smart_spend/models/expense.dart';

class TelegramService {
  final String botToken;
  final String chatId;

  TelegramService({
    required this.botToken,
    required this.chatId,
  });

  Future<void> sendDailyReport(List<Expense> expenses) async {
    final total = expenses.fold(0.0, (sum, expense) => sum + expense.amount);

    final message = '''
📊 Báo cáo chi tiêu ngày ${DateTime.now().toString().split(' ')[0]}

💰 Tổng chi tiêu: ${total.toStringAsFixed(0)}đ

📝 Chi tiết:
${expenses.map((e) => '- ${e.description}: ${e.amount.toStringAsFixed(0)}đ').join('\n')}
''';

    final url = 'https://api.telegram.org/bot$botToken/sendMessage';
    final response = await http.post(
      Uri.parse(url),
      body: {
        'chat_id': chatId,
        'text': message,
        'parse_mode': 'HTML',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send Telegram message: ${response.body}');
    }
  }
}
