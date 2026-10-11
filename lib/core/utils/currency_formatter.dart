import 'package:intl/intl.dart';

/// Formatter utilities for currency display.
class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
    locale: 'en_IN',
  );

  /// Formats a numeric [amount] to Indian Rupee currency format (e.g. `₹1,250.00`).
  static String format(double amount) {
    return _formatter.format(amount);
  }

  /// Formats a numeric [amount] without decimal places if whole number.
  static String formatCompact(double amount) {
    if (amount == amount.roundToDouble()) {
      return NumberFormat.currency(
        symbol: '₹',
        decimalDigits: 0,
        locale: 'en_IN',
      ).format(amount);
    }
    return format(amount);
  }
}
