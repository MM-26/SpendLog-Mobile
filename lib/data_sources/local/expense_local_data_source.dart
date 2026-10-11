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

  /// Returns all months that have at least one expense, as a list of
  /// [MonthSummary] objects sorted newest-first.
  ///
  /// Grouping and total calculation happens in Dart after fetching all rows.
  /// This keeps the query simple and lets the index on [expenseDate] do
  /// the heavy lifting on ordering.
  Future<List<MonthSummary>> getExpensesGroupedByMonth() async {
    final rows = await (database.select(database.expenses)
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .get();

    // Group rows by year+month key
    final Map<String, List<Expense>> grouped = {};
    for (final row in rows) {
      final key =
          '${row.expenseDate.year}-${row.expenseDate.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(row);
    }

    // Build sorted MonthSummary list (keys are already in desc order because
    // rows were fetched desc and Map preserves insertion order in Dart)
    return grouped.entries.map((entry) {
      final expenses = entry.value.map(_toModel).toList();
      final total = expenses.fold(0.0, (sum, e) => sum + e.amount);
      return MonthSummary(
        year: expenses.first.expenseDate.year,
        month: expenses.first.expenseDate.month,
        total: total,
        expenses: expenses,
      );
    }).toList();
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
