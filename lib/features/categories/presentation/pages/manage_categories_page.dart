import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/models/category.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/formatters.dart';

class ManageCategoriesPage extends ConsumerWidget {
  const ManageCategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Categorías'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
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
                    'No hay categorías',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toca el botón + para crear una',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _showEditCategoryDialog(context, ref, category),
                        leading: category.icon != null
                            ? Text(category.icon!, style: const TextStyle(fontSize: 32))
                            : const Icon(Icons.label_outline, size: 32),
                        title: Text(
                          category.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Presupuesto: ${CurrencyFormatter.format(category.monthlyLimit)}',
                            ),
                            Text(
                              'Gastado: ${CurrencyFormatter.format(category.spentThisMonth)}',
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditCategoryDialog(context, ref, category),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCategory(context, ref, category.id, category.name),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
              // Botón continuar - solo visible cuando hay categorías
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: ElevatedButton.icon(
                    onPressed: () => _showInviteDialog(context, ref),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continuar - Invitar pareja'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;

    // Generar código de invitación
    try {
      final inviteCode = await ref.read(firestoreServiceProvider).generateInviteCode(householdId);

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.share, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Invitar a tu pareja'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Comparte este código de 6 dígitos con tu pareja. El código expira en 24 horas.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Text(
                    inviteCode,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Una vez que ambos se unan, deberán configurar sus salarios para calcular los porcentajes automáticamente.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navegar al home
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                },
                child: const Text('Continuar al inicio'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar código: ${e.toString()}')),
      );
    }
  }

  Future<void> _showAddCategoryDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final limitController = TextEditingController();
    final iconController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva Categoría'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ej: Renta, Servicios, Comida',
                    ),
                    validator: (value) => Validators.required(value, fieldName: 'El nombre'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: limitController,
                    decoration: const InputDecoration(
                      labelText: 'Presupuesto mensual',
                      hintText: 'Ej: 5000',
                      prefixText: '\$ ',
                      helperText: 'Monto que se destina a esta categoría cada mes',
                    ),
                    keyboardType: TextInputType.number,
                    validator: Validators.amount,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: iconController,
                    decoration: const InputDecoration(
                      labelText: 'Emoji (opcional)',
                      hintText: 'Ej: 🏠 🚗 🎉',
                    ),
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
                if (formKey.currentState!.validate()) {
                  final householdId = ref.read(currentHouseholdIdProvider);
                  if (householdId == null) return;

                  try {
                    await ref.read(firestoreServiceProvider).createCategory(
                          householdId: householdId,
                          name: nameController.text.trim(),
                          monthlyLimit: double.parse(limitController.text),
                          icon: iconController.text.trim().isEmpty
                              ? null
                              : iconController.text.trim(),
                        );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Categoría creada')),
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
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditCategoryDialog(BuildContext context, WidgetRef ref, Category category) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category.name);
    final limitController = TextEditingController(text: category.monthlyLimit.toString());
    final iconController = TextEditingController(text: category.icon ?? '');

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Categoría'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ej: Renta, Servicios, Comida',
                    ),
                    validator: (value) => Validators.required(value, fieldName: 'El nombre'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: limitController,
                    decoration: const InputDecoration(
                      labelText: 'Presupuesto mensual',
                      hintText: 'Ej: 5000',
                      prefixText: '\$ ',
                      helperText: 'Monto que se destina a esta categoría cada mes',
                    ),
                    keyboardType: TextInputType.number,
                    validator: Validators.amount,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: iconController,
                    decoration: const InputDecoration(
                      labelText: 'Emoji (opcional)',
                      hintText: 'Ej: 🏠 🚗 🎉',
                    ),
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
                if (formKey.currentState!.validate()) {
                  final householdId = ref.read(currentHouseholdIdProvider);
                  if (householdId == null) return;

                  try {
                    final updateData = {
                      'name': nameController.text.trim(),
                      'monthlyLimit': double.parse(limitController.text),
                      'icon': iconController.text.trim().isEmpty
                          ? null
                          : iconController.text.trim(),
                      'updatedAt': DateTime.now().toIso8601String(),
                    };
                    
                    await ref.read(firestoreServiceProvider).updateCategory(
                          householdId,
                          category.id,
                          updateData,
                        );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Categoría actualizada')),
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
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    String categoryId,
    String categoryName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Categoría'),
          content: Text('¿Estás seguro de eliminar "$categoryName"?'),
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
        await ref.read(firestoreServiceProvider).deleteCategory(
              householdId,
              categoryId,
            );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Categoría eliminada')),
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
