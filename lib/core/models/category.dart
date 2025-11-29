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
    @Default(0.0) double accumulatedBalance, // Balance acumulado del mes anterior
    @Default(null) int? dueDay, // Day of month (1-31) for priority display
    @Default(false) bool canGoNegative,
    @Default(null) String? icon, // Icon name or emoji
    @Default(null) String? color, // Hex color code
    @Default(null) DateTime? createdAt,
    @Default(0) int sortOrder, // Custom order for manual sorting
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}

extension CategoryExtension on Category {
  // Presupuesto disponible este mes (SOLO el límite mensual, sin acumular)
  // El accumulatedBalance ya no se usa en la lógica, siempre es 0
  double get totalAvailable => monthlyLimit;
  
  // Presupuesto restante este mes
  double get remainingBudget => (monthlyLimit - spentThisMonth).clamp(0.0, double.infinity);
  
  double get progress {
    if (monthlyLimit == 0) return 0.0;
    return (spentThisMonth / monthlyLimit).clamp(0.0, 2.0); // Allow 200% to show excess
  }
  
  bool get isOverBudget => spentThisMonth > monthlyLimit;
  
  // Optimización: evitar recalcular monthlyLimit múltiples veces
  bool get isNearLimit {
    return spentThisMonth >= monthlyLimit * 0.8 && spentThisMonth <= monthlyLimit;
  }
  
  // Optimización: usar lógica más eficiente con un solo cálculo de comparación
  CategoryStatus get status {
    if (spentThisMonth > monthlyLimit) return CategoryStatus.overBudget;
    if (spentThisMonth >= monthlyLimit * 0.8) return CategoryStatus.nearLimit;
    return CategoryStatus.ok;
  }
}

enum CategoryStatus {
  ok,
  nearLimit,
  overBudget,
}
