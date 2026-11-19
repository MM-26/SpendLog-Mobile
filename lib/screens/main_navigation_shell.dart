import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'add_expense/add_expense_screen.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';

/// Main navigation shell hosting BottomNavigationBar and FloatingActionButton.
/// Supports both bottom navigation taps and horizontal swipe transitions between tabs
/// (v1.1 Decision 10, step 2).
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<Widget> _screens = const [
    _KeepAlivePage(child: HomeScreen()),
    _KeepAlivePage(child: HistoryScreen()),
    _KeepAlivePage(child: SettingsScreen()),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    final isAdjacent = (_currentIndex - index).abs() == 1;
    setState(() => _currentIndex = index);
    if (isAdjacent) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeInOut,
      );
    } else {
      // Instant jump for non-adjacent screens (e.g. Home <-> Settings)
      // to avoid awkward scrolling through intermediate tabs.
      _pageController.jumpToPage(index);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _openAddExpense() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddExpenseScreen(
          isFromMonthDetail: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1C1F2E) : const Color(0xFFFFFFFF);
    final navBorder = isDark ? const Color(0xFF2E3147) : const Color(0xFFE5E7EB);

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
      ),
      // FAB is visible ONLY on Home tab (v1.1 Decision 10, step 2)
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _openAddExpense,
              tooltip: 'Add Expense',
              elevation: 6,
              shape: const CircleBorder(),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(color: navBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper wrapper preserving page state across tab swipes.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
