import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendlog_mobile/app.dart';
import 'package:spendlog_mobile/core/database/app_database.dart';
import 'package:spendlog_mobile/data_sources/local/expense_local_data_source.dart';
import 'package:spendlog_mobile/models/expense.dart';
import 'package:spendlog_mobile/providers/expense_provider.dart';
import 'package:spendlog_mobile/repositories/expense_repository.dart';
import 'package:spendlog_mobile/screens/add_expense/add_expense_screen.dart';
import 'package:spendlog_mobile/screens/history/history_screen.dart';
import 'package:spendlog_mobile/screens/home/home_screen.dart';
import 'package:spendlog_mobile/screens/month_detail/month_detail_screen.dart';
import 'package:spendlog_mobile/screens/settings/settings_screen.dart';
import 'package:spendlog_mobile/widgets/hero_total_card.dart';

Future<Widget> _createTestApp({List<ExpenseModel> seedExpenses = const []}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final lds = ExpenseLocalDataSource(db);
  final repo = ExpenseRepository(lds);

  for (final exp in seedExpenses) {
    await repo.addExpense(
      description: exp.description,
      amount: exp.amount,
      category: exp.category,
      expenseDate: exp.expenseDate,
      notes: exp.notes,
    );
  }

  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      localDataSourceProvider.overrideWithValue(lds),
      expenseRepositoryProvider.overrideWithValue(repo),
    ],
    child: const SpendLogApp(),
  );
}

void main() {
  setUp(() {
    // Prevent ThemeNotifier from hanging on SharedPreferences in test environment
    SharedPreferences.setMockInitialValues({});
  });
  final now = DateTime.now();

  final sampleExpenses = [
    ExpenseModel(
      id: 1,
      description: 'Grocery Supermarket',
      amount: 150.0,
      category: 'Food',
      expenseDate: DateTime(now.year, now.month, 1),
      createdAt: now,
      updatedAt: now,
    ),
    ExpenseModel(
      id: 2,
      description: 'Office Box & Stationery',
      amount: 60.0,
      category: 'Stationery',
      expenseDate: DateTime(now.year, now.month, 2),
      createdAt: now,
      updatedAt: now,
    ),
    ExpenseModel(
      id: 3,
      description: 'Past June Dinner',
      amount: 4050.0,
      category: 'Food',
      expenseDate: DateTime(2025, 6, 15),
      createdAt: now,
      updatedAt: now,
    ),
  ];

  group('Phase 4 — Live Feature Integration Tests', () {
    testWidgets('App renders MainNavigationShell with Home, History, Settings tabs and seeded expenses', (tester) async {
      final app = await _createTestApp(seedExpenses: sampleExpenses);
      await tester.pumpWidget(app);
      // FutureProviders resolve via real async I/O (SQLite queries).
      // pumpAndSettle only drives the frame loop, not the event loop.
      // runAsync lets the event loop run so futures complete.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();


      // Verify bottom navigation items exist
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify FAB add icon exists on Home
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Verify HomeScreen displays live data from SQLite
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('SpendLog'), findsOneWidget);
      expect(find.byType(HeroTotalCard), findsOneWidget);
      expect(find.text('Recent Expenses'), findsOneWidget);
      expect(find.text('Grocery Supermarket'), findsOneWidget);
      expect(find.text('Office Box & Stationery'), findsOneWidget);
    });

    testWidgets('Tab switching between Home, History, and Settings functions and hides/shows FAB properly', (tester) async {
      final app = await _createTestApp(seedExpenses: sampleExpenses);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // On Home tab: FAB is visible
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Tap History tab
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('Monthly History'), findsOneWidget);
      // On History tab: FAB is hidden
      expect(find.byIcon(Icons.add_rounded), findsNothing);

      // Tap Settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      // On Settings tab: FAB is hidden
      expect(find.byIcon(Icons.add_rounded), findsNothing);

      // Tap Home tab back
      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      // On Home tab: FAB is visible again
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('Tapping month card in History navigates to MonthDetailScreen with bottom-right FAB', (tester) async {
      final app = await _createTestApp(seedExpenses: sampleExpenses);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Go to History
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();

      // June 2025 card should appear from SQLite
      expect(find.text('June 2025'), findsOneWidget);
      await tester.tap(find.text('June 2025'));
      await tester.pumpAndSettle();

      // Verify MonthDetailScreen displays live SQLite records
      expect(find.byType(MonthDetailScreen), findsOneWidget);
      expect(find.text('Archived Records'), findsOneWidget);
      expect(find.byType(HeroTotalCard), findsOneWidget);
      expect(find.text('Past June Dinner'), findsOneWidget);

      // FAB exists on MonthDetailScreen
      expect(find.byTooltip('Add to June 2025'), findsOneWidget);

      // Back navigation
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('AddExpenseScreen opens from Home FAB, validates inputs, and persists new expense to database', (tester) async {
      final app = await _createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Tap add expense FAB on Home
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(AddExpenseScreen), findsOneWidget);
      expect(find.text('Add Expense'), findsOneWidget);

      // Scroll to ensure Save Expense button is visible
      await tester.ensureVisible(find.text('Save Expense'));
      await tester.pumpAndSettle();

      // Attempt to submit empty form
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter an amount'), findsOneWidget);
      expect(find.text('Description cannot be empty'), findsOneWidget);

      // Enter amount (plain TextField inside amount card) & description (TextFormField)
      await tester.enterText(find.byType(TextField).first, '450.50');
      await tester.enterText(find.byType(TextFormField).first, 'Dinner with friends');
      await tester.pumpAndSettle();

      // Select category
      await tester.tap(find.text('Bills'));
      await tester.pumpAndSettle();

      // Submit form
      await tester.ensureVisible(find.text('Save Expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Verifies snackbar feedback and return to HomeScreen with newly added expense
      expect(find.text('Expense "Dinner with friends" logged'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Dinner with friends'), findsOneWidget);
    });

    testWidgets('AddExpenseScreen opened from Month Detail FAB restricts title and context', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final lds = ExpenseLocalDataSource(db);
      final repo = ExpenseRepository(lds);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            localDataSourceProvider.overrideWithValue(lds),
            expenseRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: MonthDetailScreen(
              year: 2025,
              month: 6,
              total: 4050.0,
              count: 8,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap add to month FAB
      await tester.tap(find.byTooltip('Add to June 2025'));
      await tester.pumpAndSettle();

      expect(find.byType(AddExpenseScreen), findsOneWidget);
      expect(find.text('Add to June 2025'), findsOneWidget);
      expect(find.text('Restricted to June 2025'), findsOneWidget);
    });

    testWidgets('ExpenseListTile supports Edit and Delete actions live with database', (tester) async {
      final app = await _createTestApp(seedExpenses: sampleExpenses);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Find options menu on first expense
      final optionsButtons = find.byIcon(Icons.more_vert_rounded);
      expect(optionsButtons, findsWidgets);

      // Tap 3-dots on first item
      await tester.tap(optionsButtons.first);
      await tester.pumpAndSettle();

      // Verify Edit and Delete menu items exist
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Delete to open confirmation dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Expense'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Cancel deletion
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Re-open menu to test Edit
      await tester.tap(optionsButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(AddExpenseScreen), findsOneWidget);
      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('Update Expense'), findsOneWidget);
    });
  });
}
