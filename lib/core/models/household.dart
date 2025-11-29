import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'household.freezed.dart';
part 'household.g.dart';

// Convertidor personalizado para Timestamp de Firestore
class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  @override
  dynamic toJson(DateTime? dateTime) => dateTime;
}

@freezed
class Household with _$Household {
  const factory Household({
    required String id,
    required String name,
    required String month, // Format: "2025-11"
    required double monthTarget,
    @Default(0.0) double monthPool,
    @Default(0.0) double carryOver,
    required List<String> members, // List of user UIDs
    @Default(null) String? inviteCode,
    @TimestampConverter() @Default(null) DateTime? inviteCodeExpiry,
    @TimestampConverter() @Default(null) DateTime? createdAt,
    @TimestampConverter() @Default(null) DateTime? updatedAt,
    String? currentActiveMonth, // Format: "2025-12" - Mes activo para conteo de gastos (puede diferir del mes calendario)
  }) = _Household;

  factory Household.fromJson(Map<String, dynamic> json) =>
      _$HouseholdFromJson(json);
}

extension HouseholdExtension on Household {
  // Balance total disponible = aportaciones de este mes + colchón del mes anterior
  double get availableBalance => carryOver + monthPool;
  
  // Progreso de APORTACIÓN (solo basado en monthPool, sin contar carryOver)
  // El carryOver es un colchón, no reduce la meta de aportación
  double get progress {
    if (monthTarget == 0) return 0.0;
    return (monthPool / monthTarget).clamp(0.0, 1.0);
  }
  
  // Están "on track" si han aportado lo suficiente (sin contar carryOver)
  bool get isOnTrack => monthPool >= monthTarget;
}
