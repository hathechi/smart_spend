import 'package:flutter/material.dart';
import 'package:smart_spend/models/expense.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/services/telegram_service.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smart_spend/screens/settings_page.dart';
import 'package:provider/provider.dart';
import 'package:smart_spend/services/settings_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smart_spend/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final _amountController = MoneyMaskedTextController(
    decimalSeparator: '',
    precision: 0,
    rightSymbol: ' đ',
  );
  final _purposeController = TextEditingController();
  final _storageService = StorageService();
  late final TelegramService _telegramService;
  late TabController _tabController;
  List<Expense> _expenses = [];
  DateTime _selectedDate = DateTime.now();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  double _totalExpenses = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _telegramService = TelegramService(
      botToken: dotenv.env['TELEGRAM_BOT_TOKEN'] ?? '',
      chatId: dotenv.env['TELEGRAM_CHAT_ID'] ?? '',
    );
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await _storageService.getExpensesByDate(_selectedDate);
    setState(() {
      _expenses = expenses;
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      _totalExpenses = _expenses.fold(0.0, (sum, e) => sum + e.amount);
    });
  }

  Future<void> _addExpense() async {
    if (_amountController.text.isEmpty || _purposeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('messages.fill_info'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final expense = Expense(
      id: const Uuid().v4(),
      amount: _amountController.numberValue,
      description: _purposeController.text,
      purpose: _purposeController.text,
      date: DateTime.now(),
    );

    try {
      await _storageService.saveExpense(expense);
      _amountController.clear();
      _purposeController.clear();
      await _loadExpenses();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('messages.add_success'
                .tr(args: [_currencyFormat.format(expense.amount)])),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('messages.add_error'.tr()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    try {
      await _storageService.deleteExpense(expense.id);
      await _loadExpenses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('messages.delete_success'.tr()),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('messages.delete_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _selectedDate.subtract(const Duration(days: 7)),
        end: _selectedDate,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked.end;
      });
      await _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'app.title'.tr(),
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'tabs.add_expense'.tr()),
            Tab(text: 'tabs.view_expenses'.tr()),
            Tab(text: 'tabs.settings'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab nhập chi tiêu
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'expense.amount'.tr(),
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                        ).animate().fadeIn().slideY(begin: 0.3),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _purposeController,
                          decoration: InputDecoration(
                            labelText: 'expense.purpose'.tr(),
                            prefixIcon: const Icon(Icons.description),
                          ),
                        ).animate().fadeIn().slideY(begin: 0.3),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _addExpense,
                            child: Text('expense.add'.tr()),
                          ),
                        ).animate().fadeIn().slideY(begin: 0.3),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_expenses.isNotEmpty) ...[
                  Expanded(
                    child: ListView.builder(
                      itemCount: _expenses.length > 5 ? 5 : _expenses.length,
                      itemBuilder: (context, index) {
                        final expense = _expenses[index];
                        return Dismissible(
                          key: Key(expense.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (direction) {
                            _deleteExpense(expense);
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.purpose,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('HH:mm')
                                              .format(expense.date),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _currencyFormat.format(expense.amount),
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn().slideY(begin: 0.3);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Tab xem chi tiêu
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                color: theme.cardColor,
                child: Row(
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                      style: theme.textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDateRange(context),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.cardColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'expense.total'.tr(),
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      _currencyFormat.format(_totalExpenses),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _expenses.isEmpty
                    ? Center(
                        child: Text(
                          'expense.empty'.tr(),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _expenses.length,
                        itemBuilder: (context, index) {
                          final expense = _expenses[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.purpose,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('HH:mm')
                                              .format(expense.date),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _currencyFormat.format(expense.amount),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _deleteExpense(expense),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn().slideX();
                        },
                      ),
              ),
            ],
          ),
          // Tab cài đặt
          const SettingsPage(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
