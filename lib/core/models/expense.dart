import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense.freezed.dart';
part 'expense.g.dart';

@freezed
class Expense with _$Expense {
  const factory Expense({
    required String id,
    required String by, // User UID
    required String categoryId,
    required double amount,
    required DateTime date,
    @Default('') String note,
    @Default(null) String? byDisplayName,
    @Default(null) String? categoryName,
    @Default(null) DateTime? createdAt,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}
