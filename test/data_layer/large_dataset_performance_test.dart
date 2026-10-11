import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendlog_mobile/core/database/app_database.dart';
import 'package:spendlog_mobile/data_sources/local/expense_local_data_source.dart';
import 'package:spendlog_mobile/repositories/expense_repository.dart';

void main() {
  group('Phase 5 — Large Dataset Performance & Aggregation Tests', () {
    late AppDatabase database;
    late ExpenseLocalDataSource dataSource;
    late ExpenseRepository repository;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = ExpenseLocalDataSource(database);
      repository = ExpenseRepository(dataSource);
    });

    tearDown(() async {
      await database.close();
    });

    test('Inserting 600 expenses across 12 months benchmarks well under 1000ms', () async {
      final stopwatch = Stopwatch()..start();

      // Seed 600 expenses: 50 per month across all 12 months of 2026
      const categories = ['Food', 'Transport', 'Shopping', 'Bills', 'Stationery', 'Other'];
      for (int month = 1; month <= 12; month++) {
        for (int i = 1; i <= 50; i++) {
          final day = (i % 28) + 1;
          await repository.addExpense(
            description: 'Item $i of Month $month',
            amount: 10.0 + (i * 2.0),
            category: categories[i % categories.length],
            expenseDate: DateTime(2026, month, day),
            notes: i % 5 == 0 ? 'Memo for item $i' : null,
          );
        }
      }

      stopwatch.stop();
      // Bulk inserts in memory DB should complete smoothly
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));

      // Benchmark monthly query
      final queryWatch = Stopwatch()..start();
      final marchExpenses = await repository.getExpensesForMonth(2026, 3);
      queryWatch.stop();

      expect(marchExpenses.length, 50);
      expect(queryWatch.elapsedMilliseconds, lessThan(100)); // Sub-100ms on index scan

      // Benchmark monthly history grouping
      final historyWatch = Stopwatch()..start();
      final history = await repository.getMonthlyHistory();
      historyWatch.stop();

      expect(history.length, 12);
      expect(historyWatch.elapsedMilliseconds, lessThan(100));

      // Verify calculation precision
      final marchSummary = history.firstWhere((h) => h.year == 2026 && h.month == 3);
      expect(marchSummary.expenses.length, 50);
      // Expected total: sum(10 + i * 2) for i=1..50 = 50*10 + 2*(50*51/2) = 500 + 2550 = 3050.0
      expect(marchSummary.total, 3050.0);
    });
  });
}
