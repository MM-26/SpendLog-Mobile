import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';

/// Single shared screen for adding or editing expenses (Bible §5.2).
///
/// Adapts behavior based on entry context:
/// - [isFromMonthDetail] = false (From Home): Date bounded between 1st of current month and today.
/// - [isFromMonthDetail] = true (From Month Detail): Date bounded entirely within [initialMonthYear].
/// - [isEditing] = true: Pre-populates fields for modifying an existing expense.
class AddExpenseScreen extends ConsumerStatefulWidget {
  final bool isFromMonthDetail;
  final DateTime? initialMonthYear;
  final bool isEditing;
  final int? expenseId;
  final String? initialDescription;
  final double? initialAmount;
  final String? initialCategory;
  final DateTime? initialDate;
  final String? initialNotes;
  final DateTime? initialCreatedAt;

  const AddExpenseScreen({
    super.key,
    this.isFromMonthDetail = false,
    this.initialMonthYear,
    this.isEditing = false,
    this.expenseId,
    this.initialDescription,
    this.initialAmount,
    this.initialCategory,
    this.initialDate,
    this.initialNotes,
    this.initialCreatedAt,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isSaving = false;

  final List<String> _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    //'Health',
    'Stationery',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _amountController = TextEditingController(
      text: widget.initialAmount != null
          ? (widget.initialAmount! % 1 == 0
              ? widget.initialAmount!.toInt().toString()
              : widget.initialAmount!.toString())
          : '',
    );
    _notesController = TextEditingController(
      text: widget.initialNotes ?? '',
    );

    _selectedCategory = widget.initialCategory ?? 'Food';

    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    } else if (widget.isFromMonthDetail && widget.initialMonthYear != null) {
      // Entry Context 2 — From Month Detail: defaults to 1st day of selected month
      _selectedDate = DateTime(
        widget.initialMonthYear!.year,
        widget.initialMonthYear!.month,
        1,
      );
    } else {
      // Entry Context 1 — From Home: defaults to today
      _selectedDate = now;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Calculates allowed date picker bounds per Bible §5.2.
  DateTimeRange _getDatePickerBounds() {
    final now = DateTime.now();

    if (widget.isFromMonthDetail && widget.initialMonthYear != null) {
      final targetYear = widget.initialMonthYear!.year;
      final targetMonth = widget.initialMonthYear!.month;
      final firstDay = DateTime(targetYear, targetMonth, 1);
      final lastDay = DateTime(targetYear, targetMonth + 1, 0);

      final effectiveLastDay = (targetYear == now.year && targetMonth == now.month)
          ? now
          : lastDay;

      return DateTimeRange(start: firstDay, end: effectiveLastDay);
    } else {
      // Entry Context 1 — From Home: 1st day of current month -> today
      final firstDayCurrentMonth = DateTime(now.year, now.month, 1);
      return DateTimeRange(start: firstDayCurrentMonth, end: now);
    }
  }

  Future<void> _pickDate() async {
    final bounds = _getDatePickerBounds();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(bounds.start)
          ? bounds.start
          : (_selectedDate.isAfter(bounds.end) ? bounds.end : _selectedDate),
      firstDate: bounds.start,
      lastDate: bounds.end,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: AppColors.textPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);
      final description = _descriptionController.text.trim();
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      try {
        if (widget.isEditing && widget.expenseId != null) {
          final updatedExpense = ExpenseModel(
            id: widget.expenseId!,
            description: description,
            amount: amount,
            category: _selectedCategory,
            expenseDate: _selectedDate,
            notes: notes,
            createdAt: widget.initialCreatedAt ?? DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await ref.read(expenseActionsProvider).updateExpense(updatedExpense);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Expense "$description" updated'),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop();
          }
        } else {
          await ref.read(expenseActionsProvider).addExpense(
            description: description,
            amount: amount,
            category: _selectedCategory,
            expenseDate: _selectedDate,
            notes: notes,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Expense "$description" logged'),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving expense: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _getDatePickerBounds();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Adaptive colors
    final bgColor = isDark ? const Color(0xFF0F1117) : const Color(0xFFF8F9FE);
    final surfaceColor = isDark ? const Color(0xFF1C1F2E) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF2E3147) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? const Color(0xFFF1F3FF) : const Color(0xFF181A2A);
    final textSecondary = isDark ? const Color(0xFF9AA5C4) : const Color(0xFF6B7280);
    final textMuted = isDark ? const Color(0xFF5C6685) : const Color(0xFF9CA3AF);

    final title = widget.isEditing
        ? 'Edit Expense'
        : (widget.isFromMonthDetail
            ? 'Add to ${DateFormatter.formatMonthYear(widget.initialMonthYear!)}'
            : 'Add Expense');

    final buttonText = widget.isEditing ? 'Update Expense' : 'Save Expense';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Amount Input Card ─────────────────────────────────────
              FormField<String>(
                initialValue: _amountController.text,
                validator: (_) {
                  final text = _amountController.text.trim();
                  if (text.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(text);
                  if (amount == null || amount <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  if (amount > 10000000) {
                    return 'Amount cannot exceed ₹1,00,00,000';
                  }
                  return null;
                },
                builder: (field) {
                  final hasError = field.hasError;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasError ? AppColors.error : borderColor,
                            width: hasError ? 1.6 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: hasError
                                  ? AppColors.error.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: isDark ? 0.18 : 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AMOUNT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: hasError ? AppColors.error : textSecondary,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '₹',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: hasError ? AppColors.error : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                    ],
                                    onChanged: (val) {
                                      field.didChange(val);
                                    },
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      hintStyle: TextStyle(color: textMuted),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (hasError) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            field.errorText ?? '',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── Description Input ─────────────────────────────────────
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: textPrimary),
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'e.g. Grocery Shopping, Fuel, Dinner',
                  prefixIcon: Icon(Icons.edit_note_rounded, color: textSecondary),
                  filled: true,
                  fillColor: surfaceColor,
                  counterText: '',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.error, width: 1.8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description cannot be empty';
                  }
                  if (value.trim().length > 100) {
                    return 'Description cannot exceed 100 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 22),

              // ── Category Selector ─────────────────────────────────────
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  final style = AppColors.getCategoryStyle(category);

                  // In dark mode, unselected chip uses a dark surface; selected uses the
                  // category background color at reduced opacity so it still reads dark.
                  final chipBg = isSelected
                      ? (isDark
                          ? style.color.withValues(alpha: 0.18)
                          : style.backgroundColor)
                      : surfaceColor;
                  final chipBorder = isSelected ? style.color : borderColor;
                  final iconColor = isSelected ? style.color : textSecondary;
                  final labelColor = isSelected ? style.color : textPrimary;

                  return InkWell(
                    onTap: () => setState(() => _selectedCategory = category),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: chipBorder,
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(style.icon, size: 18, color: iconColor),
                          const SizedBox(width: 8),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: labelColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              // ── Date Picker Field ─────────────────────────────────────
              Text(
                'Expense Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormatter.formatFull(_selectedDate),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, color: textMuted),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  widget.isFromMonthDetail
                      ? 'Restricted to ${DateFormatter.formatMonthYear(widget.initialMonthYear!)}'
                      : 'Allowed: ${DateFormatter.formatDayMonth(bounds.start)} – Today',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ),

              const SizedBox(height: 22),

              // ── Notes Input ───────────────────────────────────────────
              Text(
                'Notes (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Additional details or memo...',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: surfaceColor,
                  counterText: '',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.error),
                  ),
                ),
                validator: (value) {
                  if (value != null && value.length > 500) {
                    return 'Notes cannot exceed 500 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // ── Save / Update Button ──────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              buttonText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
