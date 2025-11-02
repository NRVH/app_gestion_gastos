import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required double monthlyLimit,
    @Default(0.0) double spentThisMonth,
    @Default(null) int? dueDay, // Day of month (1-31) for priority display
    @Default(false) bool canGoNegative,
    @Default(null) String? icon, // Icon name or emoji
    @Default(null) String? color, // Hex color code
    @Default(null) DateTime? createdAt,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}

extension CategoryExtension on Category {
  double get remainingBudget => (monthlyLimit - spentThisMonth).clamp(0.0, double.infinity);
  
  double get progress {
    if (monthlyLimit == 0) return 0.0;
    return (spentThisMonth / monthlyLimit).clamp(0.0, 2.0); // Allow 200% to show excess
  }
  
  bool get isOverBudget => spentThisMonth > monthlyLimit;
  
  bool get isNearLimit => spentThisMonth >= monthlyLimit * 0.8 && !isOverBudget;
  
  CategoryStatus get status {
    if (isOverBudget) return CategoryStatus.overBudget;
    if (isNearLimit) return CategoryStatus.nearLimit;
    return CategoryStatus.ok;
  }
}

enum CategoryStatus {
  ok,
  nearLimit,
  overBudget,
}
