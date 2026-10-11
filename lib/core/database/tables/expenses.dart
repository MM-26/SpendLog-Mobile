import 'package:drift/drift.dart';

// Index on expenseDate — required by Bible §3 Decision 3 and §4.1 for
// monthly grouping query performance.
@TableIndex(name: 'expenses_expense_date_idx', columns: {#expenseDate})
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get description => text()();

  RealColumn get amount => real()();

  TextColumn get category => text()();

  // Indexed — drives all monthly grouping and History queries (Bible §3 Decision 3, §4.1)
  DateTimeColumn get expenseDate => dateTime()();

  TextColumn get notes => text().nullable()();

  // Audit field — set at write time only, never shown in UI, never editable
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  // Audit field — explicitly set to DateTime.now() on every update call
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}