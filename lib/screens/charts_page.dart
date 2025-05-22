import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:smart_spend/models/expense.dart';
import 'package:smart_spend/services/storage_service.dart';
import 'package:smart_spend/theme/app_theme.dart';
import 'package:flutter/services.dart';

class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage>
    with SingleTickerProviderStateMixin {
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
  late TabController _tabController;
  String _trendPeriod = 'week';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExpenses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final expenses = await _storageService.getExpenses();
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);
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

  List<FlSpot> _getTrendSpots() {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    double total = 0;
    switch (_trendPeriod) {
      case 'week':
        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final dayExpenses = _expenses.where((e) =>
              e.date.year == date.year &&
              e.date.month == date.month &&
              e.date.day == date.day);
          total = dayExpenses.fold(0, (sum, e) => sum + e.amount);
          spots.add(FlSpot((6 - i).toDouble(), total));
        }
        break;
      case 'month':
        for (int i = 29; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final dayExpenses = _expenses.where((e) =>
              e.date.year == date.year &&
              e.date.month == date.month &&
              e.date.day == date.day);
          total = dayExpenses.fold(0, (sum, e) => sum + e.amount);
          spots.add(FlSpot((29 - i).toDouble(), total));
        }
        break;
      case 'year':
        for (int i = 11; i >= 0; i--) {
          final date = DateTime(now.year, now.month - i, 1);
          final monthExpenses = _expenses.where(
              (e) => e.date.year == date.year && e.date.month == date.month);
          total = monthExpenses.fold(0, (sum, e) => sum + e.amount);
          spots.add(FlSpot((11 - i).toDouble(), total));
        }
        break;
    }
    return spots;
  }

  String _getTrendXLabel(double value) {
    final now = DateTime.now();
    switch (_trendPeriod) {
      case 'week':
        final date = now.subtract(Duration(days: 6 - value.toInt()));
        return DateFormat('E').format(date);
      case 'month':
        final date = now.subtract(Duration(days: 29 - value.toInt()));
        return DateFormat('d').format(date);
      case 'year':
        final date = DateTime(now.year, now.month - (11 - value.toInt()), 1);
        return DateFormat('MMM').format(date);
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_expenses.isEmpty) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Center(
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
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: SafeArea(
        child: Column(
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currencyFormat.format(totalAmount),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: EdgeInsets.zero,
              child: TabBar(
                controller: _tabController,
                indicator: const UnderlineTabIndicator(
                  borderSide:
                      BorderSide(width: 3, color: AppTheme.primaryColor),
                  insets: EdgeInsets.symmetric(horizontal: 24),
                ),
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor:
                    theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                labelStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(text: 'chart.by_type'.tr()),
                  Tab(text: 'trend.title'.tr()),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Các loại biểu đồ hiện tại
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _chartTypes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              IconData icon;
                              switch (index) {
                                case 0:
                                  icon = Icons.pie_chart;
                                  break;
                                case 1:
                                  icon = Icons.bar_chart;
                                  break;
                                case 2:
                                  icon = Icons.show_chart;
                                  break;
                                case 3:
                                  icon = Icons.grid_view_rounded;
                                  break;
                                default:
                                  icon = Icons.pie_chart;
                              }
                              return ChoiceChip(
                                avatar: Icon(icon,
                                    size: 18,
                                    color: _selectedChartType == index
                                        ? AppTheme.primaryColor
                                        : theme.iconTheme.color
                                            ?.withOpacity(0.5)),
                                label: Text(_chartTypes[index].tr()),
                                selected: _selectedChartType == index,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedChartType = index;
                                  });
                                },
                                selectedColor:
                                    AppTheme.primaryColor.withOpacity(0.15),
                                backgroundColor: theme.cardColor,
                                labelStyle: TextStyle(
                                  color: _selectedChartType == index
                                      ? AppTheme.primaryColor
                                      : theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_selectedChartType == 0) ...[
                          Text(
                            'chart.by_category'.tr(),
                            style: theme.textTheme.titleLarge?.copyWith(
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
                                        sections: _createPieChartSections(
                                            categoryTotals),
                                        centerSpaceRadius: 30,
                                        sectionsSpace: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children:
                                        _createPieChartLegends(categoryTotals),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else if (_selectedChartType == 1) ...[
                          Text(
                            'chart.by_date'.tr(),
                            style: theme.textTheme.titleLarge?.copyWith(
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
                                    barGroups:
                                        _createBarChartGroups(dailyTotals),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, meta) {
                                            if (value.toInt() >=
                                                dailyTotals.length) {
                                              return const SizedBox();
                                            }
                                            final date = dailyTotals.keys
                                                .elementAt(value.toInt());
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8.0),
                                              child: Text(
                                                DateFormat('dd/MM')
                                                    .format(date),
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
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
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
                            style: theme.textTheme.titleLarge?.copyWith(
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
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: List.generate(
                                          dailyTotals.length,
                                          (index) => FlSpot(
                                              index.toDouble(),
                                              dailyTotals.values
                                                  .elementAt(index)),
                                        ),
                                        isCurved: true,
                                        color: AppTheme.primaryColor,
                                        barWidth: 3,
                                        dotData: const FlDotData(show: true),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.2),
                                        ),
                                      ),
                                    ],
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, meta) {
                                            if (value.toInt() >=
                                                dailyTotals.length) {
                                              return const SizedBox();
                                            }
                                            final date = dailyTotals.keys
                                                .elementAt(value.toInt());
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8.0),
                                              child: Text(
                                                DateFormat('dd/MM')
                                                    .format(date),
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
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                    ),
                                    gridData: const FlGridData(show: true),
                                    borderData: FlBorderData(show: false),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else if (_selectedChartType == 3) ...[
                          Text(
                            'chart.heatmap'.tr(),
                            style: theme.textTheme.titleLarge?.copyWith(
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
                  // Tab 2: Biểu đồ xu hướng
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                setState(() {
                                  _trendPeriod = value;
                                });
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'week',
                                  child: Text('trend.week'.tr()),
                                ),
                                PopupMenuItem(
                                  value: 'month',
                                  child: Text('trend.month'.tr()),
                                ),
                                PopupMenuItem(
                                  value: 'year',
                                  child: Text('trend.year'.tr()),
                                ),
                              ],
                              child: Row(
                                children: [
                                  const Icon(Icons.timeline),
                                  const SizedBox(width: 8),
                                  Text(
                                    _trendPeriod == 'week'
                                        ? 'trend.week'.tr()
                                        : _trendPeriod == 'month'
                                            ? 'trend.month'.tr()
                                            : 'trend.year'.tr(),
                                  ),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: true),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 60,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            _currencyFormat.format(value),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            _getTrendXLabel(value),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: true),
                                  minX: 0,
                                  maxX: _trendPeriod == 'week'
                                      ? 6
                                      : _trendPeriod == 'month'
                                          ? 29
                                          : 11,
                                  minY: 0,
                                  maxY: _getTrendSpots().isEmpty
                                      ? 1000000.0
                                      : _getTrendSpots()
                                              .map((e) => e.y)
                                              .reduce((a, b) => a > b ? a : b) *
                                          1.2,
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _getTrendSpots(),
                                      isCurved: true,
                                      color: AppTheme.primaryColor,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
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
                ],
              ),
            ),
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
