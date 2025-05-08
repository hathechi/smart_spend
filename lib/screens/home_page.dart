import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_spend/screens/expenses_page.dart';
import 'package:smart_spend/screens/expenses_list_page.dart';
import 'package:smart_spend/screens/charts_page.dart';
import 'package:smart_spend/screens/settings_page.dart';
import 'package:provider/provider.dart';
import 'package:smart_spend/services/settings_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smart_spend/theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  final List<Widget> _pages = [
    const ExpensesPage(),
    const ExpensesListPage(),
    const ChartsPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Thêm listener cho sự thay đổi ngôn ngữ
    context.locale;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 350),
              curve: Curves.ease,
            );
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.add_circle_outline),
            selectedIcon: const Icon(Icons.add_circle),
            label: 'navigation.add'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt),
            label: 'navigation.list'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: 'navigation.charts'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: 'navigation.settings'.tr(),
          ),
        ],
      ),
    );
  }
}
