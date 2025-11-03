import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import 'household_provider.dart';

// Enums para el ordenamiento
enum CategorySortBy {
  alphabetical,
  recentlyAdded,
  amount,
  monthlyLimit,
}

enum SortDirection {
  ascending,
  descending,
}

// Modelo para las preferencias de ordenamiento
class SortPreferences {
  final CategorySortBy sortBy;
  final SortDirection sortDirection;

  const SortPreferences({
    required this.sortBy,
    required this.sortDirection,
  });

  Map<String, dynamic> toJson() {
    return {
      'sortBy': sortBy.name,
      'sortDirection': sortDirection.name,
    };
  }

  factory SortPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SortPreferences(
        sortBy: CategorySortBy.recentlyAdded,
        sortDirection: SortDirection.descending,
      );
    }

    return SortPreferences(
      sortBy: CategorySortBy.values.firstWhere(
        (e) => e.name == json['sortBy'],
        orElse: () => CategorySortBy.recentlyAdded,
      ),
      sortDirection: SortDirection.values.firstWhere(
        (e) => e.name == json['sortDirection'],
        orElse: () => SortDirection.descending,
      ),
    );
  }

  SortPreferences copyWith({
    CategorySortBy? sortBy,
    SortDirection? sortDirection,
  }) {
    return SortPreferences(
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }
}

// Provider para las preferencias de ordenamiento
final sortPreferencesProvider = StreamProvider<SortPreferences>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) {
    return Stream.value(const SortPreferences(
      sortBy: CategorySortBy.recentlyAdded,
      sortDirection: SortDirection.descending,
    ));
  }

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchSortPreferences(householdId).map((json) {
    return SortPreferences.fromJson(json);
  });
});

// Provider para actualizar las preferencias
final sortPreferencesNotifierProvider = Provider((ref) {
  return SortPreferencesNotifier(ref);
});

class SortPreferencesNotifier {
  final Ref ref;

  SortPreferencesNotifier(this.ref);

  Future<void> updateSortPreferences(
    CategorySortBy sortBy,
    SortDirection sortDirection,
  ) async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;

    final firestoreService = ref.read(firestoreServiceProvider);
    await firestoreService.updateSortPreferences(
      householdId,
      sortBy.name,
      sortDirection.name,
    );
  }
}
