import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/expense_list_tile.dart';
import '../../widgets/hero_total_card.dart';
import '../add_expense/add_expense_screen.dart';

/// Screen displaying all expenses for a specific archived month dynamically queried from SQLite.
class MonthDetailScreen extends ConsumerWidget {
  final int year;
  final int month;
  final double total;
  final int count;

  const MonthDetailScreen({
    super.key,
    required this.year,
    required this.month,
    required this.total,
    required this.count,
  });

  void _handleEdit(BuildContext context, WidgetRef ref, ExpenseModel expense) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          isEditing: true,
          isFromMonthDetail: true,
          expenseId: expense.id,
          initialMonthYear: DateTime(year, month),
          initialDescription: expense.description,
          initialAmount: expense.amount,
          initialCategory: expense.category,
          initialDate: expense.expenseDate,
          initialNotes: expense.notes,
          initialType: expense.type,
          initialCreatedAt: expense.createdAt,
          onDeletePressed: () => ref.read(expenseActionsProvider).deleteExpense(expense.id),
        ),
      ),
    );
  }

  void _openAddExpenseToMonth(BuildContext context, DateTime monthDate) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          isFromMonthDetail: true,
          initialMonthYear: monthDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthDate = DateTime(year, month);
    final monthTitle = DateFormatter.formatMonthYear(monthDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F1117) : const Color(0xFFF8F9FE);
    final textPrimary = isDark ? const Color(0xFFF1F3FF) : const Color(0xFF181A2A);
    final textSecondary = isDark ? const Color(0xFF9AA5C4) : const Color(0xFF6B7280);
    final chipBg = isDark ? const Color(0xFF252837) : const Color(0xFFF1F3F9);

    final monthExpensesAsync = ref.watch(monthExpensesProvider((year: year, month: month)));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monthTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: textPrimary,
              ),
            ),
            Text(
              'Detailed archive for $monthTitle',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddExpenseToMonth(context, monthDate),
        tooltip: 'Add to $monthTitle',
        elevation: 4,
        shape: const CircleBorder(),
        child: Ink(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
          ),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
      body: monthExpensesAsync.when(
        loading: () => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading records for $monthTitle...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load month records',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$err',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(monthExpensesProvider((year: year, month: month)));
                    ref.invalidate(monthTotalProvider((year: year, month: month)));
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (expenses) {
          double incomeTotal = 0.0;
          double spentTotal = 0.0;
          for (final exp in expenses) {
            if (exp.isIncome) {
              incomeTotal += exp.amount;
            } else {
              spentTotal += exp.amount;
            }
          }
          final netBalance = incomeTotal - spentTotal;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Month Total Card (3-in-1 layout)
                HeroTotalCard(
                  title: incomeTotal > 0
                      ? '$monthTitle Balance'
                      : 'Total for $monthTitle',
                  amount: incomeTotal > 0 ? netBalance : spentTotal,
                  incomeAmount: incomeTotal,
                  spentAmount: spentTotal,
                  subtitle: '${expenses.length} ${expenses.length == 1 ? "entry" : "entries"} in this archive',
                  icon: Icons.calendar_today_rounded,
                ),

                const SizedBox(height: 28),

                // Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Archived Records',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${expenses.length} records',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Empty or Records List
                if (expenses.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1F2E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E3147) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.inbox_rounded,
                            size: 28,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No records in this archive',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Use the button below to log an expense for $monthTitle.',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _openAddExpenseToMonth(context, monthDate),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text('Add Expense to $monthTitle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final item = expenses[index];
                      return ExpenseListTile(
                        description: item.description,
                        amount: item.amount,
                        category: item.category,
                        expenseDate: item.expenseDate,
                        notes: item.notes,
                        type: item.type,
                        onTap: () => _handleEdit(context, ref, item),
                      );
                    },
                  ),

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}
