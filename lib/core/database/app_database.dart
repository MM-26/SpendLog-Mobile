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
  int get schemaVersion => 1;
}