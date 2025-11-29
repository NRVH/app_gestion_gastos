import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contribution.dart';
import '../services/firestore_service.dart';
import 'household_provider.dart';

// Contributions stream (limited to recent 50, filtered by current active month)
final contributionsProvider = StreamProvider<List<Contribution>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return Stream.value([]);
  
  // ✅ Ya no necesitamos filtrar aquí porque watchContributions ya filtra por currentActiveMonth
  // El filtrado se hace directamente en Firestore, más eficiente
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchContributions(householdId, limit: 50);
});
