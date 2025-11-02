import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/contribution_provider.dart';
import '../../../../core/models/contribution.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/formatters.dart';

class ContributionsListPage extends ConsumerWidget {
  const ContributionsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributionsAsync = ref.watch(contributionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Aportaciones'),
      ),
      body: contributionsAsync.when(
        data: (contributions) {
          if (contributions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay aportaciones registradas',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            );
          }

          // Agrupar por fecha
          final groupedContributions = <String, List<Contribution>>{};
          for (var contribution in contributions) {
            final dateKey = DateFormatter.formatDate(contribution.date);
            groupedContributions.putIfAbsent(dateKey, () => []).add(contribution);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedContributions.length,
            itemBuilder: (context, index) {
              final dateKey = groupedContributions.keys.elementAt(index);
              final dayContributions = groupedContributions[dateKey]!;
              final dayTotal = dayContributions.fold<double>(
                0,
                (sum, contribution) => sum + contribution.amount,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateKey,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(dayTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dayContributions.map((contribution) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.add_circle, color: Colors.green),
                          title: Text('Aportación de ${contribution.byDisplayName}'),
                          subtitle: contribution.note.isNotEmpty
                              ? Text(contribution.note)
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                CurrencyFormatter.format(contribution.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                              PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Editar'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditContributionDialog(context, ref, contribution);
                                  } else if (value == 'delete') {
                                    _deleteContribution(context, ref, contribution);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _showEditContributionDialog(
    BuildContext context,
    WidgetRef ref,
    Contribution contribution,
  ) async {
    final amountController = TextEditingController(text: contribution.amount.toStringAsFixed(0));
    final noteController = TextEditingController(text: contribution.note);
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Aportación'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'De: ${contribution.byDisplayName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                    validator: Validators.amount,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final householdId = ref.read(currentHouseholdIdProvider);
                if (householdId == null) return;

                try {
                  final oldAmount = contribution.amount;
                  final newAmount = double.parse(amountController.text);
                  final amountDiff = newAmount - oldAmount;

                  await ref.read(firestoreServiceProvider).updateContribution(
                    householdId,
                    contribution.id,
                    contribution.by,
                    {
                      'amount': newAmount,
                      'note': noteController.text.trim(),
                    },
                    amountDiff,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Aportación actualizada')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteContribution(
    BuildContext context,
    WidgetRef ref,
    Contribution contribution,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Aportación'),
          content: Text(
            '¿Eliminar aportación de ${CurrencyFormatter.format(contribution.amount)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final householdId = ref.read(currentHouseholdIdProvider);
      if (householdId == null) return;

      try {
        await ref.read(firestoreServiceProvider).deleteContribution(
          householdId,
          contribution.id,
          contribution.by,
          contribution.amount,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aportación eliminada')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }
}
