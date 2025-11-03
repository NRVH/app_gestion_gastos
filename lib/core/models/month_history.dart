import 'package:freezed_annotation/freezed_annotation.dart';

part 'month_history.freezed.dart';
part 'month_history.g.dart';

@freezed
class MonthHistory with _$MonthHistory {
  const factory MonthHistory({
    required String id, // Format: "2025-11"
    required String householdId,
    required double monthTarget,
    required double totalContributed,
    required double totalSpent,
    required double carryOverToNext,
    required DateTime closedAt,
    @Default({}) Map<String, double> memberContributions, // uid -> amount
    @Default({}) Map<String, double> categorySpending, // categoryId -> amount
    @Default({}) Map<String, CategorySnapshot> categoryDetails, // Detalles completos de categorías
  }) = _MonthHistory;

  factory MonthHistory.fromJson(Map<String, dynamic> json) =>
      _$MonthHistoryFromJson(json);
}

@freezed
class CategorySnapshot with _$CategorySnapshot {
  const factory CategorySnapshot({
    required String id,
    required String name,
    required String icon,
    required String color,
    required double monthlyLimit,
    required double spent,
    required double balance,
  }) = _CategorySnapshot;

  factory CategorySnapshot.fromJson(Map<String, dynamic> json) =>
      _$CategorySnapshotFromJson(json);
}
