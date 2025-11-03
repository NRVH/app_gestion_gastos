import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/models/category.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';

class CategoriesTab extends ConsumerStatefulWidget {
  const CategoriesTab({super.key});

  @override
  ConsumerState<CategoriesTab> createState() => _CategoriesTabState();
}

enum CategorySortBy {
  alphabetical,
  recentlyAdded,
  amount,
  monthlyLimit,
}

enum SortDirection {
  ascending,
  descending,
}

class _CategoriesTabState extends ConsumerState<CategoriesTab> {
  List<Category> _categories = [];
  String _searchQuery = '';
  bool _isSearching = false;
  CategorySortBy _sortBy = CategorySortBy.recentlyAdded;
  SortDirection _sortDirection = SortDirection.descending;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar categorías...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Categorías'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              tooltip: 'Cerrar búsqueda',
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              tooltip: 'Buscar',
            ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortDialog(context),
            tooltip: 'Ordenar',
          ),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay categorías',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca el botón + para crear',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Actualizar y aplicar filtros/ordenamiento
          _categories = _applySortAndFilter(List.from(categories));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return _buildCategoryCard(
                category: category, 
                context: context,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context),
        tooltip: 'Agregar categoría',
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Category> _applySortAndFilter(List<Category> categories) {
    // Primero filtrar por búsqueda
    var filtered = categories;
    if (_searchQuery.isNotEmpty) {
      filtered = categories.where((cat) {
        return cat.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Luego aplicar ordenamiento según el criterio y dirección
    switch (_sortBy) {
      case CategorySortBy.alphabetical:
        filtered.sort((a, b) {
          final comparison = a.name.compareTo(b.name);
          return _sortDirection == SortDirection.ascending ? comparison : -comparison;
        });
        break;
      case CategorySortBy.recentlyAdded:
        filtered.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          final comparison = a.createdAt!.compareTo(b.createdAt!);
          return _sortDirection == SortDirection.ascending ? comparison : -comparison;
        });
        break;
      case CategorySortBy.amount:
        filtered.sort((a, b) {
          final comparison = a.spentThisMonth.compareTo(b.spentThisMonth);
          return _sortDirection == SortDirection.ascending ? comparison : -comparison;
        });
        break;
      case CategorySortBy.monthlyLimit:
        filtered.sort((a, b) {
          final comparison = a.monthlyLimit.compareTo(b.monthlyLimit);
          return _sortDirection == SortDirection.ascending ? comparison : -comparison;
        });
        break;
    }

    return filtered;
  }

  Future<void> _saveSortPreferences() async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      
      // Guardar preferencias de ordenamiento en el household
      await firestoreService.updateHousehold(householdId, {
        'categorySortBy': _sortBy.index,
        'categorySortDirection': _sortDirection.index,
      });
      
      print('✅ [CategoriesTab] Preferencias guardadas: ${_sortBy.name} (${_sortDirection.name})');
    } catch (e) {
      print('❌ [CategoriesTab] Error al guardar preferencias: $e');
    }
  }

  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ordenar por'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Criterio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                RadioListTile<CategorySortBy>(
                  title: const Text('Alfabético'),
                  value: CategorySortBy.alphabetical,
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setDialogState(() {
                      _sortBy = value!;
                    });
                  },
                ),
                RadioListTile<CategorySortBy>(
                  title: const Text('Fecha de creación'),
                  value: CategorySortBy.recentlyAdded,
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setDialogState(() {
                      _sortBy = value!;
                    });
                  },
                ),
                RadioListTile<CategorySortBy>(
                  title: const Text('Monto gastado'),
                  value: CategorySortBy.amount,
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setDialogState(() {
                      _sortBy = value!;
                    });
                  },
                ),
                RadioListTile<CategorySortBy>(
                  title: const Text('Límite mensual'),
                  value: CategorySortBy.monthlyLimit,
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setDialogState(() {
                      _sortBy = value!;
                    });
                  },
                ),
                const Divider(height: 24),
                const Text(
                  'Dirección',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            _sortDirection = SortDirection.ascending;
                          });
                        },
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Ascendente'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _sortDirection == SortDirection.ascending
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            _sortDirection = SortDirection.descending;
                          });
                        },
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('Descendente'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _sortDirection == SortDirection.descending
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                // Ya están actualizados _sortBy y _sortDirection
              });
              _saveSortPreferences();
              Navigator.pop(context);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({required Category category, required BuildContext context}) {
    final progress = category.progress;
    final isOverBudget = category.isOverBudget;
    final percentage = (progress * 100).clamp(0, 200);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showCategoryActionSheet(context, category),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _parseColor(category.color).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        category.icon ?? '📁',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${CurrencyFormatter.format(category.spentThisMonth)} / ${CurrencyFormatter.format(category.totalAvailable)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isOverBudget
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isOverBudget
                              ? Colors.red
                              : category.isNearLimit
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                      ),
                      if (isOverBudget)
                        Text(
                          'Excedido',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(
                    isOverBudget
                        ? Colors.red
                        : category.isNearLimit
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
              ),
              if (category.remainingBudget > 0 && !isOverBudget)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Disponible: ${CurrencyFormatter.format(category.remainingBudget)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              if (isOverBudget)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Excedido por ${CurrencyFormatter.format(category.spentThisMonth - category.monthlyLimit)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryActionSheet(BuildContext context, Category category) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _parseColor(category.color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      category.icon ?? '📁',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        category.isOverBudget
                            ? 'Presupuesto excedido'
                            : category.isNearLimit
                                ? 'Cerca del límite'
                                : 'Dentro del presupuesto',
                        style: TextStyle(
                          color: category.isOverBudget
                              ? Colors.red
                              : category.isNearLimit
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(
              'Gastado',
              CurrencyFormatter.format(category.spentThisMonth),
              Icons.shopping_cart,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Límite mensual',
              CurrencyFormatter.format(category.monthlyLimit),
              Icons.account_balance_wallet,
            ),
            if (category.accumulatedBalance != 0) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                category.accumulatedBalance > 0 ? 'Acumulado mes anterior' : 'Déficit mes anterior',
                CurrencyFormatter.format(category.accumulatedBalance.abs()),
                category.accumulatedBalance > 0 ? Icons.trending_up : Icons.trending_down,
                valueColor: category.accumulatedBalance > 0 ? Colors.green : Colors.red,
              ),
            ],
            const SizedBox(height: 12),
            _buildDetailRow(
              'Total disponible',
              CurrencyFormatter.format(category.totalAvailable),
              Icons.account_balance,
              isBold: true,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              category.remainingBudget > 0 ? 'Disponible' : 'Excedido',
              CurrencyFormatter.format(category.remainingBudget.abs()),
              category.remainingBudget > 0 ? Icons.check_circle : Icons.error,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteCategory(context, category.id, category.name);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Eliminar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditCategoryDialog(context, category);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label, 
    String value, 
    IconData icon, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
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

  Future<void> _showEditCategoryDialog(BuildContext context, Category category) async {
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
