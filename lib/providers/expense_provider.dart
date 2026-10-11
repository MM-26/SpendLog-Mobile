import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../data_sources/local/expense_local_data_source.dart';
import '../models/expense.dart';
import '../models/month_summary.dart';
import '../repositories/expense_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

/// Provides the single [AppDatabase] instance for the app lifetime.
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// Provides [ExpenseLocalDataSource], wired to the [AppDatabase].
///
/// This is the only provider that touches Drift — everything above it
/// uses [expenseRepositoryProvider] and sees only plain Dart models.
final localDataSourceProvider = Provider<ExpenseLocalDataSource>((ref) {
  return ExpenseLocalDataSource(ref.watch(databaseProvider));
});

/// Provides [ExpenseRepository], wired to [ExpenseLocalDataSource].
///
/// Bible §2.5: repository depends on LocalDataSource only.
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(localDataSourceProvider));
});

// ---------------------------------------------------------------------------
// Read providers
// ---------------------------------------------------------------------------

/// All expenses, ordered by date descending. Returns plain [ExpenseModel] list.
final expensesProvider = FutureProvider<List<ExpenseModel>>((ref) {
  return ref.watch(expenseRepositoryProvider).getAllExpenses();
});

/// Monthly history — one [MonthSummary] per month, newest-first.
final monthlyHistoryProvider = FutureProvider<List<MonthSummary>>((ref) {
  return ref.watch(expenseRepositoryProvider).getMonthlyHistory();
});

/// Expenses logged in the current calendar month.
final currentMonthExpensesProvider = FutureProvider<List<ExpenseModel>>((ref) {
  final now = DateTime.now();
  return ref.watch(expenseRepositoryProvider).getExpensesForMonth(now.year, now.month);
});

/// Total amount spent in the current calendar month.
final currentMonthTotalProvider = FutureProvider<double>((ref) async {
  final expenses = await ref.watch(currentMonthExpensesProvider.future);
  return expenses.fold<double>(0.0, (sum, item) => sum + item.amount);
});

/// Expenses for a specific [year] and [month] (used by MonthDetailScreen).
final monthExpensesProvider = FutureProvider.family<List<ExpenseModel>, ({int year, int month})>((ref, arg) {
  return ref.watch(expenseRepositoryProvider).getExpensesForMonth(arg.year, arg.month);
});

/// Total amount spent in a specific [year] and [month].
final monthTotalProvider = FutureProvider.family<double, ({int year, int month})>((ref, arg) async {
  final expenses = await ref.watch(monthExpensesProvider(arg).future);
  return expenses.fold<double>(0.0, (sum, item) => sum + item.amount);
});

// ---------------------------------------------------------------------------
// Action provider — exposes mutations to the UI
// ---------------------------------------------------------------------------

/// Provides callable expense mutation methods to the UI layer.
///
/// UI calls these methods; they delegate to the repository.
/// UI never calls the repository or data source directly.
class ExpenseActions {
  final ExpenseRepository _repository;
  final Ref _ref;

  ExpenseActions(this._repository, this._ref);

  Future<void> addExpense({
    required String description,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? notes,
  }) async {
    await _repository.addExpense(
      description: description,
      amount: amount,
      category: category,
      expenseDate: expenseDate,
      notes: notes,
    );
    _invalidateAll();
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _repository.updateExpense(expense);
    _invalidateAll();
  }

  Future<void> deleteExpense(int id) async {
    await _repository.deleteExpense(id);
    _invalidateAll();
  }

  void _invalidateAll() {
    _ref.invalidate(expensesProvider);
    _ref.invalidate(monthlyHistoryProvider);
    _ref.invalidate(currentMonthExpensesProvider);
    _ref.invalidate(currentMonthTotalProvider);
    _ref.invalidate(monthExpensesProvider);
    _ref.invalidate(monthTotalProvider);
  }
}

final expenseActionsProvider = Provider<ExpenseActions>((ref) {
  return ExpenseActions(ref.watch(expenseRepositoryProvider), ref);
});
