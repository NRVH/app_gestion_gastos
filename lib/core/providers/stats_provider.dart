import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/month_history.dart';
import '../services/firestore_service.dart';
import 'household_provider.dart';

/// Provider para el histórico de meses
final monthHistoryProvider = StreamProvider<List<MonthHistory>>((ref) {
  final householdAsync = ref.watch(currentHouseholdProvider);
  final household = householdAsync.value;

  if (household == null) {
    return Stream.value([]);
  }

  return ref.watch(firestoreServiceProvider).watchMonthHistory(household.id);
});

/// Provider para obtener un mes específico
final getMonthHistoryProvider = FutureProvider.family<MonthHistory?, String>((ref, monthId) async {
  final householdAsync = ref.watch(currentHouseholdProvider);
  final household = householdAsync.value;

  if (household == null) return null;

  return ref.read(firestoreServiceProvider).getMonthHistory(household.id, monthId);
});

/// Provider para estadísticas de todos los tiempos
final allTimeStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final householdAsync = ref.watch(currentHouseholdProvider);
  final household = householdAsync.value;

  if (household == null) {
    return {
      'totalSpent': 0.0,
      'totalContributed': 0.0,
      'monthsTracked': 0,
      'categoryTotals': <String, Map<String, dynamic>>{},
      'averageMonthlySpending': 0.0,
    };
  }

  return ref.read(firestoreServiceProvider).getAllTimeStats(household.id);
});

/// Provider para los últimos N meses
final recentMonthsProvider = FutureProvider.family<List<MonthHistory>, int>((ref, limit) async {
  final householdAsync = ref.watch(currentHouseholdProvider);
  final household = householdAsync.value;

  if (household == null) return [];

  return ref.read(firestoreServiceProvider).getRecentMonths(household.id, limit: limit);
});
