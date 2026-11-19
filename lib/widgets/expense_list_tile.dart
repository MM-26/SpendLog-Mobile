import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import 'category_badge.dart';

/// Expense card — fully theme-aware (light & dark).
///
/// Tapping the tile opens Edit Expense. Delete has moved to the Edit Expense
/// screen's AppBar (v1.1 Decision 10, step 1) — the 3-dot menu is removed.
/// Amounts use GPay-style colors: neutral for expenses, green with '+' for income.
class ExpenseListTile extends StatelessWidget {
  final String description;
  final double amount;
  final String category;
  final DateTime expenseDate;
  final String? notes;
  final String type; // 'expense' or 'income' (Bible v1.16 Decision 10)
  final VoidCallback? onTap;
  // onEdit and onDelete are kept so callers don't need to change, but the
  // 3-dot popup menu is removed from the tile UI per v1.1 Decision 10.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExpenseListTile({
    super.key,
    required this.description,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.notes,
    this.type = 'expense',
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surfaceColor = cs.surface;
    final borderColor = isDark ? const Color(0xFF2E3147) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? const Color(0xFFF1F3FF) : const Color(0xFF181A2A);
    final textSecondary = isDark ? const Color(0xFF9AA5C4) : const Color(0xFF6B7280);
    final textMuted = isDark ? const Color(0xFF5C6685) : const Color(0xFF9CA3AF);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Category Icon
                CategoryBadge(category: category),
                const SizedBox(width: 14),

                // Description & Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            DateFormatter.formatShort(expenseDate),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                          if (notes != null && notes!.trim().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('•', style: TextStyle(fontSize: 12, color: textMuted)),
                            const SizedBox(width: 6),
                            Icon(Icons.notes_rounded, size: 13, color: textMuted),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount (GPay-style per Bible v1.16 Decision 10)
                Text(
                  type == 'income'
                      ? '+${CurrencyFormatter.format(amount)}'
                      : CurrencyFormatter.format(amount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: type == 'income' ? AppColors.creditGreen : textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),

                // v1.1 Decision 10: 3-dot popup menu removed.
                // Delete has moved to the Edit Expense screen's AppBar.
              ],
            ),
          ),
        ),
      ),
    );
  }
}
