import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import 'household_provider.dart';

// Categories stream
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  print('📂 [CategoriesProvider] Provider inicializado/reinicializado para household: $householdId');
  
  if (householdId == null) {
    print('⚠️ [CategoriesProvider] No hay householdId, retornando lista vacía');
    return Stream.value([]);
  }
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  final stream = firestoreService.watchCategories(householdId);
  
  return stream.map((categories) {
    print('📊 [CategoriesProvider] Stream emitió ${categories.length} categorías:');
    for (var cat in categories) {
      print('   - ${cat.name}: sortOrder=${cat.sortOrder}, Gastado=\$${cat.spentThisMonth.toStringAsFixed(2)}, Límite=\$${cat.monthlyLimit.toStringAsFixed(2)}');
    }
    return categories;
  });
});
