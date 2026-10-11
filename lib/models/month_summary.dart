import 'expense.dart';

/// A plain Dart model representing one month's grouped expense summary.
///
/// No Drift types — this class has zero knowledge of the database layer.
/// Used by LocalDataSource.getExpensesGroupedByMonth(), returned through
/// the repository and providers to the UI.
class MonthSummary {
  final int year;
  final int month;

  /// Sum of [ExpenseModel.amount] for all expenses in this month.
  final double total;

  /// All expenses for this month, ordered by [ExpenseModel.expenseDate] descending.
  final List<ExpenseModel> expenses;

  const MonthSummary({
    required this.year,
    required this.month,
    required this.total,
    required this.expenses,
  });
}
