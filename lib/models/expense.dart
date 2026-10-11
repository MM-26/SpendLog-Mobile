class ExpenseModel {
  final int id;
  final String description;
  final double amount;
  final String category;
  final DateTime expenseDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  ExpenseModel copyWith({
    int? id,
    String? description,
    double? amount,
    String? category,
    DateTime? expenseDate,
    String? notes,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}