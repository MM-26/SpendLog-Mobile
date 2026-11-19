import 'expense.dart';

/// A plain Dart model representing one month's grouped expense summary.
///
/// No Drift types — this class has zero knowledge of the database layer.
/// Used by LocalDataSource.getExpensesGroupedByMonth(), returned through
/// the repository and providers to the UI.
class MonthSummary {
  final int year;
  final int month;

  /// Sum of expenses (debits) in this month (maintained for backwards compatibility).
  final double total;

  /// Sum of credits (income) in this month.
  final double totalIncome;

  /// Sum of debits (expenses) in this month.
  final double totalExpense;

  /// Net balance (totalIncome - totalExpense).
  final double netBalance;

  /// All entries for this month, ordered by [ExpenseModel.expenseDate] descending.
  final List<ExpenseModel> expenses;

  const MonthSummary({
    required this.year,
    required this.month,
    required this.total,
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
    this.netBalance = 0.0,
    required this.expenses,
  });
}
