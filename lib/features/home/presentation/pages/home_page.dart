import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/member_provider.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/models/member.dart';
import '../widgets/month_summary_card.dart';
import '../widgets/personal_summary_card.dart';
import '../widgets/category_list_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    
    // Escuchar cambios en el household y miembro actual
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupListeners();
    });
  }

  void _setupListeners() {
    // Listener para detectar si el household fue eliminado o el usuario expulsado
    ref.listen(currentHouseholdProvider, (previous, next) {
      next.whenData((household) {
        if (household == null && mounted) {
          print('🏠 [HomePage] Household eliminado o usuario expulsado, redirigiendo...');
          _redirectToCreateOrJoin();
        }
      });
    });

    // Listener adicional para verificar membresía
    ref.listen(currentMemberProvider, (previous, next) {
      next.whenData((member) {
        if (member == null && mounted) {
          print('👤 [HomePage] Usuario ya no es miembro, redirigiendo...');
          _redirectToCreateOrJoin();
        }
      });
    });
  }

  void _redirectToCreateOrJoin() {
    // Limpiar el household ID guardado
    ref.read(currentHouseholdIdProvider.notifier).clear();
    
    // Redirigir a la pantalla de crear/unirse
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.createHousehold,
        (route) => false, // Eliminar toda la pila de navegación
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya no eres miembro de este hogar'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showCloseMonthDialog(BuildContext context) async {
    final householdAsync = ref.read(currentHouseholdProvider);
    final household = householdAsync.value;
    
    if (household == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar mes'),
        content: const Text(
          '¿Estás seguro de cerrar el mes actual?\n\n'
          '• Se guardarán los sobrantes/déficits de cada categoría\n'
          '• Se reiniciarán los gastos y aportaciones del mes\n'
          '• Esta acción no se puede deshacer',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Cerrar mes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Mostrar loading
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cerrando mes...'),
                ],
              ),
            ),
          ),
        ),
      );

      final membersAsync = await ref.read(householdMembersProvider.future);
      final categoriesAsync = await ref.read(categoriesProvider.future);

      await ref.read(firestoreServiceProvider).closeMonth(
            householdId: household.id,
            household: household,
            members: membersAsync,
            categories: categoriesAsync,
          );

      // Cerrar loading
      if (!context.mounted) return;
      Navigator.pop(context);

      // Refrescar datos
      ref.invalidate(currentHouseholdProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(householdMembersProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Mes cerrado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Cerrar loading si está abierto
      if (context.mounted) Navigator.pop(context);
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar mes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showInviteCodeDialog(BuildContext context, String householdId) async {
    // Generar código
    String? inviteCode;
    try {
      inviteCode = await ref.read(firestoreServiceProvider).generateInviteCode(householdId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Código de invitación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Comparte este código con tu pareja para que se una al hogar:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  inviteCode!,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'El código expira en 24 horas',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Código copiado al portapapeles'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdAsync = ref.watch(currentHouseholdProvider);
    final currentMemberAsync = ref.watch(currentMemberProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final householdId = ref.watch(currentHouseholdIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: householdAsync.when(
          data: (household) => Text(household?.name ?? 'Gestión de Gastos'),
          loading: () => const Text('Cargando...'),
          error: (_, __) => const Text('Error'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: householdId != null
                ? () => _showCloseMonthDialog(context)
                : null,
            tooltip: 'Cerrar mes',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: householdId != null
                ? () => _showInviteCodeDialog(context, householdId)
                : null,
            tooltip: 'Compartir código de invitación',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.settings);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentHouseholdProvider);
          ref.invalidate(currentMemberProvider);
          ref.invalidate(categoriesProvider);
        },
        child: householdAsync.when(
          data: (household) {
            if (household == null) {
              return const Center(
                child: Text('No se encontró el hogar'),
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonthSummaryCard(household: household),
                  const SizedBox(height: 16),
                  currentMemberAsync.when(
                    data: (member) {
                      if (member == null) {
                        return const SizedBox.shrink();
                      }
                      return PersonalSummaryCard(
                        member: member,
                        monthTarget: household.monthTarget,
                      );
                    },
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  categoriesAsync.when(
                    data: (categories) => CategoryListCard(
                      categories: categories,
                    ),
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (_, __) => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Error al cargar categorías'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Error: $error'),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'view_contributions',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.contributionsList);
            },
            child: const Icon(Icons.list),
            tooltip: 'Ver aportaciones',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_contribution',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.addContribution);
            },
            child: const Icon(Icons.add),
            tooltip: 'Agregar aportación',
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'view_expenses',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.expensesList);
            },
            backgroundColor: Colors.red[300],
            child: const Icon(Icons.list),
            tooltip: 'Ver gastos',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_expense',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.addExpense);
            },
            backgroundColor: Colors.red,
            child: const Icon(Icons.remove),
            tooltip: 'Agregar gasto',
          ),
        ],
      ),
    );
  }
}
