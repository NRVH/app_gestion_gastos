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
  }) = _MonthHistory;

  factory MonthHistory.fromJson(Map<String, dynamic> json) =>
      _$MonthHistoryFromJson(json);
}
