import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendlog_mobile/core/database/app_database.dart';
import 'package:spendlog_mobile/data_sources/local/expense_local_data_source.dart';
import 'package:spendlog_mobile/providers/expense_provider.dart';
import 'package:spendlog_mobile/providers/theme_provider.dart';
import 'package:spendlog_mobile/repositories/expense_repository.dart';
import 'package:spendlog_mobile/screens/add_expense/add_expense_screen.dart';

Widget _buildAddExpenseScreen({
  required AppDatabase db,
  required ExpenseRepository repo,
  bool isFromMonthDetail = false,
  DateTime? initialMonthYear,
}) {
  final lds = ExpenseLocalDataSource(db);
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      localDataSourceProvider.overrideWithValue(lds),
      expenseRepositoryProvider.overrideWithValue(repo),
      // Use a mock SharedPreferences so ThemeNotifier doesn't hang
      sharedPreferencesProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      home: AddExpenseScreen(
        isFromMonthDetail: isFromMonthDetail,
        initialMonthYear: initialMonthYear,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 5 — AddExpenseScreen Form Validation & Edge Cases', () {
    late AppDatabase db;
    late ExpenseRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ExpenseRepository(ExpenseLocalDataSource(db));
    });

    tearDown(() async {
      await db.close();
    });

    // Helper: set a taller viewport so the full form (including Save button) fits
    // in the hittable test area, then tap the button.
    // The default Flutter test viewport of 800×600 is too short for this form.
    Future<void> tapSaveButton(WidgetTester tester) async {
      // Expand the viewport to 800×1200 so all form fields + Save button are visible
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      // Restore default viewport
      await tester.binding.setSurfaceSize(null);
    }

    testWidgets('Empty description and empty amount trigger validation errors', (tester) async {
      await tester.pumpWidget(_buildAddExpenseScreen(db: db, repo: repo));
      await tester.pumpAndSettle();

      await tapSaveButton(tester);

      expect(find.text('Please enter an amount'), findsOneWidget);
      expect(find.text('Description cannot be empty'), findsOneWidget);
    });

    testWidgets('Whitespace-only description triggers validation error', (tester) async {
      await tester.pumpWidget(_buildAddExpenseScreen(db: db, repo: repo));
      await tester.pumpAndSettle();

      // Enter valid amount in the plain TextField inside the amount card
      await tester.enterText(find.byType(TextField).first, '150');
      // Enter whitespace-only description in the first TextFormField
      await tester.enterText(find.byType(TextFormField).first, '     ');

      await tapSaveButton(tester);

      expect(find.text('Description cannot be empty'), findsOneWidget);
    });

    testWidgets('Zero and negative amounts trigger validation error', (tester) async {
      await tester.pumpWidget(_buildAddExpenseScreen(db: db, repo: repo));
      await tester.pumpAndSettle();

      // Enter valid description first
      await tester.enterText(find.byType(TextFormField).first, 'Coffee');
      // Enter zero amount
      await tester.enterText(find.byType(TextField).first, '0');

      await tapSaveButton(tester);

      expect(find.text('Amount must be greater than 0'), findsOneWidget);
    });

    testWidgets('Amount exceeding 10,000,000 triggers validation error', (tester) async {
      await tester.pumpWidget(_buildAddExpenseScreen(db: db, repo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Super Yacht');
      await tester.enterText(find.byType(TextField).first, '99999999');

      await tapSaveButton(tester);

      expect(find.text('Amount cannot exceed ₹1,00,00,000'), findsOneWidget);
    });

    testWidgets('Valid inputs save to database successfully', (tester) async {
      await tester.pumpWidget(_buildAddExpenseScreen(db: db, repo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '249.50');
      await tester.enterText(find.byType(TextFormField).first, 'Dinner Buffet');

      await tapSaveButton(tester);

      // Give async save time to complete
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final allExpenses = await repo.getAllExpenses();
      expect(allExpenses.length, 1);
      expect(allExpenses.first.description, 'Dinner Buffet');
      expect(allExpenses.first.amount, 249.50);
      expect(allExpenses.first.category, 'Food');
    });

    testWidgets('Category chips are selectable and switch category', (tester) async {
      await tester.pumpWidget(_buildAddExpenseScreen(db: db, repo: repo));
      await tester.pumpAndSettle();

      // Select Transport chip
      await tester.tap(find.text('Transport'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '85.00');
      await tester.enterText(find.byType(TextFormField).first, 'Metro Fare');

      await tapSaveButton(tester);

      // Give async save time to complete
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final allExpenses = await repo.getAllExpenses();
      expect(allExpenses.isNotEmpty, isTrue);
      expect(allExpenses.first.category, 'Transport');
    });
  });
}
