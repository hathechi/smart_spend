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
  int _selectedChartType = 0; // 0: Pie, 1: Bar, 2: Line, 3: Heatmap
  final List<String> _chartTypes = [
    'chart.pie_chart',
    'chart.bar_chart',
    'chart.line_chart',
    'chart.heatmap',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final expenses = await _storageService.getExpenses();
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);
    // Lọc chi tiêu chỉ trong tháng hiện tại
    final monthExpenses = expenses.where((e) {
      final date = DateTime(e.date.year, e.date.month, e.date.day);
      return date.isAfter(thisMonthStart.subtract(const Duration(days: 1))) &&
          date.isBefore(nextMonthStart);
    }).toList();
    setState(() {
      _expenses = monthExpenses;
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
              'chart.no_data'.tr(),
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
    final now = DateTime.now();
    final monthStr = DateFormat.yMMMM(context.locale.languageCode).format(now);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                    Row(
                      children: [
                        Icon(Icons.calendar_month,
                            color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 8),
                        Text(
                          'chart.this_month'.tr(namedArgs: {'month': monthStr}),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currencyFormat.format(totalAmount),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'chart.by_type'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _chartTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ChoiceChip(
                    label: Text(_chartTypes[index].tr()),
                    selected: _selectedChartType == index,
                    onSelected: (selected) {
                      setState(() {
                        _selectedChartType = index;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedChartType == 0) ...[
              Text(
                'chart.by_category'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SizedBox(
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
                      const SizedBox(height: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _createPieChartLegends(categoryTotals),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_selectedChartType == 1) ...[
              Text(
                'chart.by_date'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        barGroups: _createBarChartGroups(dailyTotals),
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
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (_selectedChartType == 2) ...[
              Text(
                'chart.by_date'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: 250,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [_createLineChartBarData(dailyTotals)],
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
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final date =
                                    dailyTotals.keys.elementAt(spot.x.toInt());
                                return LineTooltipItem(
                                  '${DateFormat('dd/MM').format(date)}\n${_currencyFormat.format(spot.y)}',
                                  const TextStyle(color: Colors.white),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (_selectedChartType == 3) ...[
              Text(
                'chart.heatmap'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: 220,
                    child: _buildHeatmap(dailyTotals),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  LineChartBarData _createLineChartBarData(Map<DateTime, double> dailyTotals) {
    return LineChartBarData(
      spots: List.generate(
        dailyTotals.length,
        (index) =>
            FlSpot(index.toDouble(), dailyTotals.values.elementAt(index)),
      ),
      isCurved: true,
      color: AppTheme.primaryColor,
      barWidth: 3,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        color: AppTheme.primaryColor.withOpacity(0.2),
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

  List<BarChartGroupData> _createBarChartGroups(
      Map<DateTime, double> dailyTotals) {
    return List.generate(dailyTotals.length, (index) {
      final value = dailyTotals.values.elementAt(index);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value.toDouble(),
            color: AppTheme.primaryColor,
            width: 16,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    });
  }

  Widget _buildHeatmap(Map<DateTime, double> dailyTotals) {
    // Đơn giản: hiển thị heatmap theo tuần/tháng, mỗi ô là 1 ngày, màu sắc theo mức chi tiêu
    final days = dailyTotals.keys.toList()..sort();
    if (days.isEmpty) {
      return Center(child: Text('chart.no_data'.tr()));
    }
    final maxAmount =
        dailyTotals.values.fold<double>(0, (max, v) => v > max ? v : max);
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: days.length,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final date = days[index];
        final amount = dailyTotals[date] ?? 0;
        final colorValue =
            maxAmount == 0 ? 0.0 : (amount / maxAmount * 0.8 + 0.2);
        return Tooltip(
          message:
              '${DateFormat('dd/MM').format(date)}\n${_currencyFormat.format(amount)}',
          child: Container(
            decoration: BoxDecoration(
              color: Color.lerp(
                  Colors.grey[200], AppTheme.primaryColor, colorValue),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                DateFormat('d').format(date),
                style: TextStyle(
                  color: colorValue > 0.5 ? Colors.white : Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
      shrinkWrap: true,
    );
  }
}
