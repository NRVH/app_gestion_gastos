import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'household_provider.dart';

// Household members stream
final householdMembersProvider = StreamProvider<List<Member>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null) return Stream.value([]);
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchHouseholdMembers(householdId);
});

// Current user member data stream
final currentMemberProvider = StreamProvider<Member?>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);
  final user = ref.watch(currentUserProvider);
  
  if (householdId == null || user == null) return Stream.value(null);
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchMember(householdId, user.uid);
});
