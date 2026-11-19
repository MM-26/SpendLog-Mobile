import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../models/expense.dart';
import '../../models/month_summary.dart';

/// The only class in the app that interacts with Drift directly.
///
/// All methods return plain Dart models — never Drift-generated types.
/// The repository and everything above it have zero Drift knowledge.
class ExpenseLocalDataSource {
  final AppDatabase database;

  ExpenseLocalDataSource(this.database);

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  /// Maps a Drift-generated [Expense] row to a plain [ExpenseModel].
  ExpenseModel _toModel(Expense expense) {
    return ExpenseModel(
      id: expense.id,
      description: expense.description,
      amount: expense.amount,
      category: expense.category,
      expenseDate: expense.expenseDate,
      notes: expense.notes,
      type: expense.type,
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
    );
  }

  /// Companion for INSERT operations.
  ///
  /// Sets [createdAt] and [updatedAt] to [DateTime.now()] at write time.
  /// Never reads these from the incoming model — they are audit fields
  /// owned by the data source, not the caller.
  ExpensesCompanion _toInsertCompanion(ExpenseModel expense) {
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

  /// Companion for UPDATE operations.
  ///
  /// Omits [createdAt] entirely by construction — not by convention.
  /// This makes it structurally impossible to overwrite [createdAt] on update,
  /// regardless of what the incoming model contains.
  /// Sets [updatedAt] to [DateTime.now()] at write time.
  ExpensesCompanion _toUpdateCompanion(ExpenseModel expense) {
    return ExpensesCompanion(
      description: Value(expense.description),
      amount: Value(expense.amount),
      category: Value(expense.category),
      expenseDate: Value(expense.expenseDate),
      notes: Value(expense.notes),
      type: Value(expense.type),
      updatedAt: Value(DateTime.now()),
      // createdAt intentionally absent — Drift treats absent fields as no-op
    );
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Future<List<ExpenseModel>> getAllExpenses() async {
    final rows = await (database.select(database.expenses)
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .get();
    return rows.map(_toModel).toList();
  }

  Future<ExpenseModel?> getExpenseById(int id) async {
    final row = await (database.select(database.expenses)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _toModel(row);
  }

  Future<void> insertExpense(ExpenseModel expense) async {
    await database.into(database.expenses).insert(
          _toInsertCompanion(expense),
        );
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await (database.update(database.expenses)
          ..where((t) => t.id.equals(expense.id)))
        .write(_toUpdateCompanion(expense));
  }

  Future<void> deleteExpense(int id) async {
    await (database.delete(database.expenses)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// Atomically replaces all existing expenses with [newExpenses] inside a
  /// single database transaction (Bible v1.1 Decision 10).
  ///
  /// If any operation fails, the transaction rolls back completely,
  /// preserving existing records untouched.
  Future<void> replaceAllExpenses(List<ExpenseModel> newExpenses) async {
    await database.transaction(() async {
      await database.delete(database.expenses).go();
      for (final expense in newExpenses) {
        await database.into(database.expenses).insert(_toInsertCompanion(expense));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Returns all expenses for a given [year] and [month], ordered by
  /// [expenseDate] descending.
  Future<List<ExpenseModel>> getExpensesForMonth(int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final startOfNextMonth = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    final rows = await (database.select(database.expenses)
          ..where(
            (t) =>
                t.expenseDate.isBiggerOrEqualValue(startOfMonth) &
                t.expenseDate.isSmallerThanValue(startOfNextMonth),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .get();
    return rows.map(_toModel).toList();
  }

  /// Returns every month from the oldest expense up to the current month,
  /// newest-first, including months with zero expenses.
  ///
  /// This ensures past months without any expenses are still visible in
  /// History so the user can tap in and log retroactive entries.
  /// If there are no expenses at all the list is empty (home screen handles
  /// the brand-new user state).
  Future<List<MonthSummary>> getExpensesGroupedByMonth() async {
    final rows = await (database.select(database.expenses)
          ..orderBy([(t) => OrderingTerm.asc(t.expenseDate)]))
        .get();

    // If there are no expenses at all, return empty — no anchor to start from.
    if (rows.isEmpty) return [];

    // Build a map of year+month → expenses for quick lookup.
    final Map<String, List<Expense>> grouped = {};
    for (final row in rows) {
      final key =
          '${row.expenseDate.year}-${row.expenseDate.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(row);
    }

    // Determine the range: oldest expense month → max(newest expense, current month).
    final oldest = rows.first.expenseDate;
    final newest = rows.last.expenseDate;
    final now = DateTime.now();
    int walkYear = oldest.year;
    int walkMonth = oldest.month;
    
    final bool newestIsFuture = newest.year > now.year || 
        (newest.year == now.year && newest.month > now.month);
    final endYear = newestIsFuture ? newest.year : now.year;
    final endMonth = newestIsFuture ? newest.month : now.month;

    final List<MonthSummary> result = [];

    // Walk every calendar month in the range (inclusive on both ends).
    while (walkYear < endYear || (walkYear == endYear && walkMonth <= endMonth)) {
      final key = '$walkYear-${walkMonth.toString().padLeft(2, '0')}';
      final monthRows = grouped[key] ?? [];

      final expenses = monthRows.map(_toModel).toList();
      double totalIncome = 0.0;
      double totalExpense = 0.0;
      for (final exp in expenses) {
        if (exp.isIncome) {
          totalIncome += exp.amount;
        } else {
          totalExpense += exp.amount;
        }
      }
      final netBalance = totalIncome - totalExpense;

      result.add(MonthSummary(
        year: walkYear,
        month: walkMonth,
        total: totalExpense,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netBalance: netBalance,
        expenses: expenses,
      ));

      // Advance one month.
      if (walkMonth == 12) {
        walkYear += 1;
        walkMonth = 1;
      } else {
        walkMonth += 1;
      }
    }

    // Return newest-first.
    return result.reversed.toList();
  }

  // ---------------------------------------------------------------------------
  // Search — V1.0 internal use / testing only; not exposed through repository
  // ---------------------------------------------------------------------------

  Future<List<ExpenseModel>> searchExpenses(String query) async {
    final rows = await (database.select(database.expenses)
          ..where(
            (t) =>
                t.description.like('%$query%') |
                t.category.like('%$query%') |
                t.notes.like('%$query%'),
          ))
        .get();
    return rows.map(_toModel).toList();
  }
}
