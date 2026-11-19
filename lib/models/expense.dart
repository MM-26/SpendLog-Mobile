class ExpenseModel {
  final int id;
  final String description;
  final double amount;
  final String category;
  final DateTime expenseDate;
  final String? notes;
  final String type; // 'expense' or 'income' (Bible v1.16 Decision 10)
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.notes,
    this.type = 'expense',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  ExpenseModel copyWith({
    int? id,
    String? description,
    double? amount,
    String? category,
    DateTime? expenseDate,
    String? notes,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      expenseDate: expenseDate ?? this.expenseDate,
      notes: notes ?? this.notes,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}