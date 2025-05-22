import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:smart_spend/models/expense.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/services/ai_analysis_service.dart';
import 'package:smart_spend/services/telegram_service.dart';
import 'package:smart_spend/theme/app_theme.dart';
import 'package:smart_spend/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class ExpensesListPage extends StatefulWidget {
  const ExpensesListPage({super.key});

  @override
  State<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends State<ExpensesListPage> {
  final StorageService _storageService = StorageService();
  late final AIAnalysisService _aiAnalysisService;
  late SettingsService _settingsService;
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  List<Expense> _expenses = [];
  List<Expense> _filteredExpenses = [];
  bool _isAnalyzing = false;
  bool _isSendingWebhook = false;
  String _selectedFilter = 'today';
  bool _initialized = false;
  final _listKey = GlobalKey<AnimatedListState>();

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
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _settingsService = SettingsService(prefs);
    final telegramService = TelegramService(_settingsService);
    _aiAnalysisService = AIAnalysisService(
      _storageService,
      telegramService,
      _settingsService,
    );
    await _loadExpenses();
    setState(() {
      _initialized = true;
    });
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

  Future<void> _sendExpensesToWebhook() async {
    setState(() => _isSendingWebhook = true);
    try {
      await _storageService.sendExpensesToWebhook(_settingsService);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Đã gửi dữ liệu lên webhook thành công!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gửi dữ liệu thất bại: \\n$e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingWebhook = false);
    }
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    final jsonController = TextEditingController();
    bool isJsonMode = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('import.title'.tr()),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // maxWidth: 350,
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: Text('import.api_get'.tr()),
                              selected: !isJsonMode,
                              onSelected: (v) =>
                                  setState(() => isJsonMode = !v),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text('import.paste_json'.tr()),
                              selected: isJsonMode,
                              onSelected: (v) => setState(() => isJsonMode = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!isJsonMode)
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'API URL',
                            hintText: 'https://your-api.com/data',
                          ),
                          autofocus: true,
                        ),
                      if (isJsonMode)
                        SizedBox(
                          width: 320,
                          child: TextField(
                            controller: jsonController,
                            decoration: InputDecoration(
                              labelText: 'import.paste_json_label'.tr(),
                              hintText: 'import.paste_json_hint'.tr(),
                            ),
                            minLines: 4,
                            maxLines: 12,
                            keyboardType: TextInputType.multiline,
                            autofocus: true,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('import.cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!isJsonMode) {
                      final url = controller.text.trim();
                      if (url.isNotEmpty) {
                        Navigator.of(context).pop();
                        _importFromApi(url);
                      }
                    } else {
                      final jsonStr = jsonController.text.trim();
                      if (jsonStr.isNotEmpty) {
                        Navigator.of(context).pop();
                        _importFromJson(jsonStr);
                      }
                    }
                  },
                  child: Text('import.import'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _importFromApi(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!uri.isAbsolute) throw Exception('URL không hợp lệ');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = response.body;
        final List<dynamic> jsonList = (data is String)
            ? (data.isNotEmpty
                ? (data.startsWith('[') ? jsonDecode(data) : [jsonDecode(data)])
                : [])
            : data;
        final expenses = jsonList.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['purpose'] = map['purpose']?.toString() ?? '';
          final amount = map['amount'];
          map['amount'] = (amount is int)
              ? amount.toDouble()
              : (amount is double
                  ? amount
                  : double.tryParse(amount.toString()) ?? 0.0);
          map['created_at'] =
              map['created_at'] ?? DateTime.now().toIso8601String();
          return Expense.fromMap(map);
        }).toList();
        await _storageService.deleteAllExpenses();
        await _storageService.insertExpenses(expenses);
        await _loadExpenses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Import dữ liệu thành công!'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Lỗi khi lấy dữ liệu: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Import thất bại: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importFromJson(String jsonStr) async {
    try {
      final List<dynamic> jsonList = (jsonStr.isNotEmpty)
          ? (jsonStr.trim().startsWith('[')
              ? jsonDecode(jsonStr)
              : [jsonDecode(jsonStr)])
          : [];
      final expenses = jsonList.map((e) {
        final map = Map<String, dynamic>.from(e);
        map['purpose'] = map['purpose']?.toString() ?? '';
        final amount = map['amount'];
        map['amount'] = (amount is int)
            ? amount.toDouble()
            : (amount is double
                ? amount
                : double.tryParse(amount.toString()) ?? 0.0);
        map['created_at'] =
            map['created_at'] ?? DateTime.now().toIso8601String();
        return Expense.fromMap(map);
      }).toList();
      await _storageService.deleteAllExpenses();
      await _storageService.insertExpenses(expenses);
      await _loadExpenses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Import dữ liệu thành công!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Import thất bại: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addExpenseAnimated(Expense expense) async {
    await _storageService.saveExpense(expense);
    // Lấy lại danh sách expenses và filter
    final allExpenses = await _storageService.getExpenses();
    _expenses = allExpenses;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expenseDate =
        DateTime(expense.date.year, expense.date.month, expense.date.day);
    bool shouldShow = false;
    switch (_selectedFilter) {
      case 'today':
        shouldShow = expenseDate.isAtSameMomentAs(today);
        break;
      case 'all':
        shouldShow = true;
        break;
      // Có thể bổ sung các filter khác nếu cần
      default:
        shouldShow = true;
    }
    if (shouldShow) {
      setState(() {
        _filteredExpenses.insert(0, expense);
        _listKey.currentState?.insertItem(0);
      });
    }
  }

  Future<void> _deleteExpenseAnimated(int index) async {
    final expense = _filteredExpenses[index];
    if (expense.id != null) {
      await _storageService.deleteExpense(expense.id!);
      setState(() {
        final removed = _filteredExpenses.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(1, 0),
                end: const Offset(0, 0),
              ).chain(CurveTween(curve: Curves.easeOut)),
            ),
            child: FadeTransition(
              opacity: animation,
              child: _buildExpenseTile(removed),
            ),
          ),
          duration: const Duration(milliseconds: 400),
        );
      });
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

  Widget _buildExpenseTile(Expense expense) {
    final theme = Theme.of(context);
    return Card(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final totalAmount = _filteredExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Column(
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
                      : AnimatedList(
                          key: _listKey,
                          initialItemCount: _filteredExpenses.length,
                          itemBuilder: (context, index, animation) {
                            final expense = _filteredExpenses[index];
                            return SlideTransition(
                              position: animation.drive(
                                Tween(
                                  begin: const Offset(1, 0),
                                  end: const Offset(0, 0),
                                ).chain(CurveTween(curve: Curves.easeOut)),
                              ),
                              child: FadeTransition(
                                opacity: animation,
                                child: Dismissible(
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
                                    _deleteExpenseAnimated(index);
                                  },
                                  child: _buildExpenseTile(expense),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: SpeedDial(
                icon: Icons.add,
                activeIcon: Icons.close,
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                children: [
                  SpeedDialChild(
                    child: const Icon(Icons.download, color: Colors.blue),
                    label: 'Import',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    onTap: _showImportDialog,
                  ),
                  SpeedDialChild(
                    child: const Icon(Icons.cloud_upload, color: Colors.orange),
                    label: 'Gửi Webhook',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    onTap: _isSendingWebhook ? null : _sendExpensesToWebhook,
                  ),
                  SpeedDialChild(
                    child: const Icon(Icons.analytics, color: Colors.green),
                    label: 'Phân tích AI',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green,
                    onTap: _isAnalyzing ? null : _analyzeExpenses,
                  ),
                ],
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
