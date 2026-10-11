import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendlog_mobile/core/database/app_database.dart';
import 'package:spendlog_mobile/data_sources/local/expense_local_data_source.dart';
import 'package:spendlog_mobile/models/expense.dart';

/// Creates a fresh in-memory database + data source for each test.
/// No file I/O, no state bleed between tests.
ExpenseLocalDataSource _makeDataSource() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  return ExpenseLocalDataSource(db);
}

/// Helper: builds a minimal valid [ExpenseModel] for insertion.
/// [id] is a placeholder — the DB assigns the real id.
ExpenseModel _model({
  String description = 'Coffee',
  double amount = 5.0,
  String category = 'Food',
  DateTime? expenseDate,
  String? notes,
}) {
  return ExpenseModel(
    id: 0,
    description: description,
    amount: amount,
    category: category,
    expenseDate: expenseDate ?? DateTime(2026, 8, 1),
    notes: notes,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('ExpenseLocalDataSource', () {
    // -------------------------------------------------------------------------
    // Insert + GetAll
    // -------------------------------------------------------------------------

    test('insertExpense then getAllExpenses returns inserted record', () async {
      final ds = _makeDataSource();

      await ds.insertExpense(_model(description: 'Lunch', amount: 12.5));
      final all = await ds.getAllExpenses();

      expect(all, hasLength(1));
      expect(all.first.description, 'Lunch');
      expect(all.first.amount, 12.5);
    });

    test('getAllExpenses returns empty list when no records exist', () async {
      final ds = _makeDataSource();
      final all = await ds.getAllExpenses();
      expect(all, isEmpty);
    });

    test('getAllExpenses orders by expenseDate descending', () async {
      final ds = _makeDataSource();
      await ds.insertExpense(_model(expenseDate: DateTime(2026, 7, 1)));
      await ds.insertExpense(_model(expenseDate: DateTime(2026, 8, 1)));
      await ds.insertExpense(_model(expenseDate: DateTime(2026, 6, 1)));

      final all = await ds.getAllExpenses();
      expect(all[0].expenseDate, DateTime(2026, 8, 1));
      expect(all[1].expenseDate, DateTime(2026, 7, 1));
      expect(all[2].expenseDate, DateTime(2026, 6, 1));
    });

    // -------------------------------------------------------------------------
    // GetById
    // -------------------------------------------------------------------------

    test('getExpenseById returns correct record', () async {
      final ds = _makeDataSource();
      await ds.insertExpense(_model(description: 'Bus fare'));
      final all = await ds.getAllExpenses();
      final insertedId = all.first.id;

      final found = await ds.getExpenseById(insertedId);
      expect(found, isNotNull);
      expect(found!.description, 'Bus fare');
    });

    test('getExpenseById returns null for non-existent id', () async {
      final ds = _makeDataSource();
      final found = await ds.getExpenseById(9999);
      expect(found, isNull);
    });

    // -------------------------------------------------------------------------
    // Insert — audit field contract
    // -------------------------------------------------------------------------

    test('insertExpense sets createdAt to now, ignoring model value', () async {
      final ds = _makeDataSource();

      // Pass a model with a clearly wrong createdAt — data source must override it
      final staleModel = ExpenseModel(
        id: 0,
        description: 'Test',
        amount: 1.0,
        category: 'Other',
        expenseDate: DateTime(2026, 8, 1),
        createdAt: DateTime(2000, 1, 1), // intentionally stale
        updatedAt: DateTime(2000, 1, 1),
      );

      final before = DateTime.now();
      await ds.insertExpense(staleModel);
      final after = DateTime.now();

      final inserted = (await ds.getAllExpenses()).first;
      expect(
        inserted.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
        reason: 'createdAt should be set at write time, not taken from model',
      );
      expect(
        inserted.createdAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // Update
    // -------------------------------------------------------------------------

    test('updateExpense changes editable fields', () async {
      final ds = _makeDataSource();
      await ds.insertExpense(_model(description: 'Original', amount: 10.0));
      final inserted = (await ds.getAllExpenses()).first;

      await ds.updateExpense(inserted.copyWith(
        description: 'Updated',
        amount: 99.0,
      ));

      final updated = await ds.getExpenseById(inserted.id);
      expect(updated!.description, 'Updated');
      expect(updated.amount, 99.0);
    });

    test('updateExpense sets updatedAt to now', () async {
      final ds = _makeDataSource();
      await ds.insertExpense(_model());
      final inserted = (await ds.getAllExpenses()).first;

      // Brief pause to ensure clock advances
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await ds.updateExpense(inserted.copyWith(description: 'Changed'));
      final updated = await ds.getExpenseById(inserted.id);

      expect(
        updated!.updatedAt.isAfter(inserted.updatedAt) ||
            updated.updatedAt == inserted.updatedAt,
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // Amendment 3 — createdAt preservation regression test
    // -------------------------------------------------------------------------

    test('updateExpense never modifies createdAt', () async {
      final ds = _makeDataSource();
      await ds.insertExpense(_model(description: 'Before update'));
      final inserted = (await ds.getAllExpenses()).first;
      final originalCreatedAt = inserted.createdAt;

      // Update the expense with a modified description
      await ds.updateExpense(inserted.copyWith(description: 'After update'));
      final updated = await ds.getExpenseById(inserted.id);

      expect(
        updated!.createdAt,
        equals(originalCreatedAt),
        reason:
            'createdAt must be byte-for-byte identical before and after update. '
            'If this fails, _toUpdateCompanion is accidentally writing createdAt.',
      );
    });

    // -------------------------------------------------------------------------
    // Delete
    // -------------------------------------------------------------------------

    test('deleteExpense removes the record', () async {
      final ds = _makeDataSource();
      await ds.insertExpense(_model());
      final inserted = (await ds.getAllExpenses()).first;

      await ds.deleteExpense(inserted.id);

      final all = await ds.getAllExpenses();
      expect(all, isEmpty);
    });

    test('deleteExpense on non-existent id does not throw', () async {
      final ds = _makeDataSource();
      expect(() => ds.deleteExpense(9999), returnsNormally);
    });

    // -------------------------------------------------------------------------
    // getExpensesForMonth
    // -------------------------------------------------------------------------

    test('getExpensesForMonth returns only expenses for the given month',
        () async {
      final ds = _makeDataSource();
      await ds.insertExpense(
          _model(description: 'Aug expense', expenseDate: DateTime(2026, 8, 5)));
      await ds.insertExpense(
          _model(description: 'Jul expense', expenseDate: DateTime(2026, 7, 5)));
      await ds.insertExpense(
          _model(description: 'Aug expense 2', expenseDate: DateTime(2026, 8, 20)));

      final aug = await ds.getExpensesForMonth(2026, 8);
      expect(aug, hasLength(2));
      expect(aug.every((e) => e.expenseDate.month == 8), isTrue);
    });

    test('getExpensesForMonth returns empty list when no expenses in month',
        () async {
      final ds = _makeDataSource();
      await ds.insertExpense(
          _model(expenseDate: DateTime(2026, 7, 1)));

      final aug = await ds.getExpensesForMonth(2026, 8);
      expect(aug, isEmpty);
    });

    // -------------------------------------------------------------------------
    // getExpensesGroupedByMonth
    // -------------------------------------------------------------------------

    test('getExpensesGroupedByMonth groups correctly and calculates totals',
        () async {
      final ds = _makeDataSource();
      await ds.insertExpense(
          _model(amount: 10.0, expenseDate: DateTime(2026, 8, 1)));
      await ds.insertExpense(
          _model(amount: 20.0, expenseDate: DateTime(2026, 8, 15)));
      await ds.insertExpense(
          _model(amount: 50.0, expenseDate: DateTime(2026, 7, 10)));

      final groups = await ds.getExpensesGroupedByMonth();
      expect(groups, hasLength(2));

      // First group should be August (newest)
      expect(groups[0].year, 2026);
      expect(groups[0].month, 8);
      expect(groups[0].total, closeTo(30.0, 0.001));
      expect(groups[0].expenses, hasLength(2));

      // Second group should be July
      expect(groups[1].year, 2026);
      expect(groups[1].month, 7);
      expect(groups[1].total, closeTo(50.0, 0.001));
      expect(groups[1].expenses, hasLength(1));
    });

    test('getExpensesGroupedByMonth returns empty list when no expenses',
        () async {
      final ds = _makeDataSource();
      final groups = await ds.getExpensesGroupedByMonth();
      expect(groups, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Return types — Bible compliance
    // -------------------------------------------------------------------------

    test('getAllExpenses returns List<ExpenseModel>, not a Drift type', () async {
      final ds = _makeDataSource();
      await ds.insertExpense(_model());
      final result = await ds.getAllExpenses();
      expect(result, isA<List<ExpenseModel>>());
    });
  });
}
