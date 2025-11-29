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
  
  // Helper para convertir Timestamp/DateTime/String a String ISO 8601
  String _convertToIsoString(dynamic value) {
    if (value == null) return DateTime.now().toIso8601String();
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is String) return value; // Ya es String ISO
    return DateTime.now().toIso8601String(); // Fallback
  }
  
  // TODO: OPTIMIZACIÓN FUTURA - Configurabilidad de test mode
  // En lugar de depender de una constante global (ENABLE_TEST_MODE), considerar:
  // 
  // Opción 1 - Inyección por constructor:
  //   FirestoreService(this._firestore, {bool isTestMode = false});
  //   
  // Opción 2 - Provider con configuración:
  //   final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  //     final isTestMode = ref.watch(appConfigProvider).isTestMode;
  //     return FirestoreService(_firestore, isTestMode: isTestMode);
  //   });
  //
  // Beneficios:
  // - Facilita testing unitario sin modificar constantes globales
  // - Permite diferentes instancias del servicio con configuraciones distintas
  // - Mejora la inyección de dependencias siguiendo principios SOLID
  //
  // RIESGO: MEDIO - Requiere actualizar todas las instanciaciones del servicio
  // PRIORIDAD: BAJA - El sistema actual funciona correctamente

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
      currentActiveMonth: month, // ✅ Inicializar con el mes actual
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
    // Obtener el mes ACTIVO del household para vincular el gasto (puede diferir del mes calendario)
    final householdDoc = await _firestore.collection('households').doc(householdId).get();
    final householdData = householdDoc.data();
    
    print('🔍 [addExpense] Household data: $householdData');
    print('🔍 [addExpense] currentActiveMonth: ${householdData?['currentActiveMonth']}');
    print('🔍 [addExpense] month: ${householdData?['month']}');
    
    final activeMonth = householdData?['currentActiveMonth'] as String? ?? householdData?['month'] as String?;
    
    print('💾 [addExpense] Guardando gasto con month: $activeMonth');
    print('💾 [addExpense] Amount: $amount, Category: $categoryName, Date: $date');

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
      month: activeMonth, // Vincular al mes ACTIVO del household
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

  Stream<List<Expense>> watchExpenses(String householdId, {int? limit, String? month}) async* {
    // 🧪 MODO TEST: Devolver gastos de prueba
    if (_isTestMode) {
      final expenses = MockData.getTestExpenses();
      yield limit != null ? expenses.take(limit).toList() : expenses;
      return;
    }
    
    // ✅ Si no se especifica mes, usar currentActiveMonth del household
    String? filterMonth = month;
    if (filterMonth == null) {
      print('🔍 [watchExpenses] Obteniendo household: $householdId');
      final householdDoc = await _firestore.collection('households').doc(householdId).get();
      final householdData = householdDoc.data();
      
      print('📦 [watchExpenses] Household data completo: $householdData');
      print('📦 [watchExpenses] currentActiveMonth: ${householdData?['currentActiveMonth']}');
      print('📦 [watchExpenses] month: ${householdData?['month']}');
      
      filterMonth = householdData?['currentActiveMonth'] as String?;
      
      // ✅ Si currentActiveMonth no existe, inicializarlo con el mes del household
      if (filterMonth == null) {
        filterMonth = householdData?['month'] as String?;
        if (filterMonth == null) {
          final now = DateTime.now();
          filterMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        }
        
        // Inicializar currentActiveMonth en Firestore
        print('⚠️ [watchExpenses] Inicializando currentActiveMonth: $filterMonth');
        await _firestore.collection('households').doc(householdId).update({
          'currentActiveMonth': filterMonth,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ [watchExpenses] Filtrando por MES ACTIVO: $filterMonth');
    } else {
      print('✅ [watchExpenses] Filtrando por mes especificado: $filterMonth');
    }
    
    var query = _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .where('month', isEqualTo: filterMonth);  // ✅ FILTRO POR MES

    yield* query.snapshots().map((snapshot) {
      print('🔥 [watchExpenses] Query ejecutada - Documentos encontrados: ${snapshot.docs.length}');
      
      var expenses = snapshot.docs
          .map((doc) {
            final data = doc.data();
            print('📄 [watchExpenses] Expense doc: ${doc.id}, month: ${data['month']}, amount: ${data['amount']}, date: ${data['date']}');
            return Expense.fromJson({'id': doc.id, ...data});
          })
          .toList();
      
      print('📊 [watchExpenses] Total expenses parseados: ${expenses.length}');
      
      // Ordenar por fecha en memoria (descendente)
      expenses.sort((a, b) => b.date.compareTo(a.date));
      
      // Aplicar límite si se especificó
      if (limit != null && expenses.length > limit) {
        expenses = expenses.sublist(0, limit);
        print('✂️ [watchExpenses] Aplicado límite: $limit, expenses finales: ${expenses.length}');
      }
      
      print('✅ [watchExpenses] Retornando ${expenses.length} expenses');
      return expenses;
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

  /// Fuerza el reseteo de todas las categorías a $0 (simula cierre de mes manual)
  Future<void> forceResetCategories(String householdId) async {
    print('🔶 [Firestore] FORZANDO CIERRE DE MES - Reseteando todas las categorías a \$0');
    
    // Obtener el household actual
    final householdDoc = await _firestore
        .collection('households')
        .doc(householdId)
        .get();
    
    final householdData = householdDoc.data();
    final currentMonth = householdData?['currentActiveMonth'] as String? ?? householdData?['month'] as String?;
    
    // Calcular el siguiente mes
    DateTime nextMonth;
    if (currentMonth != null) {
      final parts = currentMonth.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      nextMonth = DateTime(year, month + 1, 1);
    } else {
      // Si no existe currentActiveMonth, usar el mes siguiente al actual
      final now = DateTime.now();
      nextMonth = DateTime(now.year, now.month + 1, 1);
    }
    
    final nextMonthString = '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}';
    print('🔶 [Firestore] Actualizando mes activo a: $nextMonthString');
    
    // Obtener todas las categorías
    final categoriesSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories')
        .get();

    final batch = _firestore.batch();
    int resetCount = 0;

    // Actualizar el mes activo en el household
    batch.update(_firestore.collection('households').doc(householdId), {
      'currentActiveMonth': nextMonthString,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final categoryDoc in categoriesSnapshot.docs) {
      final currentData = categoryDoc.data();
      final categoryName = currentData['name'] as String? ?? 'Sin nombre';
      final monthlyLimit = (currentData['monthlyLimit'] as num?)?.toDouble() ?? 0.0;
      
      print('🔶 [Firestore] Reseteando categoría "$categoryName": spentThisMonth = \$0.00, balance = \$$monthlyLimit');
      
      batch.update(categoryDoc.reference, {
        'spentThisMonth': 0.0,
        'balance': monthlyLimit, // Balance = límite completo
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      resetCount++;
    }

    await batch.commit();
    print('✅ [Firestore] CIERRE DE MES FORZADO COMPLETADO - $resetCount categorías reseteadas');
    print('✅ [Firestore] Mes activo actualizado a: $nextMonthString');
  }

  /// Recalcula el spentThisMonth de todas las categorías basándose en los gastos reales
  Future<void> recalculateCategorySpending(String householdId) async {
    print('🔄 [Firestore] Iniciando recalculateCategorySpending para household: $householdId');
    
    // Obtener el mes activo del household (puede diferir del mes calendario)
    final householdDoc = await _firestore
        .collection('households')
        .doc(householdId)
        .get();
    
    final householdData = householdDoc.data();
    var activeMonth = householdData?['currentActiveMonth'] as String? ?? householdData?['month'] as String?;
    
    // CRÍTICO: Usar el mes activo del household, NO el mes del sistema
    if (activeMonth == null) {
      // Fallback: usar el mes actual del sistema
      final now = DateTime.now();
      activeMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      print('⚠️ [Firestore] currentActiveMonth no definido, usando mes del sistema: $activeMonth');
    } else {
      print('📅 [Firestore] Filtrando gastos por MES ACTIVO: $activeMonth');
    }
    
    
    // Obtener SOLO los gastos del mes ACTIVO (filtrar por campo 'month')
    final expensesSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .where('month', isEqualTo: activeMonth)
        .get();

    print('📊 [Firestore] Total de gastos del mes activo ($activeMonth) encontrados: ${expensesSnapshot.docs.length}');

    // Calcular el total por categoría SOLO DEL MES ACTUAL
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
      final monthlyLimit = (currentData['monthlyLimit'] as num?)?.toDouble() ?? 0.0;
      final newBalance = monthlyLimit - totalSpent;
      
      print('🔧 [Firestore] Actualizando categoría $categoryId: \$${currentSpent.toStringAsFixed(2)} -> \$${totalSpent.toStringAsFixed(2)} (Balance: \$${newBalance.toStringAsFixed(2)})');
      
      batch.update(
        categoryDoc.reference,
        {
          'spentThisMonth': totalSpent,
          'balance': newBalance,
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
    // ✅ Obtener el mes ACTIVO del household para vincular el ingreso
    final householdDoc = await _firestore.collection('households').doc(householdId).get();
    final householdData = householdDoc.data();
    final activeMonth = householdData?['currentActiveMonth'] as String? ?? householdData?['month'] as String?;
    
    print('📅 [Firestore] Agregando ingreso al mes ACTIVO: $activeMonth');

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
      month: activeMonth, // ✅ Vincular al mes ACTIVO
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
    String? month,
  }) async* {
    // 🧪 MODO TEST: Devolver contribuciones de prueba
    if (_isTestMode) {
      final contributions = MockData.getTestContributions();
      yield limit != null ? contributions.take(limit).toList() : contributions;
      return;
    }
    
    // ✅ Si no se especifica mes, usar currentActiveMonth del household
    String? filterMonth = month;
    if (filterMonth == null) {
      final householdDoc = await _firestore.collection('households').doc(householdId).get();
      final householdData = householdDoc.data();
      filterMonth = householdData?['currentActiveMonth'] as String?;
      
      // ✅ Si currentActiveMonth no existe, inicializarlo con el mes del household
      if (filterMonth == null) {
        filterMonth = householdData?['month'] as String?;
        if (filterMonth == null) {
          final now = DateTime.now();
          filterMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        }
        
        // Inicializar currentActiveMonth en Firestore
        print('⚠️ [watchContributions] Inicializando currentActiveMonth: $filterMonth');
        await _firestore.collection('households').doc(householdId).update({
          'currentActiveMonth': filterMonth,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      print('📅 [watchContributions] Filtrando por MES ACTIVO: $filterMonth');
    } else {
      print('📅 [watchContributions] Filtrando por mes especificado: $filterMonth');
    }
    
    var query = _firestore
        .collection('households')
        .doc(householdId)
        .collection('contributions')
        .where('month', isEqualTo: filterMonth);  // ✅ FILTRO POR MES

    yield* query.snapshots().map((snapshot) {
      var contributions = snapshot.docs
          .map((doc) => Contribution.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
      
      // Ordenar por fecha en memoria (descendente)
      contributions.sort((a, b) => b.date.compareTo(a.date));
      
      // Aplicar límite si se especificó
      if (limit != null && contributions.length > limit) {
        contributions = contributions.sublist(0, limit);
      }
      
      return contributions;
    });
  }

  // ==================== MONTH CLOSURE ====================

  Future<void> closeMonth({
    required String householdId,
    required Household household,
    required List<Member> members,
    required List<Category> categories,
  }) async {
    print('📅 [CloseMonth] Iniciando cierre de mes ${household.month}');

    // ✅ PROTECCIÓN: Verificar que el mes no haya sido cerrado previamente
    final historyRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('months')
        .doc(household.month);

    final historyExists = await historyRef.get();
    if (historyExists.exists) {
      throw Exception('⚠️ El mes ${household.month} ya fue cerrado anteriormente. No se puede cerrar dos veces.');
    }

    final batch = _firestore.batch();

    // Create month history with detailed category info
    final memberContributions = <String, double>{};
    for (final member in members) {
      memberContributions[member.uid] = member.contributedThisMonth;
    }

    final categorySpending = <String, double>{};
    final categoryDetails = <String, CategorySnapshot>{};
    
    for (final category in categories) {
      categorySpending[category.id] = category.spentThisMonth;
      
      // Guardar snapshot de la categoría (sin considerar balance acumulado)
      final balance = category.monthlyLimit - category.spentThisMonth;
      
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

    // Convertir categoryDetails manualmente para Firestore
    final categoryDetailsJson = <String, dynamic>{};
    categoryDetails.forEach((key, snapshot) {
      categoryDetailsJson[key] = snapshot.toJson();
    });

    // Crear JSON manualmente para evitar problemas de serialización
    final historyJson = {
      'id': household.month,
      'householdId': householdId,
      'monthTarget': household.monthTarget,
      'totalContributed': household.monthPool + household.carryOver,
      'totalSpent': categories.fold(0.0, (sum, cat) => sum + cat.spentThisMonth),
      'carryOverToNext': household.availableBalance,
      'closedAt': DateTime.now().toIso8601String(),
      'memberContributions': memberContributions,
      'categorySpending': categorySpending,
      'categoryDetails': categoryDetailsJson,
    };

    print('📝 [CloseMonth] JSON generado: ${historyJson.keys.join(", ")}');
    print('📊 [CloseMonth] CategoryDetails convertido: ${categoryDetailsJson.length} categorías');
    
    batch.set(historyRef, historyJson);
    print('✅ [CloseMonth] Histórico del mes guardado con ${categoryDetails.length} categorías');

    // Calcular el siguiente mes
    final currentDate = DateTime.now();
    final currentMonthParts = household.month.split('-');
    final year = int.parse(currentMonthParts[0]);
    final month = int.parse(currentMonthParts[1]);
    
    final nextMonthDate = DateTime(year, month + 1, 1);
    final nextMonth = '${nextMonthDate.year}-${nextMonthDate.month.toString().padLeft(2, '0')}';
    
    print('📅 [CloseMonth] Avanzando de ${household.month} a $nextMonth');

    // Update household for next month
    batch.update(
      _firestore.collection('households').doc(householdId),
      {
        'month': nextMonth,  // ✅ Avanzar al siguiente mes
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

    // Reset categories: NO acumular balance, simplemente resetear
    for (final category in categories) {
      // El balance de la categoría NO se acumula mes a mes
      // Solo se resetea el gasto a 0
      print('📊 [CloseMonth] ${category.name}:');
      print('   Límite mensual: \$${category.monthlyLimit}');
      print('   Gastado este mes: \$${category.spentThisMonth}');
      print('   → Reseteando para próximo mes (sin acumular balance)');
      
      batch.update(
        _firestore
            .collection('households')
            .doc(householdId)
            .collection('categories')
            .doc(category.id),
        {
          'spentThisMonth': 0.0,
          'accumulatedBalance': 0.0, // SIEMPRE 0, no acumular
        },
      );
    }

    await batch.commit();
    print('✅ [CloseMonth] Mes cerrado exitosamente');

    // 📦 Migrar registros sin mes al mes que se está cerrando
    print('📦 [CloseMonth] Migrando registros sin mes asignado...');
    await migrateUnassignedRecordsToMonth(householdId, household.month);
    print('✅ [CloseMonth] Migración de registros completada');

    // Limpieza automática de registros antiguos (mantener solo últimos 3 meses)
    print('🧹 [CloseMonth] Iniciando limpieza de registros antiguos...');
    await _cleanupOldRecords(householdId);
    print('✅ [CloseMonth] Limpieza completada');
  }

  /// Migra todos los registros sin campo 'month' al mes especificado
  /// Útil para registros legacy creados antes de implementar el campo month
  Future<void> migrateUnassignedRecordsToMonth(String householdId, String targetMonth) async {
    print('📦 [Migration] Iniciando migración de registros sin mes asignado...');
    print('📦 [Migration] Mes destino: $targetMonth');
    
    int expensesMigrated = 0;
    int contributionsMigrated = 0;

    // Migrar gastos
    final expensesSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .get();

    final expenseBatch = _firestore.batch();
    for (var doc in expensesSnapshot.docs) {
      final data = doc.data();
      if (data['month'] == null) {
        expenseBatch.update(doc.reference, {'month': targetMonth});
        expensesMigrated++;
      }
    }
    
    if (expensesMigrated > 0) {
      await expenseBatch.commit();
      print('✅ [Migration] Migrados $expensesMigrated gastos');
    }

    // Migrar ingresos
    final contributionsSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('contributions')
        .get();

    final contributionBatch = _firestore.batch();
    for (var doc in contributionsSnapshot.docs) {
      final data = doc.data();
      if (data['month'] == null) {
        contributionBatch.update(doc.reference, {'month': targetMonth});
        contributionsMigrated++;
      }
    }
    
    if (contributionsMigrated > 0) {
      await contributionBatch.commit();
      print('✅ [Migration] Migrados $contributionsMigrated ingresos');
    }

    print('🎉 [Migration] Migración completada: $expensesMigrated gastos + $contributionsMigrated ingresos');
  }

  /// Actualiza el mes actual del household (útil para avanzar manualmente)
  Future<void> updateHouseholdMonth(String householdId, String newMonth) async {
    print('📅 [UpdateMonth] Actualizando mes de household a: $newMonth');
    
    await _firestore.collection('households').doc(householdId).update({
      'month': newMonth,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ [UpdateMonth] Mes actualizado exitosamente');
  }

  /// Resetea accumulatedBalance de todas las categorías a 0
  /// Útil para limpiar datos legacy cuando se cambia la lógica
  Future<void> resetCategoryBalances(String householdId) async {
    print('🔄 [ResetBalances] Reseteando balances y gastos de categorías...');
    
    final categoriesSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('categories')
        .get();

    final batch = _firestore.batch();
    int count = 0;

    for (var doc in categoriesSnapshot.docs) {
      final data = doc.data();
      final accumulatedBalance = data['accumulatedBalance'] ?? 0.0;
      final spentThisMonth = data['spentThisMonth'] ?? 0.0;
      
      if (accumulatedBalance != 0.0 || spentThisMonth != 0.0) {
        batch.update(doc.reference, {
          'accumulatedBalance': 0.0,
          'spentThisMonth': 0.0,
        });
        count++;
        print('   📝 ${data['name']}: Gastado=\$${spentThisMonth} → \$0.00, Balance=\$${accumulatedBalance} → \$0.00');
      }
    }

    if (count > 0) {
      await batch.commit();
      print('✅ [ResetBalances] $count categorías reseteadas');
    } else {
      print('✅ [ResetBalances] Todas las categorías ya están en 0');
    }
  }

  /// Cuenta cuántos registros no tienen el campo month asignado
  Future<int> countUnassignedRecords(String householdId) async {
    int count = 0;

    // Contar gastos sin month
    final expensesSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .get();

    for (var doc in expensesSnapshot.docs) {
      if (doc.data()['month'] == null) count++;
    }

    // Contar ingresos sin month
    final contributionsSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('contributions')
        .get();

    for (var doc in contributionsSnapshot.docs) {
      if (doc.data()['month'] == null) count++;
    }

    return count;
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
        .handleError((error) {
          print('❌ [watchMonthHistory] Error en stream: $error');
        })
        .map((snapshot) {
      try {
        print('📅 [watchMonthHistory] Snapshot recibido con ${snapshot.docs.length} documentos');
        
        return snapshot.docs.map((doc) {
          try {
            final data = doc.data();
            print('📅 [watchMonthHistory] Procesando mes: ${doc.id}');
            
            // Convertir TODOS los Maps anidados (Firestore Web issue)
            
            // 1. memberContributions: Map<String, double>
            final memberContributionsRaw = data['memberContributions'];
            final Map<String, double> memberContributionsConverted = {};
            if (memberContributionsRaw != null && memberContributionsRaw is Map) {
              memberContributionsRaw.forEach((key, value) {
                memberContributionsConverted[key.toString()] = 
                    (value is num) ? value.toDouble() : 0.0;
              });
            }
            
            // 2. categorySpending: Map<String, double>
            final categorySpendingRaw = data['categorySpending'];
            final Map<String, double> categorySpendingConverted = {};
            if (categorySpendingRaw != null && categorySpendingRaw is Map) {
              categorySpendingRaw.forEach((key, value) {
                categorySpendingConverted[key.toString()] = 
                    (value is num) ? value.toDouble() : 0.0;
              });
            }
            
            // 3. categoryDetails: Map<String, CategorySnapshot>
            // CRÍTICO: Construir CategorySnapshot MANUALMENTE para evitar problemas con freezed en Web
            final categoryDetailsRaw = data['categoryDetails'];
            final Map<String, CategorySnapshot> categoryDetailsConverted = {};
            if (categoryDetailsRaw != null && categoryDetailsRaw is Map) {
              categoryDetailsRaw.forEach((key, value) {
                if (value is Map) {
                  // Crear CategorySnapshot directamente sin fromJson
                  final snapshot = CategorySnapshot(
                    id: value['id']?.toString() ?? '',
                    name: value['name']?.toString() ?? '',
                    icon: value['icon']?.toString() ?? '',
                    color: value['color']?.toString() ?? '',
                    monthlyLimit: (value['monthlyLimit'] is num) ? (value['monthlyLimit'] as num).toDouble() : 0.0,
                    spent: (value['spent'] is num) ? (value['spent'] as num).toDouble() : 0.0,
                    balance: (value['balance'] is num) ? (value['balance'] as num).toDouble() : 0.0,
                  );
                  categoryDetailsConverted[key.toString()] = snapshot;
                }
              });
            }
            
            // Crear MonthHistory directamente sin fromJson para evitar problemas con freezed en Web
            final result = MonthHistory(
              id: doc.id,
              householdId: data['householdId'],
              monthTarget: (data['monthTarget'] is num) ? (data['monthTarget'] as num).toDouble() : 0.0,
              totalContributed: (data['totalContributed'] is num) ? (data['totalContributed'] as num).toDouble() : 0.0,
              totalSpent: (data['totalSpent'] is num) ? (data['totalSpent'] as num).toDouble() : 0.0,
              carryOverToNext: (data['carryOverToNext'] is num) ? (data['carryOverToNext'] as num).toDouble() : 0.0,
              closedAt: (data['closedAt'] is Timestamp) 
                  ? (data['closedAt'] as Timestamp).toDate() 
                  : (data['closedAt'] is DateTime) 
                      ? data['closedAt'] as DateTime 
                      : DateTime.parse(data['closedAt'].toString()),
              memberContributions: memberContributionsConverted,
              categorySpending: categorySpendingConverted,
              categoryDetails: categoryDetailsConverted,
            );
            print('✅ [watchMonthHistory] MonthHistory creado exitosamente para ${doc.id}');
            return result;
          } catch (e, stackTrace) {
            print('❌ [watchMonthHistory] Error deserializando mes ${doc.id}: $e');
            print('📋 Stack trace: $stackTrace');
            print('📄 Data completa: ${doc.data()}');
            rethrow;
          }
        }).toList();
      } catch (e, stackTrace) {
        print('❌ [watchMonthHistory] Error en map general: $e');
        print('📋 Stack trace: $stackTrace');
        rethrow;
      }
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

      final data = doc.data()!;
      
      // Convertir TODOS los Maps anidados (Firestore Web issue)
      
      // 1. memberContributions: Map<String, double>
      final memberContributionsRaw = data['memberContributions'];
      final Map<String, double> memberContributionsConverted = {};
      if (memberContributionsRaw != null && memberContributionsRaw is Map) {
        memberContributionsRaw.forEach((key, value) {
          memberContributionsConverted[key.toString()] = 
              (value is num) ? value.toDouble() : 0.0;
        });
      }
      
      // 2. categorySpending: Map<String, double>
      final categorySpendingRaw = data['categorySpending'];
      final Map<String, double> categorySpendingConverted = {};
      if (categorySpendingRaw != null && categorySpendingRaw is Map) {
        categorySpendingRaw.forEach((key, value) {
          categorySpendingConverted[key.toString()] = 
              (value is num) ? value.toDouble() : 0.0;
        });
      }
      
      // 3. categoryDetails: Map<String, CategorySnapshot>
      final categoryDetailsRaw = data['categoryDetails'];
      final Map<String, CategorySnapshot> categoryDetailsConverted = {};
      if (categoryDetailsRaw != null && categoryDetailsRaw is Map) {
        categoryDetailsRaw.forEach((key, value) {
          if (value is Map) {
            final snapshot = CategorySnapshot(
              id: value['id']?.toString() ?? '',
              name: value['name']?.toString() ?? '',
              icon: value['icon']?.toString() ?? '',
              color: value['color']?.toString() ?? '',
              monthlyLimit: (value['monthlyLimit'] is num) ? (value['monthlyLimit'] as num).toDouble() : 0.0,
              spent: (value['spent'] is num) ? (value['spent'] as num).toDouble() : 0.0,
              balance: (value['balance'] is num) ? (value['balance'] as num).toDouble() : 0.0,
            );
            categoryDetailsConverted[key.toString()] = snapshot;
          }
        });
      }

      return MonthHistory(
        id: doc.id,
        householdId: data['householdId'],
        monthTarget: (data['monthTarget'] is num) ? (data['monthTarget'] as num).toDouble() : 0.0,
        totalContributed: (data['totalContributed'] is num) ? (data['totalContributed'] as num).toDouble() : 0.0,
        totalSpent: (data['totalSpent'] is num) ? (data['totalSpent'] as num).toDouble() : 0.0,
        carryOverToNext: (data['carryOverToNext'] is num) ? (data['carryOverToNext'] as num).toDouble() : 0.0,
        closedAt: (data['closedAt'] is Timestamp) 
            ? (data['closedAt'] as Timestamp).toDate() 
            : (data['closedAt'] is DateTime) 
                ? data['closedAt'] as DateTime 
                : DateTime.parse(data['closedAt'].toString()),
        memberContributions: memberContributionsConverted,
        categorySpending: categorySpendingConverted,
        categoryDetails: categoryDetailsConverted,
      );
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
        // Convertir el documento manualmente (mismo proceso que getRecentMonths)
        final data = doc.data();
        
        // Convertir Maps anidados
        final memberContributionsRaw = data['memberContributions'];
        final Map<String, double> memberContributionsConverted = {};
        if (memberContributionsRaw != null && memberContributionsRaw is Map) {
          memberContributionsRaw.forEach((key, value) {
            memberContributionsConverted[key.toString()] = 
                (value is num) ? value.toDouble() : 0.0;
          });
        }
        
        final categorySpendingRaw = data['categorySpending'];
        final Map<String, double> categorySpendingConverted = {};
        if (categorySpendingRaw != null && categorySpendingRaw is Map) {
          categorySpendingRaw.forEach((key, value) {
            categorySpendingConverted[key.toString()] = 
                (value is num) ? value.toDouble() : 0.0;
          });
        }
        
        final categoryDetailsRaw = data['categoryDetails'];
        final Map<String, CategorySnapshot> categoryDetailsConverted = {};
        if (categoryDetailsRaw != null && categoryDetailsRaw is Map) {
          categoryDetailsRaw.forEach((key, value) {
            if (value is Map) {
              final snapshot = CategorySnapshot(
                id: value['id']?.toString() ?? '',
                name: value['name']?.toString() ?? '',
                icon: value['icon']?.toString() ?? '',
                color: value['color']?.toString() ?? '',
                monthlyLimit: (value['monthlyLimit'] is num) ? (value['monthlyLimit'] as num).toDouble() : 0.0,
                spent: (value['spent'] is num) ? (value['spent'] as num).toDouble() : 0.0,
                balance: (value['balance'] is num) ? (value['balance'] as num).toDouble() : 0.0,
              );
              categoryDetailsConverted[key.toString()] = snapshot;
            }
          });
        }
        
        final history = MonthHistory(
          id: doc.id,
          householdId: data['householdId']?.toString() ?? '',
          monthTarget: (data['monthTarget'] is num) ? (data['monthTarget'] as num).toDouble() : 0.0,
          totalContributed: (data['totalContributed'] is num) ? (data['totalContributed'] as num).toDouble() : 0.0,
          totalSpent: (data['totalSpent'] is num) ? (data['totalSpent'] as num).toDouble() : 0.0,
          carryOverToNext: (data['carryOverToNext'] is num) ? (data['carryOverToNext'] as num).toDouble() : 0.0,
          closedAt: (data['closedAt'] is Timestamp) 
              ? (data['closedAt'] as Timestamp).toDate() 
              : DateTime.parse(data['closedAt'].toString()),
          memberContributions: memberContributionsConverted,
          categorySpending: categorySpendingConverted,
          categoryDetails: categoryDetailsConverted,
        );
        
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
      print('📅 [getRecentMonths] Obteniendo últimos $limit meses...');
      final snapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('months')
          .orderBy('closedAt', descending: true)
          .limit(limit)
          .get();

      print('📅 [getRecentMonths] Encontrados ${snapshot.docs.length} documentos');

      return snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          
          // Convertir TODOS los Maps anidados (Firestore Web issue)
          
          // 1. memberContributions: Map<String, double>
          final memberContributionsRaw = data['memberContributions'];
          final Map<String, double> memberContributionsConverted = {};
          if (memberContributionsRaw != null && memberContributionsRaw is Map) {
            memberContributionsRaw.forEach((key, value) {
              memberContributionsConverted[key.toString()] = 
                  (value is num) ? value.toDouble() : 0.0;
            });
          }
          
          // 2. categorySpending: Map<String, double>
          final categorySpendingRaw = data['categorySpending'];
          final Map<String, double> categorySpendingConverted = {};
          if (categorySpendingRaw != null && categorySpendingRaw is Map) {
            categorySpendingRaw.forEach((key, value) {
              categorySpendingConverted[key.toString()] = 
                  (value is num) ? value.toDouble() : 0.0;
            });
          }
          
          // 3. categoryDetails: Map<String, CategorySnapshot>
          // CRÍTICO: Construir CategorySnapshot MANUALMENTE para evitar problemas con freezed en Web
          final categoryDetailsRaw = data['categoryDetails'];
          final Map<String, CategorySnapshot> categoryDetailsConverted = {};
          if (categoryDetailsRaw != null && categoryDetailsRaw is Map) {
            categoryDetailsRaw.forEach((key, value) {
              if (value is Map) {
                // Crear CategorySnapshot directamente sin fromJson
                final snapshot = CategorySnapshot(
                  id: value['id']?.toString() ?? '',
                  name: value['name']?.toString() ?? '',
                  icon: value['icon']?.toString() ?? '',
                  color: value['color']?.toString() ?? '',
                  monthlyLimit: (value['monthlyLimit'] is num) ? (value['monthlyLimit'] as num).toDouble() : 0.0,
                  spent: (value['spent'] is num) ? (value['spent'] as num).toDouble() : 0.0,
                  balance: (value['balance'] is num) ? (value['balance'] as num).toDouble() : 0.0,
                );
                categoryDetailsConverted[key.toString()] = snapshot;
              }
            });
          }
          
          // Crear MonthHistory directamente sin fromJson para evitar problemas con freezed en Web
          final monthHistory = MonthHistory(
            id: doc.id,
            householdId: data['householdId'],
            monthTarget: (data['monthTarget'] is num) ? (data['monthTarget'] as num).toDouble() : 0.0,
            totalContributed: (data['totalContributed'] is num) ? (data['totalContributed'] as num).toDouble() : 0.0,
            totalSpent: (data['totalSpent'] is num) ? (data['totalSpent'] as num).toDouble() : 0.0,
            carryOverToNext: (data['carryOverToNext'] is num) ? (data['carryOverToNext'] as num).toDouble() : 0.0,
            closedAt: (data['closedAt'] is Timestamp) 
                ? (data['closedAt'] as Timestamp).toDate() 
                : (data['closedAt'] is DateTime) 
                    ? data['closedAt'] as DateTime 
                    : DateTime.parse(data['closedAt'].toString()),
            memberContributions: memberContributionsConverted,
            categorySpending: categorySpendingConverted,
            categoryDetails: categoryDetailsConverted,
          );
          
          print('✅ [getRecentMonths] MonthHistory creado: ${monthHistory.id}');
          print('   closedAt field: ${monthHistory.closedAt} (${monthHistory.closedAt.runtimeType})');
          print('   categoryDetails: ${monthHistory.categoryDetails.runtimeType}');
          
          return monthHistory;
        } catch (e, stackTrace) {
          print('❌ [getRecentMonths] Error procesando mes ${doc.id}: $e');
          print('📋 StackTrace: $stackTrace');
          rethrow;
        }
      }).toList();
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
