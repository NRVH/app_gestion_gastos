import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/sort_preferences_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/models/category.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/config/theme_config.dart';

class CategoriesTab extends ConsumerStatefulWidget {
  const CategoriesTab({super.key});

  @override
  ConsumerState<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends ConsumerState<CategoriesTab> {
  List<Category> _categories = [];
  String _searchQuery = '';
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final sortPrefsAsync = ref.watch(sortPreferencesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
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
          // BOTÓN TEMPORAL DE RESET
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red),
            onPressed: () async {
              final householdId = ref.read(currentHouseholdIdProvider);
              if (householdId != null) {
                await ref.read(firestoreServiceProvider).recalculateCategorySpending(householdId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Categorías recalculadas del mes actual')),
                  );
                }
              }
            },
            tooltip: 'RESET TEMPORAL',
          ),
          // BOTÓN FORZAR CIERRE DE MES
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.orange),
            onPressed: () async {
              final householdId = ref.read(currentHouseholdIdProvider);
              if (householdId != null) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('⚠️ Forzar Cierre de Mes'),
                    content: const Text(
                      'Esto RESETARÁ todas las categorías a \$0.00.\n\n'
                      'Úsalo solo si necesitas empezar un nuevo mes sin esperar al cierre automático.\n\n'
                      '¿Continuar?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange),
                        child: const Text('RESETEAR'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true && mounted) {
                  await ref.read(firestoreServiceProvider).forceResetCategories(householdId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Categorías reseteadas a \$0 - Nuevo mes iniciado'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              }
            },
            tooltip: 'FORZAR CIERRE DE MES',
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortDialog(context),
            tooltip: 'Ordenar',
          ),
        ],
      ),
      body: sortPrefsAsync.when(
        data: (sortPrefs) {
          return categoriesAsync.when(
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

              // Aplicar filtros/ordenamiento con las preferencias persistidas
              _categories = _applySortAndFilter(
                List.from(categories),
                sortPrefs.sortBy,
                sortPrefs.sortDirection,
              );

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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => categoriesAsync.when(
          data: (categories) {
            // Usar valores por defecto si hay error al cargar preferencias
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

            _categories = _applySortAndFilter(
              List.from(categories),
              CategorySortBy.recentlyAdded,
              SortDirection.descending,
            );

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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context),
        tooltip: 'Agregar categoría',
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Category> _applySortAndFilter(
    List<Category> categories,
    CategorySortBy sortBy,
    SortDirection sortDirection,
  ) {
    // Primero filtrar por búsqueda
    var filtered = categories;
    if (_searchQuery.isNotEmpty) {
      filtered = categories.where((cat) {
        return cat.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Luego aplicar ordenamiento según el criterio y dirección
    switch (sortBy) {
      case CategorySortBy.alphabetical:
        filtered.sort((a, b) {
          final comparison = a.name.compareTo(b.name);
          return sortDirection == SortDirection.ascending ? comparison : -comparison;
        });
        break;
      case CategorySortBy.recentlyAdded:
        filtered.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          final comparison = a.createdAt!.compareTo(b.createdAt!);
          return sortDirection == SortDirection.ascending ? comparison : -comparison;
        });
        break;
      case CategorySortBy.amount:
        filtered.sort((a, b) {
          final comparison = a.spentThisMonth.compareTo(b.spentThisMonth);
          return sortDirection == SortDirection.ascending ? comparison : -comparison;
        });
        break;
      case CategorySortBy.monthlyLimit:
        filtered.sort((a, b) {
          final comparison = a.monthlyLimit.compareTo(b.monthlyLimit);
          return sortDirection == SortDirection.ascending ? comparison : -comparison;
        });
        break;
    }

    return filtered;
  }

  void _showSortDialog(BuildContext context) {
    final sortPrefs = ref.read(sortPreferencesProvider).value;
    if (sortPrefs == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    CategorySortBy tempSortBy = sortPrefs.sortBy;
    SortDirection tempSortDirection = sortPrefs.sortDirection;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Título
                const Text(
                  'Ordenar categorías',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                // Opciones de ordenamiento
                _buildSortOption(
                  Icons.sort_by_alpha, 
                  'Alfabético', 
                  CategorySortBy.alphabetical,
                  tempSortBy,
                  (value) => setDialogState(() => tempSortBy = value),
                ),
                _buildSortOption(
                  Icons.calendar_today, 
                  'Fecha de creación', 
                  CategorySortBy.recentlyAdded,
                  tempSortBy,
                  (value) => setDialogState(() => tempSortBy = value),
                ),
                _buildSortOption(
                  Icons.shopping_cart, 
                  'Monto gastado', 
                  CategorySortBy.amount,
                  tempSortBy,
                  (value) => setDialogState(() => tempSortBy = value),
                ),
                _buildSortOption(
                  Icons.account_balance_wallet, 
                  'Límite mensual', 
                  CategorySortBy.monthlyLimit,
                  tempSortBy,
                  (value) => setDialogState(() => tempSortBy = value),
                ),
                
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                
                // Toggle Ascendente/Descendente
                Row(
                  children: [
                    const Icon(Icons.swap_vert, size: 20),
                    const SizedBox(width: 12),
                    const Text('Orden:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    SegmentedButton<SortDirection>(
                      segments: const [
                        ButtonSegment(value: SortDirection.descending, label: Text('Desc')),
                        ButtonSegment(value: SortDirection.ascending, label: Text('Asc')),
                      ],
                      selected: {tempSortDirection},
                      onSelectionChanged: (Set<SortDirection> selection) {
                        setDialogState(() {
                          tempSortDirection = selection.first;
                        });
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Botón aplicar
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        // Guardar en Firestore
                        await ref.read(sortPreferencesNotifierProvider)
                            .updateSortPreferences(tempSortBy, tempSortDirection);
                        
                        print('✅ [CategoriesTab] Preferencias guardadas: ${tempSortBy.name} (${tempSortDirection.name})');
                        
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      } catch (e) {
                        print('❌ [CategoriesTab] Error al guardar preferencias: $e');
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al guardar preferencias: $e')),
                        );
                      }
                    },
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortOption(
    IconData icon, 
    String label, 
    CategorySortBy criteria,
    CategorySortBy currentCriteria,
    Function(CategorySortBy) onTap,
  ) {
    final isSelected = currentCriteria == criteria;
    final palette = context.appPalette;
    
    return ListTile(
      leading: Icon(icon, color: isSelected ? palette.secondary : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? palette.secondary : null,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: palette.secondary) : null,
      onTap: () => onTap(criteria),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddCategorySheet(ref: ref),
    );
  }

  Future<void> _showEditCategoryDialog(BuildContext context, Category category) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditCategorySheet(ref: ref, category: category),
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
          icon: Icon(
            Icons.warning_rounded,
            color: Colors.orange.shade600,
            size: 48,
          ),
          title: const Text('Eliminar Categoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿Estás seguro de eliminar "$categoryName"?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Esta acción no se puede deshacer.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
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

// BottomSheet para agregar categoría
class _AddCategorySheet extends StatefulWidget {
  final WidgetRef ref;

  const _AddCategorySheet({required this.ref});

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();
  final _iconController = TextEditingController();
  bool _isLoading = false;
  double? _previewAmount;

  @override
  void initState() {
    super.initState();
    _limitController.addListener(() {
      final text = _limitController.text;
      setState(() {
        _previewAmount = text.isNotEmpty ? double.tryParse(text) : null;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final householdId = widget.ref.read(currentHouseholdIdProvider);
      if (householdId == null) throw Exception('Sesión inválida');

      await widget.ref.read(firestoreServiceProvider).createCategory(
            householdId: householdId,
            name: _nameController.text.trim(),
            monthlyLimit: double.parse(_limitController.text),
            icon: _iconController.text.trim().isEmpty
                ? null
                : _iconController.text.trim(),
          );

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Categoría creada'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 100),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.appPalette.tertiary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.category,
                              size: 32,
                              color: context.appPalette.tertiary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nueva Categoría',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'Crea una categoría de gasto',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Preview card
                      if (_previewAmount != null && _iconController.text.isNotEmpty && _nameController.text.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primaryContainer,
                                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _iconController.text,
                                style: const TextStyle(fontSize: 48),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nameController.text,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Presupuesto: ${CurrencyFormatter.format(_previewAmount!)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Emoji field
                      TextFormField(
                        controller: _iconController,
                        decoration: InputDecoration(
                          labelText: 'Emoji',
                          hintText: '🏠 🚗 🍔 🎉',
                          prefixIcon: const Icon(Icons.emoji_emotions),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        style: const TextStyle(fontSize: 24),
                        textAlign: TextAlign.center,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 20),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Ej: Renta, Servicios, Comida',
                          prefixIcon: const Icon(Icons.label),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => Validators.required(value, fieldName: 'El nombre'),
                        enabled: !_isLoading,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Budget field
                      TextFormField(
                        controller: _limitController,
                        decoration: InputDecoration(
                          labelText: 'Presupuesto mensual',
                          hintText: '5000',
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          helperText: 'Monto mensual para esta categoría',
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: Validators.amount,
                        enabled: !_isLoading,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Botones
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _createCategory,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Crear Categoría',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),

                      // Espacio para el teclado
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// BottomSheet para editar categoría
class _EditCategorySheet extends StatefulWidget {
  final WidgetRef ref;
  final Category category;

  const _EditCategorySheet({
    required this.ref,
    required this.category,
  });

  @override
  State<_EditCategorySheet> createState() => _EditCategorySheetState();
}

class _EditCategorySheetState extends State<_EditCategorySheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _limitController;
  late final TextEditingController _iconController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  double? _previewAmount;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _limitController = TextEditingController(
      text: widget.category.monthlyLimit.toString(),
    );
    _iconController = TextEditingController(text: widget.category.icon ?? '');
    _previewAmount = widget.category.monthlyLimit;

    _limitController.addListener(() {
      final text = _limitController.text;
      setState(() {
        _previewAmount = text.isNotEmpty ? double.tryParse(text) : null;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _updateCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final householdId = widget.ref.read(currentHouseholdIdProvider);
      if (householdId == null) throw Exception('Sesión inválida');

      final updateData = {
        'name': _nameController.text.trim(),
        'monthlyLimit': double.parse(_limitController.text),
        'icon': _iconController.text.trim().isEmpty
            ? null
            : _iconController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await widget.ref.read(firestoreServiceProvider).updateCategory(
            householdId,
            widget.category.id,
            updateData,
          );

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Categoría actualizada'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 100),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _parseColor(widget.category.color).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              widget.category.icon ?? '📁',
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Editar Categoría',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'Modifica los datos de la categoría',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Preview card
                      if (_previewAmount != null && _iconController.text.isNotEmpty && _nameController.text.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _parseColor(widget.category.color).withOpacity(0.2),
                                _parseColor(widget.category.color).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _parseColor(widget.category.color).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _iconController.text,
                                style: const TextStyle(fontSize: 48),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nameController.text,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Presupuesto: ${CurrencyFormatter.format(_previewAmount!)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Emoji field
                      TextFormField(
                        controller: _iconController,
                        decoration: InputDecoration(
                          labelText: 'Emoji',
                          hintText: '🏠 🚗 🍔 🎉',
                          prefixIcon: const Icon(Icons.emoji_emotions),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _parseColor(widget.category.color),
                              width: 2,
                            ),
                          ),
                        ),
                        style: const TextStyle(fontSize: 24),
                        textAlign: TextAlign.center,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 20),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Ej: Renta, Servicios, Comida',
                          prefixIcon: const Icon(Icons.label),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _parseColor(widget.category.color),
                              width: 2,
                            ),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => Validators.required(value, fieldName: 'El nombre'),
                        enabled: !_isLoading,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Budget field
                      TextFormField(
                        controller: _limitController,
                        decoration: InputDecoration(
                          labelText: 'Presupuesto mensual',
                          hintText: '5000',
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: _parseColor(widget.category.color),
                          ),
                          helperText: 'Monto mensual para esta categoría',
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _parseColor(widget.category.color),
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: Validators.amount,
                        enabled: !_isLoading,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Botones
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _updateCategory,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: _parseColor(widget.category.color),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Guardar Cambios',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),

                      // Espacio para el teclado
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
