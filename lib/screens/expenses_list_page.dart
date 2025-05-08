import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:smart_spend/models/expense.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/services/ai_analysis_service.dart';
import 'package:smart_spend/services/telegram_service.dart';
import 'package:smart_spend/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ExpensesListPage extends StatefulWidget {
  const ExpensesListPage({super.key});

  @override
  State<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends State<ExpensesListPage> {
  final StorageService _storageService = StorageService();
  final AIAnalysisService _aiAnalysisService = AIAnalysisService(
    StorageService(),
    TelegramService(
      botToken: dotenv.env['TELEGRAM_BOT_TOKEN'] ?? '',
      chatId: dotenv.env['TELEGRAM_CHAT_ID'] ?? '',
    ),
  );
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  List<Expense> _expenses = [];
  List<Expense> _filteredExpenses = [];
  bool _isAnalyzing = false;
  String _selectedFilter = 'today';

  final Map<String, String> _dateFilters = {
    'all': 'filters.all'.tr(),
    'today': 'filters.today'.tr(),
    'yesterday': 'filters.yesterday'.tr(),
    'this_week': 'filters.this_week'.tr(),
    'last_week': 'filters.last_week'.tr(),
    'this_month': 'filters.this_month'.tr(),
    'last_month': 'filters.last_month'.tr(),
  };

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await _storageService.getExpenses();
    setState(() {
      _expenses = expenses;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    setState(() {
      _filteredExpenses = _expenses.where((expense) {
        final expenseDate = DateTime(
          expense.date.year,
          expense.date.month,
          expense.date.day,
        );

        switch (_selectedFilter) {
          case 'today':
            return expenseDate.isAtSameMomentAs(today);
          case 'yesterday':
            return expenseDate.isAtSameMomentAs(yesterday);
          case 'this_week':
            return expenseDate
                    .isAfter(thisWeekStart.subtract(const Duration(days: 1))) &&
                expenseDate
                    .isBefore(thisWeekStart.add(const Duration(days: 7)));
          case 'last_week':
            return expenseDate
                    .isAfter(lastWeekStart.subtract(const Duration(days: 1))) &&
                expenseDate
                    .isBefore(lastWeekStart.add(const Duration(days: 7)));
          case 'this_month':
            return expenseDate.isAfter(
                    thisMonthStart.subtract(const Duration(days: 1))) &&
                expenseDate.isBefore(DateTime(now.year, now.month + 1, 1));
          case 'last_month':
            return expenseDate.isAfter(
                    lastMonthStart.subtract(const Duration(days: 1))) &&
                expenseDate.isBefore(thisMonthStart);
          case 'all':
          default:
            return true;
        }
      }).toList();
    });
  }

  Future<void> _deleteExpense(Expense expense) async {
    await _storageService.deleteExpense(expense.id);
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

  Future<void> _analyzeExpenses() async {
    if (_filteredExpenses.isEmpty) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalAmount = _filteredExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        items: _dateFilters.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedFilter = value;
                              _applyFilter();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _analyzeExpenses,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.analytics),
                  label: Text(
                    _isAnalyzing
                        ? 'messages.analyzing'.tr()
                        : 'messages.analyze'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_filteredExpenses.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'expense.total'.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(totalAmount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: _filteredExpenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'expense.no_data'.tr(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'expense.add_new'.tr(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredExpenses.length,
                      itemBuilder: (context, index) {
                        final expense = _filteredExpenses[index];
                        return Dismissible(
                          key: Key(expense.id),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedFilter,
              isExpanded: true,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('Tất cả'.tr()),
                ),
                DropdownMenuItem(
                  value: 'today',
                  child: Text('Hôm nay'.tr()),
                ),
                DropdownMenuItem(
                  value: 'yesterday',
                  child: Text('Hôm qua'.tr()),
                ),
                DropdownMenuItem(
                  value: 'lastWeek',
                  child: Text('Tuần trước'.tr()),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedFilter = value;
                    _applyFilter();
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList() {
    if (_filteredExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Không có chi tiêu nào'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy thêm chi tiêu mới'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredExpenses.length,
      itemBuilder: (context, index) {
        final expense = _filteredExpenses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                expense.purpose[0].toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(
              expense.purpose,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              DateFormat('dd/MM/yyyy').format(expense.date),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            trailing: Text(
              _currencyFormat.format(expense.amount),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}
