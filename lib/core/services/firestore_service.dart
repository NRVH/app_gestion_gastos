import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/household.dart';
import '../models/member.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/contribution.dart';
import '../models/month_history.dart';
import 'auth_service.dart';
import 'mock_data.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(FirebaseFirestore.instance);
});

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService(this._firestore);
  
  // 🧪 Verificar si estamos en modo TEST
  bool get _isTestMode => ENABLE_TEST_MODE;

  // ==================== HOUSEHOLD ====================

  Future<String> createHousehold({
    required String name,
    required String month,
    required double monthTarget,
    required String ownerUid,
    required String ownerDisplayName,
    required double ownerShare,
  }) async {
    final householdRef = _firestore.collection('households').doc();
    final household = Household(
      id: householdRef.id,
      name: name,
      month: month,
      monthTarget: monthTarget,
      members: [ownerUid],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final member = Member(
      uid: ownerUid,
      displayName: ownerDisplayName,
      role: MemberRole.owner,
      share: ownerShare,
      joinedAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.set(householdRef, household.toJson());
    batch.set(
      householdRef.collection('members').doc(ownerUid),
      member.toJson(),
    );

    await batch.commit();
    return householdRef.id;
  }

  Future<void> joinHousehold({
    required String householdId,
    required String uid,
    required String displayName,
    required double share,
  }) async {
    final householdRef = _firestore.collection('households').doc(householdId);
    
    final member = Member(
      uid: uid,
      displayName: displayName,
      role: MemberRole.partner,
      share: share,
      joinedAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.update(householdRef, {
      'members': FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      householdRef.collection('members').doc(uid),
      member.toJson(),
    );

    await batch.commit();
  }

  Stream<Household?> watchHousehold(String householdId) {
    // 🧪 MODO TEST: Devolver household de prueba
    if (_isTestMode) {
      return Stream.value(MockData.getTestHousehold());
    }
    
    return _firestore
        .collection('households')
        .doc(householdId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Household.fromJson({'id': doc.id, ...doc.data()!});
    });
  }

  Stream<List<Household>> watchUserHouseholds(String uid) {
    // 🧪 MODO TEST: Devolver lista con household de prueba
    if (_isTestMode) {
      return Stream.value([MockData.getTestHousehold()]);
    }
    
    return _firestore
        .collection('households')
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Household.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    });
  }

  Future<void> updateHousehold(String householdId, Map<String, dynamic> data) async {
    await _firestore.collection('households').doc(householdId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteHousehold(String householdId) async {
    final batch = _firestore.batch();
    
    // Eliminar todas las subcollections (categories, expenses, contributions, members)
    final categories = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories')
        .get();
    for (var doc in categories.docs) {
      batch.delete(doc.reference);
    }
    
    final expenses = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .get();
    for (var doc in expenses.docs) {
      batch.delete(doc.reference);
    }
    
    final contributions = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('contributions')
        .get();
    for (var doc in contributions.docs) {
      batch.delete(doc.reference);
    }
    
    final members = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();
    for (var doc in members.docs) {
      batch.delete(doc.reference);
    }
    
    // Finalmente eliminar el household
    batch.delete(_firestore.collection('households').doc(householdId));
    
    await batch.commit();
  }

  // ==================== MEMBERS ====================

  Stream<List<Member>> watchHouseholdMembers(String householdId) {
    // 🧪 MODO TEST: Devolver miembros de prueba
    if (_isTestMode) {
      return Stream.value(MockData.getTestMembers());
    }
    
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Member.fromJson(doc.data()))
          .toList();
    });
  }

  Stream<Member?> watchMember(String householdId, String uid) {
    // 🧪 MODO TEST: Devolver miembro del usuario actual
    if (_isTestMode) {
      return Stream.value(MockData.getTestMembers().firstWhere(
        (m) => m.uid == uid,
        orElse: () => MockData.getTestMembers().first,
      ));
    }
    
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Member.fromJson(doc.data()!);
    });
  }

  Future<void> updateMember(
    String householdId,
    String uid,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(uid)
        .update(data);
  }

  Future<void> updateFcmToken(
    String householdId,
    String uid,
    String token,
  ) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(uid)
        .update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  /// Recalcula los porcentajes de aportación de todos los miembros
  /// basándose en sus salarios mensuales
  Future<void> recalculateMemberShares(String householdId) async {
    // Obtener todos los miembros
    final membersSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();

    if (membersSnapshot.docs.isEmpty) return;

    // Calcular el total de salarios
    double totalSalary = 0;
    for (var doc in membersSnapshot.docs) {
      final salary = (doc.data()['monthlySalary'] as num?)?.toDouble() ?? 0;
      totalSalary += salary;
    }

    // Si no hay salarios, distribuir equitativamente
    if (totalSalary <= 0) {
      final equalShare = 1.0 / membersSnapshot.docs.length;
      final batch = _firestore.batch();
      
      for (var doc in membersSnapshot.docs) {
        batch.update(doc.reference, {'share': equalShare});
      }
      
      await batch.commit();
      return;
    }

    // Calcular y actualizar porcentajes basados en salarios
    final batch = _firestore.batch();
    
    for (var doc in membersSnapshot.docs) {
      final salary = (doc.data()['monthlySalary'] as num?)?.toDouble() ?? 0;
      final share = salary / totalSalary;
      batch.update(doc.reference, {'share': share});
    }
    
    await batch.commit();
  }

  // ==================== CATEGORIES ====================

  Future<String> createCategory({
    required String householdId,
    required String name,
    required double monthlyLimit,
    int? dueDay,
    bool canGoNegative = false,
    String? icon,
    String? color,
  }) async {
    final categoryRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories')
        .doc();

    final category = Category(
      id: categoryRef.id,
      name: name,
      monthlyLimit: monthlyLimit,
      dueDay: dueDay,
      canGoNegative: canGoNegative,
      icon: icon,
      color: color,
      createdAt: DateTime.now(),
    );

    await categoryRef.set(category.toJson());
    
    // Recalcular meta mensual del household
    await _recalculateMonthTarget(householdId);
    
    return categoryRef.id;
  }

  Stream<List<Category>> watchCategories(String householdId) {
    // 🧪 MODO TEST: Devolver categorías de prueba
    if (_isTestMode) {
      return Stream.value(MockData.getTestCategories());
    }
    
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Category.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    });
  }

  Future<void> updateCategory(
    String householdId,
    String categoryId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories')
        .doc(categoryId)
        .update(data);
    
    // Recalcular meta mensual del household
    await _recalculateMonthTarget(householdId);
  }

  Future<void> deleteCategory(String householdId, String categoryId) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories')
        .doc(categoryId)
        .delete();
    
    // Recalcular meta mensual del household
    await _recalculateMonthTarget(householdId);
  }

  /// Recalcula la meta mensual del household sumando todos los monthlyLimit de las categorías
  Future<void> _recalculateMonthTarget(String householdId) async {
    final categoriesSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories')
        .get();

    double totalTarget = 0.0;
    for (var doc in categoriesSnapshot.docs) {
      final monthlyLimit = (doc.data()['monthlyLimit'] as num?)?.toDouble() ?? 0;
      totalTarget += monthlyLimit;
    }

    await _firestore.collection('households').doc(householdId).update({
      'monthTarget': totalTarget,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== EXPENSES ====================

  Future<String> addExpense({
    required String householdId,
    required String byUid,
    required String byDisplayName,
    required String categoryId,
    required String categoryName,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    final expenseRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .doc();

    final expense = Expense(
      id: expenseRef.id,
      by: byUid,
      byDisplayName: byDisplayName,
      categoryId: categoryId,
      categoryName: categoryName,
      amount: amount,
      date: date,
      note: note,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    // Add expense document
    batch.set(expenseRef, expense.toJson());

    // Update household monthPool
    batch.update(
      _firestore.collection('households').doc(householdId),
      {
        'monthPool': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // Update category spentThisMonth
    batch.update(
      _firestore
          .collection('households')
          .doc(householdId)
          .collection('categories')
          .doc(categoryId),
      {'spentThisMonth': FieldValue.increment(amount)},
    );

    await batch.commit();
    return expenseRef.id;
  }

  Stream<List<Expense>> watchExpenses(String householdId, {int? limit}) {
    // 🧪 MODO TEST: Devolver gastos de prueba
    if (_isTestMode) {
      final expenses = MockData.getTestExpenses();
      return Stream.value(limit != null ? expenses.take(limit).toList() : expenses);
    }
    
    var query = _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .orderBy('date', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Expense.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    });
  }

  Future<void> updateExpense(
    String householdId,
    String expenseId,
    String categoryId,
    Map<String, dynamic> data,
    double amountDiff,
  ) async {
    final batch = _firestore.batch();

    // Update expense
    batch.update(
      _firestore
          .collection('households')
          .doc(householdId)
          .collection('expenses')
          .doc(expenseId),
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
    );

    // Update household monthPool
    if (amountDiff != 0) {
      batch.update(
        _firestore.collection('households').doc(householdId),
        {
          'monthPool': FieldValue.increment(-amountDiff),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Update category spentThisMonth
      batch.update(
        _firestore
            .collection('households')
            .doc(householdId)
            .collection('categories')
            .doc(categoryId),
        {'spentThisMonth': FieldValue.increment(amountDiff)},
      );
    }

    await batch.commit();
  }

  Future<void> deleteExpense(
    String householdId,
    String expenseId,
    String categoryId,
    double amount,
  ) async {
    final batch = _firestore.batch();

    // Delete expense
    batch.delete(
      _firestore
          .collection('households')
          .doc(householdId)
          .collection('expenses')
          .doc(expenseId),
    );

    // Revert household monthPool
    batch.update(
      _firestore.collection('households').doc(householdId),
      {
        'monthPool': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // Revert category spentThisMonth
    batch.update(
      _firestore
          .collection('households')
          .doc(householdId)
          .collection('categories')
          .doc(categoryId),
      {'spentThisMonth': FieldValue.increment(-amount)},
    );

    await batch.commit();
  }

  // ==================== CONTRIBUTIONS ====================

  Future<String> addContribution({
    required String householdId,
    required String byUid,
    required String byDisplayName,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    final contributionRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('contributions')
        .doc();

    final contribution = Contribution(
      id: contributionRef.id,
      by: byUid,
      byDisplayName: byDisplayName,
      amount: amount,
      date: date,
      note: note,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    // Add contribution document
    batch.set(contributionRef, contribution.toJson());

    // Update household monthPool
    batch.update(
      _firestore.collection('households').doc(householdId),
      {
        'monthPool': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // Update member contributedThisMonth
    batch.update(
      _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(byUid),
      {'contributedThisMonth': FieldValue.increment(amount)},
    );

    await batch.commit();
    return contributionRef.id;
  }

  Future<void> updateContribution(
    String householdId,
    String contributionId,
    String byUid,
    Map<String, dynamic> data,
    double amountDiff,
  ) async {
    final batch = _firestore.batch();

    // Update contribution
    batch.update(
      _firestore
          .collection('households')
          .doc(householdId)
          .collection('contributions')
          .doc(contributionId),
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
    );

    // Update household monthPool and member contributedThisMonth
    if (amountDiff != 0) {
      batch.update(
        _firestore.collection('households').doc(householdId),
        {
          'monthPool': FieldValue.increment(amountDiff),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        _firestore
            .collection('households')
            .doc(householdId)
            .collection('members')
            .doc(byUid),
        {'contributedThisMonth': FieldValue.increment(amountDiff)},
      );
    }

    await batch.commit();
  }

  Future<void> deleteContribution(
    String householdId,
    String contributionId,
    String byUid,
    double amount,
  ) async {
    final batch = _firestore.batch();

    // Delete contribution
    batch.delete(
      _firestore
          .collection('households')
          .doc(householdId)
          .collection('contributions')
          .doc(contributionId),
    );

    // Revert household monthPool
    batch.update(
      _firestore.collection('households').doc(householdId),
      {
        'monthPool': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // Revert member contributedThisMonth
    batch.update(
      _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(byUid),
      {'contributedThisMonth': FieldValue.increment(-amount)},
    );

    await batch.commit();
  }

  Stream<List<Contribution>> watchContributions(
    String householdId, {
    int? limit,
  }) {
    // 🧪 MODO TEST: Devolver contribuciones de prueba
    if (_isTestMode) {
      final contributions = MockData.getTestContributions();
      return Stream.value(limit != null ? contributions.take(limit).toList() : contributions);
    }
    
    var query = _firestore
        .collection('households')
        .doc(householdId)
        .collection('contributions')
        .orderBy('date', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Contribution.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    });
  }

  // ==================== MONTH CLOSURE ====================

  Future<void> closeMonth({
    required String householdId,
    required Household household,
    required List<Member> members,
    required List<Category> categories,
  }) async {
    final batch = _firestore.batch();

    // Create month history
    final historyRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('months')
        .doc(household.month);

    final memberContributions = <String, double>{};
    for (final member in members) {
      memberContributions[member.uid] = member.contributedThisMonth;
    }

    final categorySpending = <String, double>{};
    for (final category in categories) {
      categorySpending[category.id] = category.spentThisMonth;
    }

    final history = MonthHistory(
      id: household.month,
      householdId: householdId,
      monthTarget: household.monthTarget,
      totalContributed: household.monthPool + household.carryOver,
      totalSpent: categories.fold(0.0, (sum, cat) => sum + cat.spentThisMonth),
      carryOverToNext: household.availableBalance,
      closedAt: DateTime.now(),
      memberContributions: memberContributions,
      categorySpending: categorySpending,
    );

    batch.set(historyRef, history.toJson());

    // Update household for next month
    batch.update(
      _firestore.collection('households').doc(householdId),
      {
        'carryOver': household.availableBalance,
        'monthPool': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    // Reset all members' contributedThisMonth
    for (final member in members) {
      batch.update(
        _firestore
            .collection('households')
            .doc(householdId)
            .collection('members')
            .doc(member.uid),
        {'contributedThisMonth': 0.0},
      );
    }

    // Reset all categories' spentThisMonth
    for (final category in categories) {
      batch.update(
        _firestore
            .collection('households')
            .doc(householdId)
            .collection('categories')
            .doc(category.id),
        {'spentThisMonth': 0.0},
      );
    }

    await batch.commit();
  }

  Stream<List<MonthHistory>> watchMonthHistory(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('months')
        .orderBy('closedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MonthHistory.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    });
  }

  // ==================== INVITATION SYSTEM ====================

  /// Genera un código de invitación de 6 dígitos para el household
  Future<String> generateInviteCode(String householdId) async {
    // Generar código aleatorio de 6 dígitos
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    final code = random.toString().padLeft(6, '0');

    // Guardar código en el household con timestamp de expiración (24 horas)
    await _firestore.collection('households').doc(householdId).update({
      'inviteCode': code,
      'inviteCodeExpiry': DateTime.now().add(const Duration(hours: 24)),
    });

    return code;
  }

  /// Busca un household por código de invitación
  Future<String?> findHouseholdByInviteCode(String code) async {
    // Consulta simplificada sin índice compuesto
    final snapshot = await _firestore
        .collection('households')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    
    // Validar expiración en código
    final doc = snapshot.docs.first;
    final data = doc.data();
    final expiry = data['inviteCodeExpiry'];
    
    if (expiry != null) {
      final expiryDate = (expiry is Timestamp) 
          ? expiry.toDate() 
          : DateTime.parse(expiry.toString());
      
      if (expiryDate.isBefore(DateTime.now())) {
        return null; // Código expirado
      }
    }
    
    return doc.id;
  }

  /// Une un usuario a un household usando el código de invitación
  Future<String> joinHouseholdWithCode(String code, String uid, String displayName) async {
    final householdId = await findHouseholdByInviteCode(code);
    
    if (householdId == null) {
      throw Exception('Código inválido o expirado');
    }

    // Verificar si el usuario ya es miembro
    final existingMember = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(uid)
        .get();

    if (existingMember.exists) {
      // Ya es miembro, solo retornar el householdId para que pueda acceder
      return householdId;
    }

    // Agregar usuario como miembro
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(uid)
        .set({
      'uid': uid,
      'displayName': displayName,
      'email': '', // Se actualizará después
      'share': 0.5, // Por defecto 50%
      'monthlySalary': 0.0,
      'contributedThisMonth': 0.0,
      'fcmTokens': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Recalcular porcentajes
    await recalculateMemberShares(householdId);
    
    return householdId;
  }
}
