import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../models/expense.dart';

/// Exception thrown when a backup file fails validation or cannot be read.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// Metadata and parsed records resulting from validating a backup JSON file.
class BackupValidationResult {
  final int version;
  final DateTime exportedAt;
  final List<ExpenseModel> expenses;
  final String? fileName;

  const BackupValidationResult({
    required this.version,
    required this.exportedAt,
    required this.expenses,
    this.fileName,
  });
}

/// Result of a successful backup export.
class BackupExportResult {
  final String filePath;
  final int count;
  final DateTime exportedAt;

  const BackupExportResult({
    required this.filePath,
    required this.count,
    required this.exportedAt,
  });
}

/// Service handling JSON backup export and import validation per Bible §3 Decision 4 & Decision 10 (v1.16).
class BackupService {
  static const int currentBackupVersion = 2; // Bumped for credit/income support (Bible v1.16 Decision 10)
  static const String backupFileName = 'spendlog_backup.json';

  /// Generates the date-stamped file name (e.g. spendlog_backup_2026-11-02.json per Bible v1.16 Decision 10).
  static String generateBackupFileName([DateTime? date]) {
    final d = date ?? DateTime.now();
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'spendlog_backup_$y-$m-$day.json';
  }

  /// Serializes [expenses] to JSON format per Bible §3 Decision 4 & Decision 10.
  static String serializeExpensesToJson(List<ExpenseModel> expenses, {DateTime? now}) {
    final exportedTime = (now ?? DateTime.now()).toUtc();
    final backupMap = {
      'app': 'SpendLog',
      'version': currentBackupVersion,
      'exportedAt': exportedTime.toIso8601String(),
      'expenses': expenses.map((e) {
        return {
          'description': e.description,
          'amount': e.amount,
          'category': e.category,
          'expenseDate': e.expenseDate.toUtc().toIso8601String(),
          'type': e.type,
          if (e.notes != null && e.notes!.trim().isNotEmpty) 'notes': e.notes!.trim(),
        };
      }).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  /// Prompts user with native "Save As" file picker and exports backup (Bible v1.16 Decision 10).
  /// Returns [BackupExportResult] if saved, or null if the user cancelled the dialog.
  static Future<BackupExportResult?> exportWithFilePicker({
    required List<ExpenseModel> expenses,
  }) async {
    final now = DateTime.now().toUtc();
    final jsonContent = serializeExpensesToJson(expenses, now: now);
    final fileName = generateBackupFileName(now.toLocal());
    final bytes = Uint8List.fromList(utf8.encode(jsonContent));

    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Save SpendLog Backup',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
    );

    if (savedUri == null) {
      // User cancelled save dialog
      return null;
    }

    String pathDisplay;
    try {
      pathDisplay = savedUri.isScheme('file') ? savedUri.toFilePath() : savedUri.toString();
    } catch (_) {
      pathDisplay = savedUri.path;
    }

    return BackupExportResult(
      filePath: pathDisplay,
      count: expenses.length,
      exportedAt: now,
    );
  }

  /// Direct file write export (useful for automated testing or headless environments).
  static Future<BackupExportResult> exportBackupToFile({
    required List<ExpenseModel> expenses,
    required File targetFile,
  }) async {
    final now = DateTime.now().toUtc();
    final jsonContent = serializeExpensesToJson(expenses, now: now);

    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsString(jsonContent, flush: true);

    return BackupExportResult(
      filePath: targetFile.path,
      count: expenses.length,
      exportedAt: now,
    );
  }

  /// Prompts user with native file picker to select a backup file (Bible v1.16 Decision 10).
  /// Strictly validates that the selected file is an authentic SpendLog backup.
  /// Returns [BackupValidationResult] if valid, or null if user cancelled.
  /// Throws [BackupException] if user selected a file that is not a SpendLog backup.
  static Future<BackupValidationResult?> pickAndValidateBackup() async {
    final platformFile = await FilePicker.pickFile(
      dialogTitle: 'Select SpendLog Backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (platformFile == null) {
      return null; // User cancelled
    }

    // PlatformFile v13: use readAsBytes() — no .bytes field on this platform API.
    final Uint8List rawBytes;
    try {
      rawBytes = await platformFile.readAsBytes();
    } catch (_) {
      throw const BackupException('Could not read content from the selected file.');
    }
    final String jsonString = utf8.decode(rawBytes);

    final validation = validateJsonString(jsonString);
    return BackupValidationResult(
      version: validation.version,
      exportedAt: validation.exportedAt,
      expenses: validation.expenses,
      fileName: platformFile.name,
    );
  }

  /// Reads and validates the backup file from [file].
  /// Throws [BackupException] if the file does not exist or fails validation.
  static Future<BackupValidationResult> validateFile(File file) async {
    if (!await file.exists()) {
      throw BackupException(
        'Backup file not found at:\n${file.path}\n\n'
        'Please ensure "$backupFileName" is present at that location.',
      );
    }

    final content = await file.readAsString();
    return validateJsonString(content);
  }

  /// Parses and strictly validates [jsonString] before any database operations occur.
  ///
  /// Rejects foreign JSON files (non-SpendLog), malformed documents, unsupported versions,
  /// or corrupt records.
  static BackupValidationResult validateJsonString(String jsonString) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      throw const BackupException(
        'The selected file is not a valid JSON document.',
      );
    }

