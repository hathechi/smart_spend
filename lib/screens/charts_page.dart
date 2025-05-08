import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:smart_spend/models/expense.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/theme/app_theme.dart';

class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  final StorageService _storageService = StorageService();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final expenses = await _storageService.getExpenses();
    setState(() {
      _expenses = expenses;
      _isLoading = false;
    });
  }

  Map<String, double> _getCategoryTotals() {
    final totals = <String, double>{};
    for (var expense in _expenses) {
      totals[expense.purpose] = (totals[expense.purpose] ?? 0) + expense.amount;
    }
    return totals;
  }

  Map<DateTime, double> _getDailyTotals() {
    final totals = <DateTime, double>{};
    for (var expense in _expenses) {
      final date = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      totals[date] = (totals[date] ?? 0) + expense.amount;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'expense.no_data'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      );
    }

    final categoryTotals = _getCategoryTotals();
    final dailyTotals = _getDailyTotals();
    final totalAmount = _expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tổng chi tiêu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'expense.total'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currencyFormat.format(totalAmount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _expenses.isNotEmpty
                        ? 'Ngày ${DateFormat('dd/MM/yyyy').format(_expenses.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b))}'
                        : 'Ngày ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Biểu đồ tròn theo danh mục
            Text(
              'expense.category'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                height: 220,
                width: 220,
                child: PieChart(
                  PieChartData(
                    sections: _createPieChartSections(categoryTotals),
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _createPieChartLegends(categoryTotals),
              ),
            ),
            const SizedBox(height: 32),

            // Biểu đồ cột theo ngày
            Text(
              'expense.daily'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: dailyTotals.values.reduce((a, b) => a > b ? a : b) *
                        1.2,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final date = dailyTotals.keys.elementAt(groupIndex);
                          return BarTooltipItem(
                            '${DateFormat('dd/MM').format(date)}\n${_currencyFormat.format(rod.toY)}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= dailyTotals.length) {
                              return const SizedBox();
                            }
                            final date =
                                dailyTotals.keys.elementAt(value.toInt());
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              _currencyFormat.format(value),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1000000,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    barGroups: _createBarGroups(dailyTotals),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _createPieChartSections(
      Map<String, double> categoryTotals) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    return categoryTotals.entries.map((entry) {
      final index = categoryTotals.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        value: entry.value,
        title:
            '${(entry.value / _expenses.fold<double>(0, (sum, e) => sum + e.amount) * 100).toStringAsFixed(1)}%',
        color: colors[index % colors.length],
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Widget> _createPieChartLegends(Map<String, double> categoryTotals) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    return categoryTotals.entries.map((entry) {
      final index = categoryTotals.keys.toList().indexOf(entry.key);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _currencyFormat.format(entry.value),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<BarChartGroupData> _createBarGroups(Map<DateTime, double> dailyTotals) {
    return List.generate(dailyTotals.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: dailyTotals.values.elementAt(index),
            color: AppTheme.primaryColor,
            width: 16,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
          ),
        ],
      );
    });
  }
}
