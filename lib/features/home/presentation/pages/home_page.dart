import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/member_provider.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../widgets/month_summary_card.dart';
import '../widgets/personal_summary_card.dart';
import '../widgets/category_list_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _showInviteCodeDialog(BuildContext context, WidgetRef ref, String householdId) async {
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
            icon: const Icon(Icons.share),
            onPressed: householdId != null
                ? () => _showInviteCodeDialog(context, ref, householdId)
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
