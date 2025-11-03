import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/household.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

// SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden');
});

// Current household ID provider (persisted in SharedPreferences)
final currentHouseholdIdProvider = StateNotifierProvider<HouseholdIdNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HouseholdIdNotifier(prefs);
});

class HouseholdIdNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  static const String _key = 'current_household_id';

  HouseholdIdNotifier(this._prefs) : super(_prefs.getString(_key));

  Future<void> setHouseholdId(String? id) async {
    if (id == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, id);
    }
    state = id;
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
    state = null;
  }
}

// Current household stream
final currentHouseholdProvider = StreamProvider<Household?>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return Stream.value(null);
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchHousehold(householdId);
});

// User households stream
final userHouseholdsProvider = StreamProvider<List<Household>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchUserHouseholds(user.uid);
});
