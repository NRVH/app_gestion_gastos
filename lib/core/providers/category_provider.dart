import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import 'household_provider.dart';

// Categories stream
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return Stream.value([]);
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchCategories(householdId);
});
