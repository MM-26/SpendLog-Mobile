import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/expenses.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Expenses,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Production constructor — opens the real on-device SQLite file.
  AppDatabase()
      : super(
          driftDatabase(
            name: 'spendlog.db',
            native: const DriftNativeOptions(),
          ),
        );

  /// Testing constructor — accepts any [QueryExecutor] (e.g. in-memory).
  /// Use this in unit tests to avoid touching the file system.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Version 2 adds the `type` column ('expense' or 'income')
            // with default 'expense' so all existing data is preserved.
            await m.addColumn(expenses, expenses.type);
          }
        },
      );
}