    if (decoded is! Map) {
      throw const BackupException(
        'The selected file is not a SpendLog backup.\n(JSON root is not an object)',
      );
    }

    // Check mandatory fields for SpendLog backup
    final rawVersion = decoded['version'];
    final rawExpenses = decoded['expenses'];

    if (rawVersion == null && rawExpenses == null) {
      throw const BackupException(
        'The selected file is not a SpendLog backup file.\n'
        'It does not contain SpendLog expense records.',
      );
    }

    if (rawVersion == null || rawVersion is! int) {
      throw const BackupException(
        'The selected file is not a SpendLog backup (missing or invalid "version" field).',
      );
    }

    if (rawVersion > currentBackupVersion) {
      throw BackupException(
        'This backup was created with a newer version of SpendLog (v$rawVersion) '
        'which is newer than what this app supports (v$currentBackupVersion). '
        'Please update SpendLog to restore this file.',
      );
    }

    if (rawVersion < 1) {
      throw BackupException('Invalid backup: unsupported version number ($rawVersion).');
    }

    if (rawExpenses == null || rawExpenses is! List) {
      throw const BackupException(
        'The selected file is not a SpendLog backup: missing "expenses" list.',
      );
    }

    final List<ExpenseModel> parsedExpenses = [];
    final now = DateTime.now();

    for (int i = 0; i < rawExpenses.length; i++) {
      final item = rawExpenses[i];
      if (item is! Map) {
        throw BackupException(
          'Invalid backup file: expense item at index $i is not a valid record.',
        );
      }

      final description = item['description'];
      if (description == null || description is! String || description.trim().isEmpty) {
        throw BackupException(
          'Invalid backup file: record at position ${i + 1} has an empty or missing description. '
          'The "description" must be a non-empty string.',
        );
      }

      final rawAmount = item['amount'];
      if (rawAmount == null || rawAmount is! num || rawAmount <= 0) {
        throw BackupException(
          'Invalid backup file: record at position ${i + 1} has an invalid amount (${rawAmount ?? "missing"}). '
          'The "amount" must be a positive number.',
        );
      }

      final category = item['category'];
      if (category == null || category is! String || category.trim().isEmpty) {
        throw BackupException(
          'Invalid backup file: record at position ${i + 1} is missing a category.',
        );
      }

      final rawDate = item['expenseDate'];
      if (rawDate == null || rawDate is! String) {
        throw BackupException(
          'Invalid backup file: record at position ${i + 1} is missing "expenseDate".',
        );
      }

      final parsedExpenseDate = DateTime.tryParse(rawDate);
      if (parsedExpenseDate == null) {
        throw BackupException(
          'Invalid backup file: record at position ${i + 1} has an invalid date format ("$rawDate").',
        );
      }

      final notes = item['notes'] is String ? (item['notes'] as String).trim() : null;

      // Credit/income support: missing or non-income type defaults to 'expense'
      // per Bible v1.16 Decision 10 (seamless backward compatibility for v1 backups).
      final rawType = item['type'];
      final String type = (rawType is String && rawType == 'income') ? 'income' : 'expense';

      parsedExpenses.add(
        ExpenseModel(
          id: 0, // Assigned by database upon insertion
          description: description.trim(),
          amount: rawAmount.toDouble(),
          category: category.trim(),
          expenseDate: parsedExpenseDate.toLocal(),
          notes: (notes != null && notes.isNotEmpty) ? notes : null,
          type: type,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    DateTime exportedAt = DateTime.now();
    final rawExportedAt = decoded['exportedAt'];
    if (rawExportedAt is String) {
      final parsedDate = DateTime.tryParse(rawExportedAt);
      if (parsedDate != null) {
        exportedAt = parsedDate;
      }
    }

    return BackupValidationResult(
      version: rawVersion,
      exportedAt: exportedAt,
      expenses: parsedExpenses,
    );
  }
}
