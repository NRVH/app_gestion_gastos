import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';
import 'household_provider.dart';

// Expenses stream (limited to recent 50)
final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return Stream.value([]);
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchExpenses(householdId, limit: 50);
});
