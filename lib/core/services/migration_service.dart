import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member.dart';

/// Servicio para migrar datos cuando sea necesario
class MigrationService {
  final FirebaseFirestore _firestore;

  MigrationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Arregla miembros que no tienen el campo 'role' definido
  /// Esto debe ejecutarse una sola vez para cada household
  Future<void> fixMembersWithoutRole(String householdId) async {
    try {
      final membersSnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .get();

      final batch = _firestore.batch();
      int fixedCount = 0;

      for (var doc in membersSnapshot.docs) {
        final data = doc.data();
        
        // Si no tiene el campo 'role', agregarlo
        if (!data.containsKey('role')) {
          // Determinar el rol basándose en si es el owner o partner
          // El owner suele ser el primero o el que tiene más tiempo
          final role = data['uid'] == membersSnapshot.docs.first.id
              ? 'owner'
              : 'partner';

          batch.update(doc.reference, {'role': role});
          fixedCount++;
          print('✅ Arreglado miembro ${data['displayName']} - rol: $role');
        }
      }

      if (fixedCount > 0) {
        await batch.commit();
        print('✨ Se arreglaron $fixedCount miembros');
      } else {
        print('✅ Todos los miembros ya tienen el campo role');
      }
    } catch (e) {
      print('❌ Error al arreglar miembros: $e');
      rethrow;
    }
  }

  /// Migración completa para asegurar que todos los campos requeridos existan
  Future<void> migrateHouseholdMembers(String householdId) async {
    try {
      print('🔄 Iniciando migración de miembros para household: $householdId');
      
      final membersSnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .get();

      if (membersSnapshot.docs.isEmpty) {
        print('⚠️  No hay miembros en este household');
        return;
      }

      final batch = _firestore.batch();
      int migratedCount = 0;

      for (var doc in membersSnapshot.docs) {
        final data = doc.data();
        final updates = <String, dynamic>{};

        // Agregar campos faltantes con valores por defecto
        if (!data.containsKey('role')) {
          updates['role'] = 'partner'; // Por defecto partner, el owner debe identificarse manualmente
        }
        
        if (!data.containsKey('monthlySalary')) {
          updates['monthlySalary'] = 0.0;
        }
        
        if (!data.containsKey('contributedThisMonth')) {
          updates['contributedThisMonth'] = 0.0;
        }
        
        if (!data.containsKey('fcmTokens')) {
          updates['fcmTokens'] = [];
        }
        
        if (!data.containsKey('share')) {
          updates['share'] = 0.5; // 50% por defecto
        }

        if (!data.containsKey('email')) {
          updates['email'] = '';
        }

        if (updates.isNotEmpty) {
          batch.update(doc.reference, updates);
          migratedCount++;
          print('✅ Migrado miembro: ${data['displayName']}');
          print('   Campos agregados: ${updates.keys.join(", ")}');
        }
      }

      if (migratedCount > 0) {
        await batch.commit();
        print('✨ Migración completada: $migratedCount miembros actualizados');
      } else {
        print('✅ No se necesitaron migraciones');
      }
    } catch (e) {
      print('❌ Error durante la migración: $e');
      rethrow;
    }
  }
}
