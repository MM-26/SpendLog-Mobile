import 'package:intl/intl.dart';

/// Formatter utilities for date and time display.
class DateFormatter {
  static final DateFormat _shortDate = DateFormat('d MMM yyyy');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _fullDate = DateFormat('EEEE, d MMMM yyyy');

  /// Formats date to e.g. `23 May 2026`.
  static String formatShort(DateTime date) => _shortDate.format(date);

  /// Formats date to e.g. `May 2026`.
  static String formatMonthYear(DateTime date) => _monthYear.format(date);

  /// Formats month number and year to e.g. `June 2026`.
  static String formatMonthYearFromInt(int year, int month) =>
      _monthYear.format(DateTime(year, month));

  /// Formats date to e.g. `23 May`.
  static String formatDayMonth(DateTime date) => _dayMonth.format(date);

  /// Formats date to e.g. `Saturday, 23 May 2026`.
  static String formatFull(DateTime date) => _fullDate.format(date);
}
