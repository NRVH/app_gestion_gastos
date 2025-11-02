import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contribution.dart';
import '../services/firestore_service.dart';
import 'household_provider.dart';

// Contributions stream (limited to recent 50)
final contributionsProvider = StreamProvider<List<Contribution>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return Stream.value([]);
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchContributions(householdId, limit: 50);
});
