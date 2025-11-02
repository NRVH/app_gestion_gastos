import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/household.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

// Current household ID provider (stored in SharedPreferences)
final currentHouseholdIdProvider = StateProvider<String?>((ref) => null);

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
