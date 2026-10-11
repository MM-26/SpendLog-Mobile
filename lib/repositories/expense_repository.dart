import '../data_sources/local/expense_local_data_source.dart';
import '../models/expense.dart';
import '../models/month_summary.dart';

/// Business logic layer for expense data.
///
/// Depends on [ExpenseLocalDataSource] only — has zero Drift imports and
/// zero knowledge of the database implementation.
/// Always returns plain Dart models ([ExpenseModel], [MonthSummary]).
///
/// Bible §2.5, §11.1: repositories never return Drift-generated types.
class ExpenseRepository {
  final ExpenseLocalDataSource _dataSource;

  ExpenseRepository(this._dataSource);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Returns all expenses ordered by date descending.
  Future<List<ExpenseModel>> getAllExpenses() {
    return _dataSource.getAllExpenses();
  }

  /// Returns a single expense by [id], or null if not found.
  Future<ExpenseModel?> getExpenseById(int id) {
    return _dataSource.getExpenseById(id);
  }

  /// Returns all expenses for the given [year] and [month],
  /// ordered by date descending.
  Future<List<ExpenseModel>> getExpensesForMonth(int year, int month) {
    return _dataSource.getExpensesForMonth(year, month);
  }

  /// Returns a list of [MonthSummary] objects, one per month that has at
  /// least one expense, sorted newest-first.
  Future<List<MonthSummary>> getMonthlyHistory() {
    return _dataSource.getExpensesGroupedByMonth();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Adds a new expense after validating inputs.
  ///
  /// Throws [ArgumentError] if [description] is empty or [amount] is not > 0.
  /// [createdAt] and [updatedAt] are set by [ExpenseLocalDataSource] at write
  /// time — callers must not supply them.
  Future<void> addExpense({
    required String description,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? notes,
  }) {
    if (description.trim().isEmpty) {
      throw ArgumentError('Description must not be empty.');
    }
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than 0.');
    }

    // Temporary model used as a data carrier to the data source.
    // id is a placeholder — the DB assigns the real id on insert.
    // createdAt/updatedAt are placeholders — LDS overwrites them at write time.
    final expense = ExpenseModel(
      id: 0,
      description: description.trim(),
      amount: amount,
      category: category,
      expenseDate: expenseDate,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return _dataSource.insertExpense(expense);
  }

  /// Updates an existing expense.
  ///
  /// [updatedAt] is set by [ExpenseLocalDataSource] at write time.
  /// [createdAt] on the incoming model is ignored — it is never written on update.
  /// Throws [ArgumentError] on invalid description or amount.
  Future<void> updateExpense(ExpenseModel expense) {
    if (expense.description.trim().isEmpty) {
      throw ArgumentError('Description must not be empty.');
    }
    if (expense.amount <= 0) {
      throw ArgumentError('Amount must be greater than 0.');
    }
    return _dataSource.updateExpense(expense);
  }

  /// Deletes the expense with the given [id].
  Future<void> deleteExpense(int id) {
    return _dataSource.deleteExpense(id);
  }
}
