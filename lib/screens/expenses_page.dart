import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:smart_spend/models/expense.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/services/ai_analysis_service.dart';
import 'package:smart_spend/services/telegram_service.dart';
import 'package:smart_spend/theme/app_theme.dart';
import 'package:smart_spend/screens/settings_page.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:smart_spend/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final StorageService _storageService = StorageService();
  late final AIAnalysisService _aiAnalysisService;
  final _amountController = MoneyMaskedTextController(
    decimalSeparator: '',
    precision: 0,
    rightSymbol: ' đ',
  );
  final _purposeController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  List<Expense> _expenses = [];
  DateTime _selectedDate = DateTime.now();
  double _totalExpenses = 0;
  final ScrollController _scrollController = ScrollController();
  final bool _showAnimation = true;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService(prefs);
    final telegramService = TelegramService(settingsService);
    _aiAnalysisService = AIAnalysisService(
      _storageService,
      telegramService,
      settingsService,
    );
    await _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await _storageService.getExpenses();
    final today = DateTime.now();
    final todayExpenses = expenses
        .where((e) =>
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
        .toList();
    setState(() {
      _expenses = todayExpenses;
      _totalExpenses = todayExpenses.fold(0, (sum, e) => sum + e.amount);
    });
  }

  Future<void> _addExpense() async {
    if (_amountController.text.isEmpty || _purposeController.text.isEmpty) {
      return;
    }

    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (amountText.isEmpty) {
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      return;
    }

    final expense = Expense(
      amount: amount,
      purpose: _purposeController.text,
      date: DateTime.now(),
      description: _purposeController.text,
    );

    await _storageService.saveExpense(expense);
    FocusScope.of(context).unfocus();
    _amountController.updateValue(0);
    _purposeController.clear();
    await _loadExpenses();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('messages.add_success'.tr()),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    if (expense.id != null) {
      await _storageService.deleteExpense(expense.id!);
      await _loadExpenses();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('messages.delete_success'.tr()),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _analyzeExpenses() async {
    if (_expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('messages.no_expenses'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      await _aiAnalysisService.analyzeAndSendReport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('messages.analysis_success'.tr()),
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
            content: Text('messages.analysis_error'.tr()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
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

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showAnimation ? 1.0 : 0.0,
                child: Container(
                  height: MediaQuery.sizeOf(context).height * 0.2,
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  child: Lottie.asset(
                    'assets/animations/wallet.json',
                    fit: BoxFit.fitWidth,
                    repeat: true,
                    animate: true,
                    options: LottieOptions(
                      enableMergePaths: true,
                    ),
                    frameRate: FrameRate.max,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _amountController,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                            decoration: InputDecoration(
                              labelText: 'expense.amount'.tr(),
                              labelStyle: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.grey,
                              ),
                              prefixIcon: const Icon(
                                Icons.attach_money,
                                color: AppTheme.primaryColor,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const Divider(height: 32),
                          TextField(
                            controller: _purposeController,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              labelText: 'expense.purpose'.tr(),
                              labelStyle: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.grey,
                              ),
                              prefixIcon: const Icon(
                                Icons.description,
                                color: AppTheme.primaryColor,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.grey.withOpacity(0.1),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.primaryColor.withOpacity(0.7),
                                const Color(0xFF6DD5FA),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ElevatedButton(
                            onPressed: _addExpense,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_circle_outline),
                                const SizedBox(width: 8),
                                Text(
                                  'expense.add'.tr(),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_expenses.isNotEmpty) ...[
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _expenses.length > 5 ? 5 : _expenses.length,
                  itemBuilder: (context, index) {
                    final expense = _expenses[index];
                    return Dismissible(
                      key: Key(expense.id.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                      onDismissed: (direction) {
                        _deleteExpense(expense);
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            expense.purpose,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('HH:mm').format(expense.date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          trailing: Text(
                            _currencyFormat.format(expense.amount),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
