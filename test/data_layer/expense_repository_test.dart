import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendlog_mobile/core/database/app_database.dart';
import 'package:spendlog_mobile/data_sources/local/expense_local_data_source.dart';
import 'package:spendlog_mobile/models/expense.dart';
import 'package:spendlog_mobile/repositories/expense_repository.dart';

/// Creates a real in-memory stack: DB → LDS → Repository.
/// No mocks — tests the full data path end-to-end within the data layer.
ExpenseRepository _makeRepository() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final ds = ExpenseLocalDataSource(db);
  return ExpenseRepository(ds);
}

void main() {
  group('ExpenseRepository', () {
    // -------------------------------------------------------------------------
    // addExpense — validation
    // -------------------------------------------------------------------------

    test('addExpense throws ArgumentError for empty description', () async {
      final repo = _makeRepository();
      expect(
        () => repo.addExpense(
          description: '   ', // whitespace only
          amount: 10.0,
          category: 'Food',
          expenseDate: DateTime(2026, 8, 1),
        ),
        throwsArgumentError,
      );
    });

    test('addExpense throws ArgumentError for zero amount', () async {
      final repo = _makeRepository();
      expect(
        () => repo.addExpense(
          description: 'Coffee',
          amount: 0.0,
          category: 'Food',
          expenseDate: DateTime(2026, 8, 1),
        ),
        throwsArgumentError,
      );
    });

    test('addExpense throws ArgumentError for negative amount', () async {
      final repo = _makeRepository();
      expect(
        () => repo.addExpense(
          description: 'Coffee',
          amount: -5.0,
          category: 'Food',
          expenseDate: DateTime(2026, 8, 1),
        ),
        throwsArgumentError,
      );
    });

    test('addExpense trims description whitespace', () async {
      final repo = _makeRepository();
      await repo.addExpense(
        description: '  Bus fare  ',
        amount: 2.5,
        category: 'Transport',
        expenseDate: DateTime(2026, 8, 1),
      );
      final all = await repo.getAllExpenses();
      expect(all.first.description, 'Bus fare');
    });

    test('addExpense converts empty-string notes to null', () async {
      final repo = _makeRepository();
      await repo.addExpense(
        description: 'Lunch',
        amount: 15.0,
        category: 'Food',
        expenseDate: DateTime(2026, 8, 1),
        notes: '   ', // whitespace — should be stored as null
      );
      final all = await repo.getAllExpenses();
      expect(all.first.notes, isNull);
    });

    // -------------------------------------------------------------------------
    // addExpense — happy path
    // -------------------------------------------------------------------------

    test('addExpense stores all fields correctly', () async {
      final repo = _makeRepository();
      final date = DateTime(2026, 8, 10);

      await repo.addExpense(
        description: 'Groceries',
        amount: 42.75,
        category: 'Shopping',
        expenseDate: date,
        notes: 'Weekly shop',
      );

      final all = await repo.getAllExpenses();
      expect(all, hasLength(1));
      final e = all.first;
      expect(e.description, 'Groceries');
      expect(e.amount, 42.75);
      expect(e.category, 'Shopping');
      expect(e.expenseDate, date);
      expect(e.notes, 'Weekly shop');
    });

    // -------------------------------------------------------------------------
    // updateExpense — validation
    // -------------------------------------------------------------------------

    test('updateExpense throws ArgumentError for empty description', () async {
      final repo = _makeRepository();
      await repo.addExpense(
        description: 'Valid',
        amount: 10.0,
        category: 'Other',
        expenseDate: DateTime(2026, 8, 1),
      );
      final inserted = (await repo.getAllExpenses()).first;

      expect(
        () => repo.updateExpense(inserted.copyWith(description: '')),
        throwsArgumentError,
      );
    });

    test('updateExpense throws ArgumentError for amount <= 0', () async {
      final repo = _makeRepository();
      await repo.addExpense(
        description: 'Valid',
        amount: 10.0,
        category: 'Other',
        expenseDate: DateTime(2026, 8, 1),
      );
      final inserted = (await repo.getAllExpenses()).first;

      expect(
        () => repo.updateExpense(inserted.copyWith(amount: 0.0)),
        throwsArgumentError,
      );
    });

    // -------------------------------------------------------------------------
    // getAllExpenses
    // -------------------------------------------------------------------------

    test('getAllExpenses returns ExpenseModel list, not Drift types', () async {
      final repo = _makeRepository();
      await repo.addExpense(
        description: 'Test',
        amount: 1.0,
        category: 'Other',
        expenseDate: DateTime(2026, 8, 1),
      );
      final result = await repo.getAllExpenses();
      expect(result, isA<List<ExpenseModel>>());
    });

    // -------------------------------------------------------------------------
    // getMonthlyHistory — grouping and totals
    // -------------------------------------------------------------------------

    test('getMonthlyHistory groups by month and sums totals correctly',
        () async {
      final repo = _makeRepository();
      await repo.addExpense(
          description: 'A',
          amount: 10.0,
          category: 'Food',
          expenseDate: DateTime(2026, 8, 1));
      await repo.addExpense(
          description: 'B',
          amount: 25.0,
          category: 'Food',
          expenseDate: DateTime(2026, 8, 15));
      await repo.addExpense(
          description: 'C',
          amount: 100.0,
          category: 'Bills',
          expenseDate: DateTime(2026, 7, 5));

      final history = await repo.getMonthlyHistory();
      expect(history, hasLength(2));

      expect(history[0].year, 2026);
      expect(history[0].month, 8);
      expect(history[0].total, closeTo(35.0, 0.001));

      expect(history[1].year, 2026);
      expect(history[1].month, 7);
      expect(history[1].total, closeTo(100.0, 0.001));
    });

    test('getMonthlyHistory returns empty list when no expenses', () async {
      final repo = _makeRepository();
      final history = await repo.getMonthlyHistory();
      expect(history, isEmpty);
    });

    // -------------------------------------------------------------------------
    // deleteExpense
    // -------------------------------------------------------------------------

    test('deleteExpense removes the record from getAllExpenses', () async {
      final repo = _makeRepository();
      await repo.addExpense(
        description: 'To delete',
        amount: 5.0,
        category: 'Other',
        expenseDate: DateTime(2026, 8, 1),
      );
      final inserted = (await repo.getAllExpenses()).first;
      await repo.deleteExpense(inserted.id);
      expect(await repo.getAllExpenses(), isEmpty);
    });
  });
}
