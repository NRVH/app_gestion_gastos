import '../models/household.dart';
import '../models/member.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/contribution.dart';

// 🧪 DATOS DE PRUEBA para modo TEST
class MockData {
  static const String testHouseholdId = 'test-household-id';
  static const String testUserId = 'test-user-id';
  static const String testPartnerId = 'test-partner-id';

  // Household de prueba
  static Household getTestHousehold() {
    final now = DateTime.now();
    return Household(
      id: testHouseholdId,
      name: 'Casa de Prueba',
      month: '${now.year}-${now.month.toString().padLeft(2, '0')}', // Format: "2025-11"
      monthTarget: 76025.0,
      monthPool: 45000.0,
      carryOver: 0.0,
      members: [testUserId, testPartnerId],
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      updatedAt: DateTime.now(),
    );
  }

  // Miembros de prueba
  static List<Member> getTestMembers() {
    return [
      Member(
        uid: testUserId,
        displayName: 'Usuario Prueba',
        role: MemberRole.owner,
        monthlySalary: 76700.0, // Tu salario mensual
        share: 0.7373, // 73.73% (calculado automáticamente: 76700 / 104000)
        contributedThisMonth: 33000.0,
        joinedAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      Member(
        uid: testPartnerId,
        displayName: 'Pareja Prueba',
        role: MemberRole.partner,
        monthlySalary: 27300.0, // Salario de tu esposa
        share: 0.2627, // 26.27% (calculado automáticamente: 27300 / 104000)
        contributedThisMonth: 12000.0,
        joinedAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];
  }

  // Categorías de prueba
  static List<Category> getTestCategories() {
    return [
      Category(
        id: 'cat-1',
        name: '🏠 Renta',
        monthlyLimit: 18000.0,
        spentThisMonth: 18000.0,
        dueDay: 5,
        canGoNegative: false,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      Category(
        id: 'cat-2',
        name: '🍔 Comida',
        monthlyLimit: 12000.0,
        spentThisMonth: 8500.0,
        canGoNegative: false,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      Category(
        id: 'cat-3',
        name: '🚗 Transporte',
        monthlyLimit: 3000.0,
        spentThisMonth: 2200.0,
        canGoNegative: false,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      Category(
        id: 'cat-4',
        name: '⚡ Servicios',
        monthlyLimit: 2500.0,
        spentThisMonth: 2400.0,
        dueDay: 10,
        canGoNegative: false,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      Category(
        id: 'cat-5',
        name: '💊 Salud',
        monthlyLimit: 2000.0,
        spentThisMonth: 850.0,
        canGoNegative: false,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      Category(
        id: 'cat-6',
        name: '🎉 Entretenimiento',
        monthlyLimit: 3000.0,
        spentThisMonth: 1200.0,
        canGoNegative: true,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];
  }

  // Gastos de prueba
  static List<Expense> getTestExpenses() {
    final now = DateTime.now();
    return [
      Expense(
        id: 'exp-1',
        categoryId: 'cat-1',
        by: testUserId,
        amount: 18000.0,
        date: DateTime(now.year, now.month, 5),
        note: 'Pago de renta mensual',
        byDisplayName: 'Usuario Prueba',
        categoryName: '🏠 Renta',
        createdAt: DateTime(now.year, now.month, 5),
      ),
      Expense(
        id: 'exp-2',
        categoryId: 'cat-2',
        by: testPartnerId,
        amount: 450.0,
        date: DateTime(now.year, now.month, now.day - 2),
        note: 'Súper del fin de semana',
        byDisplayName: 'Pareja Prueba',
        categoryName: '🍔 Comida',
        createdAt: DateTime(now.year, now.month, now.day - 2),
      ),
      Expense(
        id: 'exp-3',
        categoryId: 'cat-3',
        by: testUserId,
        amount: 500.0,
        date: DateTime(now.year, now.month, now.day - 1),
        note: 'Gasolina',
        byDisplayName: 'Usuario Prueba',
        categoryName: '🚗 Transporte',
        createdAt: DateTime(now.year, now.month, now.day - 1),
      ),
      Expense(
        id: 'exp-4',
        categoryId: 'cat-4',
        by: testUserId,
        amount: 1200.0,
        date: DateTime(now.year, now.month, 10),
        note: 'Luz y agua',
        byDisplayName: 'Usuario Prueba',
        categoryName: '⚡ Servicios',
        createdAt: DateTime(now.year, now.month, 10),
      ),
      Expense(
        id: 'exp-5',
        categoryId: 'cat-6',
        by: testPartnerId,
        amount: 800.0,
        date: DateTime(now.year, now.month, now.day - 3),
        note: 'Cine y cena',
        byDisplayName: 'Pareja Prueba',
        categoryName: '🎉 Entretenimiento',
        createdAt: DateTime(now.year, now.month, now.day - 3),
      ),
    ];
  }

  // Contribuciones de prueba
  static List<Contribution> getTestContributions() {
    final now = DateTime.now();
    return [
      Contribution(
        id: 'cont-1',
        by: testUserId,
        amount: 20000.0,
        date: DateTime(now.year, now.month, 1),
        note: 'Aportación quincena 1',
        byDisplayName: 'Usuario Prueba',
        createdAt: DateTime(now.year, now.month, 1),
      ),
      Contribution(
        id: 'cont-2',
        by: testUserId,
        amount: 13000.0,
        date: DateTime(now.year, now.month, 15),
        note: 'Aportación quincena 2',
        byDisplayName: 'Usuario Prueba',
        createdAt: DateTime(now.year, now.month, 15),
      ),
      Contribution(
        id: 'cont-3',
        by: testPartnerId,
        amount: 7000.0,
        date: DateTime(now.year, now.month, 1),
        note: 'Aportación quincena 1',
        byDisplayName: 'Pareja Prueba',
        createdAt: DateTime(now.year, now.month, 1),
      ),
      Contribution(
        id: 'cont-4',
        by: testPartnerId,
        amount: 5000.0,
        date: DateTime(now.year, now.month, 15),
        note: 'Aportación quincena 2',
        byDisplayName: 'Pareja Prueba',
        createdAt: DateTime(now.year, now.month, 15),
      ),
    ];
  }
}
