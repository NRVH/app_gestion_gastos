import 'package:freezed_annotation/freezed_annotation.dart';

part 'monthly_summary.freezed.dart';
part 'monthly_summary.g.dart';

@freezed
class MonthlySummary with _$MonthlySummary {
  const factory MonthlySummary({
    required String id, // formato: YYYY-MM
    required double totalSpent,
    required double totalContributed,
    required Map<String, CategoryMonthlySummary> categories,
    required DateTime createdAt,
  }) = _MonthlySummary;

  factory MonthlySummary.fromJson(Map<String, dynamic> json) =>
      _$MonthlySummaryFromJson(json);
}

@freezed
class CategoryMonthlySummary with _$CategoryMonthlySummary {
  const factory CategoryMonthlySummary({
    required String categoryId,
    required String categoryName,
    required String categoryIcon,
    required double spent,
    required double monthlyLimit,
    required double balance, // monthlyLimit - spent
  }) = _CategoryMonthlySummary;

  factory CategoryMonthlySummary.fromJson(Map<String, dynamic> json) =>
      _$CategoryMonthlySummaryFromJson(json);
}
