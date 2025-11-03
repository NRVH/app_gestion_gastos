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

  // Generar código de 6 dígitos único
  Future<String> _generateUniqueCode() async {
    int attempts = 0;
    const maxAttempts = 10;
    
    while (attempts < maxAttempts) {
      // Generar código de 6 dígitos (100000 a 999999)
      final code = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000)).toString();
      
      // Verificar si ya existe
      final doc = await _firestore.collection('households').doc(code).get();
      if (!doc.exists) {
        return code;
      }
      
      attempts++;
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    throw Exception('No se pudo generar un código único después de $maxAttempts intentos');
  }

  Future<String> createHousehold({
    required String name,
    required String month,
    required double monthTarget,
    required String ownerUid,
    required String ownerDisplayName,
    required double ownerShare,
  }) async {
    // Generar código único de 6 dígitos
    final code = await _generateUniqueCode();
    final householdRef = _firestore.collection('households').doc(code);
    
    final household = Household(
      id: code,
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
    return code;
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
      print('👥 [Firestore] Cargando ${snapshot.docs.length} miembros del household $householdId');
      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              print('👤 [Firestore] Miembro ${doc.id}: role="${data['role']}", displayName="${data['displayName']}"');
              
              // Normalizar el campo 'role' si existe pero es inválido
              if (data['role'] == null || 
                  (data['role'] is String && 
                   data['role'] != 'owner' && 
                   data['role'] != 'partner')) {
                print('⚠️ [Firestore] Miembro ${doc.id} tiene role inválido: "${data['role']}", usando "partner" por defecto');
                data['role'] = 'partner'; // Valor por defecto
              }
              
              final member = Member.fromJson(data);
              print('✅ [Firestore] Miembro ${doc.id} deserializado correctamente: ${member.displayName} (${member.role})');
              return member;
            } catch (e, stackTrace) {
              print('❌ [Firestore] Error al deserializar miembro ${doc.id}: $e');
              print('❌ [Firestore] Stack trace: $stackTrace');
              // Retornar un miembro por defecto en caso de error
              return Member(
                uid: doc.id,
                displayName: 'Usuario ${doc.id.substring(0, 5)}',
                role: MemberRole.partner,
                share: 0.5,
              );
            }
          })
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
      try {
        final data = doc.data()!;
        // Normalizar el campo 'role' si existe pero es inválido
        if (data['role'] == null || 
            (data['role'] is String && 
             data['role'] != 'owner' && 
             data['role'] != 'partner')) {
          print('⚠️ [Firestore] Miembro ${doc.id} tiene role inválido: ${data['role']}, usando "partner" por defecto');
          data['role'] = 'partner'; // Valor por defecto
        }
        return Member.fromJson(data);
      } catch (e) {
        print('❌ [Firestore] Error al deserializar miembro $uid: $e');
        // Retornar un miembro por defecto en caso de error
        return Member(
          uid: uid,
          displayName: 'Usuario $uid',
          role: MemberRole.partner,
          share: 0.5,
        );
      }
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
    print('🔔 [FirestoreService] updateFcmToken llamado');
    print('🔔 [FirestoreService] householdId: $householdId');
    print('🔔 [FirestoreService] uid: $uid');
    print('🔔 [FirestoreService] token: ${token.substring(0, 20)}...');
    
    try {
      final memberRef = _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(uid);
      
      // Verificar si el documento existe
      final memberDoc = await memberRef.get();
      if (!memberDoc.exists) {
        print('❌ [FirestoreService] El miembro $uid NO EXISTE en household $householdId');
        throw Exception('El miembro no existe');
      }
      
      print('✅ [FirestoreService] Miembro existe, actualizando tokens...');
      
      await memberRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
      
      print('✅ [FirestoreService] Token guardado exitosamente');
      
      // Verificar que se guardó correctamente
      final updatedDoc = await memberRef.get();
      final tokens = updatedDoc.data()?['fcmTokens'] as List?;
      print('🔔 [FirestoreService] Tokens actuales del miembro: ${tokens?.length ?? 0} tokens');
      
    } catch (e, stackTrace) {
      print('❌ [FirestoreService] Error al guardar token: $e');
      print('❌ [FirestoreService] Stack trace: $stackTrace');
      rethrow;
    }
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

  /// Elimina un miembro de la casa
  Future<void> removeMemberFromHousehold(String householdId, String uid) async {
    final batch = _firestore.batch();

    // Eliminar el documento del miembro
    final memberRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(uid);
    
    batch.delete(memberRef);

    // Actualizar la lista de miembros en el household
    batch.update(
      _firestore.collection('households').doc(householdId),
      {
        'members': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    // Recalcular porcentajes de los miembros restantes
    await recalculateMemberShares(householdId);
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

    await batch.commit();
    
    // Recalcular gastos de todas las categorías para mantener consistencia
    await recalculateCategorySpending(householdId);
    
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
    }

    await batch.commit();
    
    // Recalcular gastos de todas las categorías para mantener consistencia
    await recalculateCategorySpending(householdId);
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

    await batch.commit();
    
    // Recalcular gastos de todas las categorías para mantener consistencia
    await recalculateCategorySpending(householdId);
  }

  /// Recalcula el spentThisMonth de todas las categorías basándose en los gastos reales
  Future<void> recalculateCategorySpending(String householdId) async {
    print('🔄 [Firestore] Iniciando recalculateCategorySpending para household: $householdId');
    
    // Obtener todos los gastos
    final expensesSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .get();

    print('📊 [Firestore] Total de gastos encontrados: ${expensesSnapshot.docs.length}');

    // Calcular el total por categoría
    final Map<String, double> categoryTotals = {};
    
    for (final expenseDoc in expensesSnapshot.docs) {
      final data = expenseDoc.data();
      final categoryId = data['categoryId'] as String?;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      
      if (categoryId != null && categoryId.isNotEmpty) {
        categoryTotals[categoryId] = (categoryTotals[categoryId] ?? 0.0) + amount;
        print('💵 [Firestore] Categoría $categoryId: +\$${amount.toStringAsFixed(2)} = \$${categoryTotals[categoryId]!.toStringAsFixed(2)}');
      }
    }

    print('📈 [Firestore] Totales calculados por categoría:');
    categoryTotals.forEach((catId, total) {
      print('   - $catId: \$${total.toStringAsFixed(2)}');
    });

    // Obtener todas las categorías
    final categoriesSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories')
        .get();

    print('📂 [Firestore] Total de categorías encontradas: ${categoriesSnapshot.docs.length}');

    // Actualizar cada categoría con su total real
    final batch = _firestore.batch();
    
    for (final categoryDoc in categoriesSnapshot.docs) {
      final categoryId = categoryDoc.id;
      final totalSpent = categoryTotals[categoryId] ?? 0.0;
      final currentData = categoryDoc.data();
      final currentSpent = (currentData['spentThisMonth'] as num?)?.toDouble() ?? 0.0;
      
      print('🔧 [Firestore] Actualizando categoría $categoryId: \$${currentSpent.toStringAsFixed(2)} -> \$${totalSpent.toStringAsFixed(2)}');
      
      batch.update(
        categoryDoc.reference,
        {
          'spentThisMonth': totalSpent,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    // Actualizar el household para forzar refresh de streams
    batch.update(
      _firestore.collection('households').doc(householdId),
      {'updatedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
    print('✅ [Firestore] recalculateCategorySpending completado exitosamente');
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

    print('📅 [CloseMonth] Iniciando cierre de mes ${household.month}');

    // Create month history with detailed category info
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
    final categoryDetails = <String, CategorySnapshot>{};
    
    for (final category in categories) {
      categorySpending[category.id] = category.spentThisMonth;
      
      // Guardar snapshot completo de la categoría
      final totalAvailable = category.monthlyLimit + category.accumulatedBalance;
      final balance = totalAvailable - category.spentThisMonth;
      
      categoryDetails[category.id] = CategorySnapshot(
        id: category.id,
        name: category.name,
        icon: category.icon ?? '📁',
        color: category.color ?? '#808080',
        monthlyLimit: category.monthlyLimit,
        spent: category.spentThisMonth,
        balance: balance,
      );
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
      categoryDetails: categoryDetails,
    );

    batch.set(historyRef, history.toJson());
    print('✅ [CloseMonth] Histórico del mes guardado con ${categoryDetails.length} categorías');

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

    // Reset categories: calculate accumulated balance and reset spentThisMonth
    for (final category in categories) {
      // Balance de este mes = presupuesto total disponible - gastado
      final totalAvailable = category.monthlyLimit + category.accumulatedBalance;
      final currentBalance = totalAvailable - category.spentThisMonth;
      
      print('📊 [CloseMonth] ${category.name}:');
      print('   Límite mensual: \$${category.monthlyLimit}');
      print('   Balance acumulado anterior: \$${category.accumulatedBalance}');
      print('   Total disponible este mes: \$${totalAvailable}');
      print('   Gastado: \$${category.spentThisMonth}');
      print('   Balance actual: \$${currentBalance}');
      print('   → Nuevo balance acumulado para próximo mes: \$${currentBalance}');
      
      batch.update(
        _firestore
            .collection('households')
            .doc(householdId)
            .collection('categories')
            .doc(category.id),
        {
          'spentThisMonth': 0.0,
          'accumulatedBalance': currentBalance, // Acumular el sobrante/déficit
        },
      );
    }

    await batch.commit();
    print('✅ [CloseMonth] Mes cerrado exitosamente');

    // Limpieza automática de registros antiguos (mantener solo últimos 3 meses)
    print('🧹 [CloseMonth] Iniciando limpieza de registros antiguos...');
    await _cleanupOldRecords(householdId);
    print('✅ [CloseMonth] Limpieza completada');
  }

  /// Elimina gastos y aportaciones de hace más de 3 meses
  Future<void> _cleanupOldRecords(String householdId) async {
    try {
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
      
      print('📆 [Cleanup] Eliminando registros anteriores a: ${threeMonthsAgo.toString().substring(0, 10)}');

      // Eliminar gastos antiguos
      final expensesSnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('expenses')
          .where('date', isLessThan: Timestamp.fromDate(threeMonthsAgo))
          .get();

      if (expensesSnapshot.docs.isNotEmpty) {
        final expenseBatch = _firestore.batch();
        for (final doc in expensesSnapshot.docs) {
          expenseBatch.delete(doc.reference);
        }
        await expenseBatch.commit();
        print('🗑️ [Cleanup] Eliminados ${expensesSnapshot.docs.length} gastos antiguos');
      } else {
        print('✨ [Cleanup] No hay gastos antiguos para eliminar');
      }

      // Eliminar aportaciones antiguas
      final contributionsSnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('contributions')
          .where('date', isLessThan: Timestamp.fromDate(threeMonthsAgo))
          .get();

      if (contributionsSnapshot.docs.isNotEmpty) {
        final contributionBatch = _firestore.batch();
        for (final doc in contributionsSnapshot.docs) {
          contributionBatch.delete(doc.reference);
        }
        await contributionBatch.commit();
        print('🗑️ [Cleanup] Eliminadas ${contributionsSnapshot.docs.length} aportaciones antiguas');
      } else {
        print('✨ [Cleanup] No hay aportaciones antiguas para eliminar');
      }

      print('✅ [Cleanup] Limpieza completada exitosamente');
    } catch (e) {
      print('❌ [Cleanup] Error durante la limpieza: $e');
      // No lanzamos el error para no interrumpir el cierre de mes
    }
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

  /// Obtiene el histórico de un mes específico
  Future<MonthHistory?> getMonthHistory(String householdId, String monthId) async {
    try {
      final doc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('months')
          .doc(monthId)
          .get();

      if (!doc.exists) return null;

      return MonthHistory.fromJson({'id': doc.id, ...doc.data()!});
    } catch (e) {
      print('❌ [getMonthHistory] Error: $e');
      return null;
    }
  }

  /// Obtiene estadísticas agregadas de todos los tiempos
  Future<Map<String, dynamic>> getAllTimeStats(String householdId) async {
    try {
      print('📊 [AllTimeStats] Calculando estadísticas de todos los tiempos...');

      final snapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('months')
          .orderBy('closedAt', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalSpent': 0.0,
          'totalContributed': 0.0,
          'monthsTracked': 0,
          'categoryTotals': <String, Map<String, dynamic>>{},
          'averageMonthlySpending': 0.0,
        };
      }

      double totalSpent = 0.0;
      double totalContributed = 0.0;
      final categoryTotals = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final history = MonthHistory.fromJson({'id': doc.id, ...doc.data()});
        
        totalSpent += history.totalSpent;
        totalContributed += history.totalContributed;

        // Agregar por categoría
        for (final entry in history.categoryDetails.entries) {
          final categoryId = entry.key;
          final snapshot = entry.value;

          if (!categoryTotals.containsKey(categoryId)) {
            categoryTotals[categoryId] = {
              'name': snapshot.name,
              'icon': snapshot.icon,
              'color': snapshot.color,
              'totalSpent': 0.0,
              'monthsWithData': 0,
            };
          }

          categoryTotals[categoryId]!['totalSpent'] = 
              (categoryTotals[categoryId]!['totalSpent'] as double) + snapshot.spent;
          categoryTotals[categoryId]!['monthsWithData'] = 
              (categoryTotals[categoryId]!['monthsWithData'] as int) + 1;
        }
      }

      final monthsTracked = snapshot.docs.length;
      final averageMonthlySpending = monthsTracked > 0 ? totalSpent / monthsTracked : 0.0;

      print('✅ [AllTimeStats] Calculadas estadísticas de $monthsTracked meses');
      print('   Total gastado: \$$totalSpent');
      print('   Total aportado: \$$totalContributed');
      print('   Promedio mensual: \$$averageMonthlySpending');

      return {
        'totalSpent': totalSpent,
        'totalContributed': totalContributed,
        'monthsTracked': monthsTracked,
        'categoryTotals': categoryTotals,
        'averageMonthlySpending': averageMonthlySpending,
      };
    } catch (e) {
      print('❌ [AllTimeStats] Error: $e');
      return {
        'totalSpent': 0.0,
        'totalContributed': 0.0,
        'monthsTracked': 0,
        'categoryTotals': <String, Map<String, dynamic>>{},
        'averageMonthlySpending': 0.0,
      };
    }
  }

  /// Obtiene los últimos N meses de histórico
  Future<List<MonthHistory>> getRecentMonths(String householdId, {int limit = 3}) async {
    try {
      final snapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('months')
          .orderBy('closedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => MonthHistory.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      print('❌ [getRecentMonths] Error: $e');
      return [];
    }
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
      print('🏠 [JoinHouseholdWithCode] Usuario ya es miembro, verificando array members...');
      
      // Verificar si está en el array members del household principal
      final householdDoc = await _firestore.collection('households').doc(householdId).get();
      final members = List<String>.from(householdDoc.data()?['members'] ?? []);
      
      if (!members.contains(uid)) {
        print('🏠 [JoinHouseholdWithCode] ⚠️ Usuario NO está en array members, agregando...');
        await _firestore.collection('households').doc(householdId).update({
          'members': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('🏠 [JoinHouseholdWithCode] ✅ Usuario agregado al array members');
      }
      
      return householdId;
    }

    print('🏠 [JoinHouseholdWithCode] Agregando nuevo miembro: $uid');
    
    // Usar batch para actualizar tanto el array members como el documento del miembro
    final batch = _firestore.batch();
    
    // 1. Actualizar el array members en el documento principal del household
    batch.update(
      _firestore.collection('households').doc(householdId),
      {
        'members': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    
    // 2. Crear el documento del miembro en la subcolección
    batch.set(
      _firestore.collection('households').doc(householdId).collection('members').doc(uid),
      {
        'uid': uid,
        'displayName': displayName,
        'role': 'partner',
        'email': '',
        'share': 0.5,
        'monthlySalary': 0.0,
        'contributedThisMonth': 0.0,
        'fcmTokens': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    
    await batch.commit();
    print('🏠 [JoinHouseholdWithCode] ✅ Miembro agregado exitosamente');

    // Recalcular porcentajes
    await recalculateMemberShares(householdId);
    
    return householdId;
  }

  /// Elimina todos los datos del usuario del sistema
  /// ADVERTENCIA: Esta acción es irreversible
  Future<void> deleteUserData(String uid) async {
    try {
      // 1. Buscar todos los households donde el usuario es miembro
      final householdsSnapshot = await _firestore
          .collection('households')
          .where('members', arrayContains: uid)
          .get();

      final batch = _firestore.batch();

      for (var householdDoc in householdsSnapshot.docs) {
        final householdId = householdDoc.id;
        final householdData = householdDoc.data();
        final members = List<String>.from(householdData['members'] ?? []);

        // Si es el único miembro o el owner, eliminar todo el household
        if (members.length == 1 && members.contains(uid)) {
          // Eliminar el household completo incluyendo subcollections
          await _deleteHouseholdCompletely(householdId, batch);
        } else {
          // Si hay más miembros, solo eliminar al usuario
          // Eliminar el miembro de la subcollection
          batch.delete(
            _firestore
                .collection('households')
                .doc(householdId)
                .collection('members')
                .doc(uid),
          );

          // Remover uid del array de members
          batch.update(
            _firestore.collection('households').doc(householdId),
            {
              'members': FieldValue.arrayRemove([uid]),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );

          // Si era el owner, transferir ownership al primer miembro restante
          final memberDoc = await _firestore
              .collection('households')
              .doc(householdId)
              .collection('members')
              .doc(uid)
              .get();

          if (memberDoc.exists &&
              memberDoc.data()?['role'] == 'owner' &&
              members.length > 1) {
            final newOwnerUid = members.firstWhere((id) => id != uid);
            batch.update(
              _firestore
                  .collection('households')
                  .doc(householdId)
                  .collection('members')
                  .doc(newOwnerUid),
              {'role': 'owner'},
            );
          }

          // Recalcular porcentajes después de eliminar al miembro
          // Esto se hará después de commit
        }
      }

      await batch.commit();

      // Recalcular porcentajes para los households donde se removió al usuario
      for (var householdDoc in householdsSnapshot.docs) {
        final householdData = householdDoc.data();
        final members = List<String>.from(householdData['members'] ?? []);
        
        if (members.length > 1) {
          await recalculateMemberShares(householdDoc.id);
        }
      }

      print('✅ Datos del usuario eliminados exitosamente');
    } catch (e) {
      print('❌ Error eliminando datos del usuario: $e');
      rethrow;
    }
  }

  /// Método auxiliar para eliminar un household completamente
  Future<void> _deleteHouseholdCompletely(String householdId, WriteBatch batch) async {
    // Eliminar members
    final membersSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();
    
    for (var doc in membersSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Eliminar categories
    final categoriesSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories')
        .get();
    
    for (var doc in categoriesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Eliminar expenses
    final expensesSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .get();
    
    for (var doc in expensesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Eliminar contributions
    final contributionsSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('contributions')
        .get();
    
    for (var doc in contributionsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Eliminar months
    final monthsSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('months')
        .get();
    
    for (var doc in monthsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Finalmente, eliminar el household
    batch.delete(_firestore.collection('households').doc(householdId));
  }

  // ==================== SORT PREFERENCES ====================

  Stream<Map<String, dynamic>?> watchSortPreferences(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      return data?['sortPreferences'] as Map<String, dynamic>?;
    });
  }

  Future<void> updateSortPreferences(
    String householdId,
    String sortBy,
    String sortDirection,
  ) async {
    await _firestore.collection('households').doc(householdId).update({
      'sortPreferences': {
        'sortBy': sortBy,
        'sortDirection': sortDirection,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
