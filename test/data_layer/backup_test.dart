import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendlog_mobile/core/database/app_database.dart';
import 'package:spendlog_mobile/core/utils/backup_service.dart';
import 'package:spendlog_mobile/data_sources/local/expense_local_data_source.dart';
import 'package:spendlog_mobile/models/expense.dart';
import 'package:spendlog_mobile/repositories/expense_repository.dart';

// ---------------------------------------------------------------------------
// Test double: throws on the Nth insert inside replaceAllExpenses so we can
// verify the Drift transaction rolls back and existing data is preserved.
// ---------------------------------------------------------------------------
class _FailingOnNthInsertDataSource extends ExpenseLocalDataSource {
  final int failOnInsertIndex; // 1-based
  int _insertCount = 0;

  _FailingOnNthInsertDataSource(super.database,
      {required this.failOnInsertIndex});

  @override
  Future<void> replaceAllExpenses(List<ExpenseModel> newExpenses) async {
    await database.transaction(() async {
      await database.delete(database.expenses).go();
      for (final expense in newExpenses) {
        _insertCount++;
        if (_insertCount == failOnInsertIndex) {
          throw Exception('Simulated mid-transaction insert failure');
        }
        await database
            .into(database.expenses)
            .insert(_toInsertCompanionPublic(expense));
      }
    });
  }

  /// Exposes the private companion builder purely for the test double.
  ExpensesCompanion _toInsertCompanionPublic(ExpenseModel expense) {
    final now = DateTime.now();
    return ExpensesCompanion.insert(
      description: expense.description,
      amount: expense.amount,
      category: expense.category,
      expenseDate: expense.expenseDate,
      notes: Value(expense.notes),
      type: Value(expense.type),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }
}

void main() {
  late AppDatabase db;
  late ExpenseLocalDataSource dataSource;
  late ExpenseRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = ExpenseLocalDataSource(db);
    repository = ExpenseRepository(dataSource);
  });

  tearDown(() async {
    await db.close();
  });

  group('V1.1 Backup & Import Tests (Bible §3 Decision 4 & Decision 10)', () {
    test('valid export writes valid JSON conforming to schema', () async {
      await repository.addExpense(
        description: 'Grocery Shopping',
        amount: 850.50,
        category: 'Food',
        expenseDate: DateTime(2026, 10, 20),
        notes: 'Vegetables and dairy',
      );
      await repository.addExpense(
        description: 'Metro Pass',
        amount: 500.0,
        category: 'Transport',
        expenseDate: DateTime(2026, 10, 21),
      );

      final tempDir = await Directory.systemTemp.createTemp('backup_export_test');
      final targetFile = File('${tempDir.path}/spendlog_backup.json');

      final allExpenses = await repository.getAllExpenses();
      final result = await BackupService.exportBackupToFile(
        expenses: allExpenses,
        targetFile: targetFile,
      );

      expect(result.count, 2);
      expect(await targetFile.exists(), isTrue);

      final jsonContent = await targetFile.readAsString();
      final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;

      expect(decoded['version'], BackupService.currentBackupVersion);
      expect(decoded['exportedAt'], isNotNull);
      expect((decoded['expenses'] as List).length, 2);

      await tempDir.delete(recursive: true);
    });

    test('valid import replaces all existing expenses in database', () async {
      // Seed existing data
      await repository.addExpense(
        description: 'Old Expense 1',
        amount: 100.0,
        category: 'Bills',
        expenseDate: DateTime(2026, 9, 1),
      );
      await repository.addExpense(
        description: 'Old Expense 2',
        amount: 200.0,
        category: 'Shopping',
        expenseDate: DateTime(2026, 9, 2),
      );

      final initialExpenses = await repository.getAllExpenses();
      expect(initialExpenses.length, 2);

      // JSON to import
      final backupJson = jsonEncode({
        'version': 1,
        'exportedAt': '2026-10-31T12:00:00.000Z',
        'expenses': [
          {
            'description': 'Restored Dinner',
            'amount': 450.0,
            'category': 'Food',
            'expenseDate': '2026-10-30T19:30:00.000Z',
            'notes': 'Family dinner',
          },
          {
            'description': 'Restored Fuel',
            'amount': 1200.0,
            'category': 'Transport',
            'expenseDate': '2026-10-31T08:00:00.000Z',
          },
        ],
      });

      final validation = BackupService.validateJsonString(backupJson);
      expect(validation.version, 1);
      expect(validation.expenses.length, 2);

      // Execute replace-all
      await repository.replaceAllExpenses(validation.expenses);

      final updatedExpenses = await repository.getAllExpenses();
      expect(updatedExpenses.length, 2);
      expect(updatedExpenses.any((e) => e.description == 'Old Expense 1'), isFalse);
      expect(updatedExpenses.any((e) => e.description == 'Restored Dinner'), isTrue);
      expect(updatedExpenses.any((e) => e.description == 'Restored Fuel'), isTrue);
    });

    test('corrupt JSON throws BackupException and leaves existing records untouched', () async {
      await repository.addExpense(
        description: 'Keep Me',
        amount: 99.0,
        category: 'Other',
        expenseDate: DateTime(2026, 10, 1),
      );

      const corruptJson = '{ "version": 1, "expenses": [ { "description": "unclosed';

      expect(
        () => BackupService.validateJsonString(corruptJson),
        throwsA(isA<BackupException>()),
      );

      final currentExpenses = await repository.getAllExpenses();
      expect(currentExpenses.length, 1);
      expect(currentExpenses.first.description, 'Keep Me');
    });

    test('wrong version (newer than supported) throws BackupException', () async {
      final newerVersionJson = jsonEncode({
        'version': 99,
        'exportedAt': '2030-01-01T00:00:00.000Z',
        'expenses': [],
      });

      expect(
        () => BackupService.validateJsonString(newerVersionJson),
        throwsA(
          predicate<BackupException>(
            (e) => e.message.contains('is newer than what this app supports'),
          ),
        ),
      );
    });

    test('empty list imports successfully and leaves zero records', () async {
      await repository.addExpense(
        description: 'Will be erased',
        amount: 50.0,
        category: 'Food',
        expenseDate: DateTime(2026, 10, 1),
      );

      final emptyJson = jsonEncode({
        'version': 1,
        'exportedAt': '2026-10-31T00:00:00.000Z',
        'expenses': [],
      });

      final validation = BackupService.validateJsonString(emptyJson);
      expect(validation.expenses, isEmpty);

      await repository.replaceAllExpenses(validation.expenses);

      final current = await repository.getAllExpenses();
      expect(current, isEmpty);
    });

    test('file not found throws clear BackupException with file path', () async {
      final nonExistentFile = File('C:/non_existent_folder/spendlog_backup.json');

      expect(
        () => BackupService.validateFile(nonExistentFile),
        throwsA(
          predicate<BackupException>(
            (e) => e.message.contains('Backup file not found at:'),
          ),
        ),
      );
    });

    test('invalid record (negative amount, empty description) throws BackupException', () {
      final invalidAmountJson = jsonEncode({
        'version': 1,
        'expenses': [
          {
            'description': 'Invalid',
            'amount': -10.0,
            'category': 'Food',
            'expenseDate': '2026-10-31T00:00:00.000Z',
          }
        ],
      });

      expect(
        () => BackupService.validateJsonString(invalidAmountJson),
        throwsA(
          predicate<BackupException>(
            (e) => e.message.contains('"amount" must be a positive number'),
          ),
        ),
      );

      final emptyDescJson = jsonEncode({
        'version': 1,
        'expenses': [
          {
            'description': '   ',
            'amount': 10.0,
            'category': 'Food',
            'expenseDate': '2026-10-31T00:00:00.000Z',
          }
        ],
      });

      expect(
        () => BackupService.validateJsonString(emptyDescJson),
        throwsA(
          predicate<BackupException>(
            (e) => e.message.contains('"description" must be a non-empty string'),
          ),
        ),
      );
    });

    test('reject foreign JSON file that is not a SpendLog backup', () {
      // 1. Random package.json style file
      const foreignJson = '{"name": "my-tool", "version": "1.0.0", "dependencies": {}}';
      expect(
        () => BackupService.validateJsonString(foreignJson),
        throwsA(
          predicate<BackupException>(
            (e) => e.message.contains('not a SpendLog backup'),
          ),
        ),
      );

      // 2. JSON array instead of JSON object
      const arrayJson = '[{"id": 1, "description": "Coffee"}]';
      expect(
        () => BackupService.validateJsonString(arrayJson),
        throwsA(
          predicate<BackupException>(
            (e) => e.message.contains('not an object'),
          ),
        ),
      );

      // 3. File with version int but no expenses
      const missingExpensesJson = '{"version": 1, "data": []}';
      expect(
        () => BackupService.validateJsonString(missingExpensesJson),
        throwsA(
          predicate<BackupException>(
            (e) => e.message.contains('missing "expenses" list'),
          ),
        ),
      );
    });

    test('generateBackupFileName produces date-stamped filename per Bible v1.16', () {
      final date = DateTime(2026, 11, 2);
      final fileName = BackupService.generateBackupFileName(date);
      expect(fileName, 'spendlog_backup_2026-11-02.json');
    });

    // -------------------------------------------------------------------------
    // Rollback tests (Bible §3 Decision 10 — "rollback on failure")
    // -------------------------------------------------------------------------

    test(
        'failed import — invalid record in JSON leaves ALL existing expenses untouched (validation-layer rollback)',
        () async {
      // 1. Seed two real expenses in the DB.
      await repository.addExpense(
        description: 'Groceries',
        amount: 500.0,
        category: 'Food',
        expenseDate: DateTime(2026, 11, 1),
      );
      await repository.addExpense(
        description: 'Fuel',
        amount: 200.0,
        category: 'Transport',
        expenseDate: DateTime(2026, 11, 5),
      );

      final before = await repository.getAllExpenses();
      expect(before.length, 2,
          reason: 'Precondition: 2 existing expenses must be in the DB');

      // 2. Build a backup that would pass the version check but contain a
      //    record with a negative amount — validateJsonString must throw
      //    BEFORE replaceAllExpenses is ever called.
      final badJson = jsonEncode({
        'version': BackupService.currentBackupVersion,
        'exportedAt': '2026-11-10T00:00:00.000Z',
        'expenses': [
          {
            'description': 'Valid Record',
            'amount': 100.0,
            'category': 'Food',
            'expenseDate': '2026-11-01T00:00:00.000Z',
            'type': 'expense',
          },
          {
            'description': 'Bad Record — negative amount',
            'amount': -50.0, // ← invalid; must be rejected
            'category': 'Food',
            'expenseDate': '2026-11-02T00:00:00.000Z',
            'type': 'expense',
          },
        ],
      });

      // 3. The import pipeline stops at validateJsonString → no DB write occurs.
      expect(
        () => BackupService.validateJsonString(badJson),
        throwsA(isA<BackupException>()),
        reason: 'validateJsonString must reject the negative-amount record',
      );

      // 4. Existing data must be completely untouched.
      final after = await repository.getAllExpenses();
      expect(after.length, 2,
          reason: 'Existing expense count must not change after failed import');
      expect(
        after.map((e) => e.description),
        containsAll(['Groceries', 'Fuel']),
        reason: 'Both original expenses must still be in the DB by description',
      );
    });

    test(
        'failed import — mid-transaction DB error rolls back; existing expenses survive (transaction-layer rollback)',
        () async {
      // 1. Build a fresh DB wired to the fault-injecting data source.
      final failingDb =
          AppDatabase.forTesting(NativeDatabase.memory());
      final failingDs = _FailingOnNthInsertDataSource(
        failingDb,
        failOnInsertIndex: 2, // blow up on the 2nd insert inside the transaction
      );
      final failingRepo = ExpenseRepository(failingDs);

      // 2. Seed existing data.
      await failingRepo.addExpense(
        description: 'Keep Me — Alpha',
        amount: 300.0,
        category: 'Bills',
        expenseDate: DateTime(2026, 10, 1),
      );
      await failingRepo.addExpense(
        description: 'Keep Me — Beta',
        amount: 150.0,
        category: 'Shopping',
        expenseDate: DateTime(2026, 10, 15),
      );

      final before = await failingRepo.getAllExpenses();
      expect(before.length, 2,
          reason: 'Precondition: 2 existing rows must be seeded');

      // 3. Attempt a 3-record import; the 2nd insert will throw inside the
      //    Drift transaction.  replaceAllExpenses must propagate the exception.
      final newExpenses = [
        ExpenseModel(
          id: 0,
          description: 'New 1',
          amount: 100.0,
          category: 'Food',
          expenseDate: DateTime(2026, 11, 1),
          type: 'expense',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ExpenseModel(
          id: 0,
          description: 'New 2 — will trigger failure',
          amount: 200.0,
          category: 'Food',
          expenseDate: DateTime(2026, 11, 2),
          type: 'expense',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ExpenseModel(
          id: 0,
          description: 'New 3 — never reached',
          amount: 300.0,
          category: 'Food',
          expenseDate: DateTime(2026, 11, 3),
          type: 'expense',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await expectLater(
        failingRepo.replaceAllExpenses(newExpenses),
        throwsException,
        reason: 'replaceAllExpenses must throw when a mid-transaction insert fails',
      );

      // 4. The Drift transaction must have rolled back — the original 2 rows
      //    must still be intact; none of the 3 new rows should exist.
      final after = await failingRepo.getAllExpenses();
      expect(after.length, 2,
          reason:
              'Drift transaction rollback must restore the original 2 rows');
      expect(
        after.map((e) => e.description),
        containsAll(['Keep Me — Alpha', 'Keep Me — Beta']),
        reason: 'Both original descriptions must survive the failed import',
      );
      expect(
        after.any((e) => e.description.startsWith('New')),
        isFalse,
        reason: 'None of the new import rows must appear after a rollback',
      );

      await failingDb.close();
    });
  });
}

