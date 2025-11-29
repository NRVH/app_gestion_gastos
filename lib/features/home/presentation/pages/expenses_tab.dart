import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/expense_provider.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/sort_preferences_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/category.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/config/theme_config.dart';
import '../../../expenses/presentation/pages/add_expense_page.dart';
import '../../../expenses/presentation/pages/edit_expense_page.dart';

enum ExpenseSortCriteria {
  amount,
  date,
  category,
  person,
}

class ExpensesTab extends ConsumerStatefulWidget {
  const ExpensesTab({super.key});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  String? _selectedCategoryId;
  String _searchQuery = '';
  ExpenseSortCriteria _sortCriteria = ExpenseSortCriteria.amount;
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(currentHouseholdProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            ),
            title: const Text('Gastos'),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showInfo(context),
                tooltip: 'Información',
              ),
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: () => _showSortDialog(context),
                tooltip: 'Ordenar',
              ),
            ],
          ),

          // Category Filter
          SliverToBoxAdapter(
            child: categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _buildCategoryFilter(categories);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // Expenses List
          expensesAsync.when(
            data: (expenses) {
              final filteredExpenses = _selectedCategoryId == null
                  ? expenses
                  : expenses
                      .where((e) => e.categoryId == _selectedCategoryId)
                      .toList();

              // Ordenar según criterio seleccionado
              _sortExpenses(filteredExpenses, categoriesAsync.value ?? []);

              // Group expenses by date
              final groupedExpenses = <String, List<Expense>>{};
              for (final expense in filteredExpenses) {
                final dateKey = DateFormatter.formatDate(expense.date);
                groupedExpenses.putIfAbsent(dateKey, () => []);
                groupedExpenses[dateKey]!.add(expense);
              }

              if (filteredExpenses.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _selectedCategoryId == null
                              ? 'No hay gastos'
                              : 'No hay gastos en esta categoría',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toca el botón + para agregar',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 80), // Espacio para el FAB
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final expense = filteredExpenses[index];
                      return _buildExpenseItem(
                        expense,
                        categoriesAsync.value
                            ?.firstWhere((c) => c.id == expense.categoryId,
                                orElse: () => Category(
                                      id: '',
                                      name: 'Sin categoría',
                                      monthlyLimit: 0,
                                      icon: '❓',
                                      color: '#808080',
                                    )),
                      );
                    },
                    childCount: filteredExpenses.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: householdAsync.when(
        data: (household) => household != null
            ? FloatingActionButton(
                onPressed: () => _navigateToAddExpense(context),
                child: const Icon(Icons.add),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  Widget _buildCategoryFilter(List<Category> categories) {
    final selectedCategory = categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => Category(
        id: '',
        name: 'Todas las categorías',
        monthlyLimit: 0,
        icon: '📋',
        color: '#808080',
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: InkWell(
        onTap: () => _showCategorySearchDialog(context, categories),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
            color: _selectedCategoryId == null
                ? (isDark ? Colors.grey.shade800 : Colors.grey.shade50)
                : _parseColor(selectedCategory.color).withOpacity(isDark ? 0.2 : 0.1),
          ),
          child: Row(
            children: [
              Text(
                _selectedCategoryId == null ? '📋' : (selectedCategory.icon ?? '📁'),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filtrar por categoría',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedCategoryId == null
                          ? 'Todas las categorías'
                          : selectedCategory.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade200 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 28,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategorySearchDialog(BuildContext context, List<Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CategorySearchDialog(
        categories: categories,
        selectedCategoryId: _selectedCategoryId,
        onCategorySelected: (categoryId) {
          setState(() {
            _selectedCategoryId = categoryId;
            _searchQuery = '';
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildExpenseItem(Expense expense, Category? category) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _parseColor(category?.color).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              category?.icon ?? '❓',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          expense.note.isEmpty ? 'Gasto sin descripción' : expense.note,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category?.name ?? 'Sin categoría'),
            const SizedBox(height: 2),
            Text(
              DateFormatter.formatDate(expense.date),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Text(
          CurrencyFormatter.format(expense.amount),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        onTap: () => _showExpenseDetails(context, expense, category),
      ),
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

  void _showExpenseDetails(
    BuildContext context,
    Expense expense,
    Category? category,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ExpenseDetailsSheet(
        expense: expense,
        category: category,
        onDelete: () {
          Navigator.pop(context);
          _deleteExpense(expense);
        },
        onEdit: () {
          Navigator.pop(context);
          _editExpense(context, expense);
        },
      ),
    );
  }

  void _deleteExpense(Expense expense) async {
    final householdAsync = ref.read(currentHouseholdProvider);
    final household = householdAsync.value;
    if (household == null) return;

    final description = expense.note.isEmpty ? 'este gasto' : expense.note;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_rounded,
          color: Colors.orange.shade600,
          size: 48,
        ),
        title: const Text('Eliminar gasto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Estás seguro de eliminar "$description"?',
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.appPalette.danger,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        print('🗑️ [ExpensesTab] Eliminando gasto: ${expense.id}, Monto: ${expense.amount}');
        
        await ref.read(firestoreServiceProvider).deleteExpense(
          household.id,
          expense.id,
          expense.categoryId,
          expense.amount,
        );

        print('✅ [ExpensesTab] Gasto eliminado exitosamente');

        // Esperar un momento para que Firestore termine de actualizar
        await Future.delayed(const Duration(milliseconds: 500));

        // Refrescar providers para forzar actualización inmediata
        print('🔄 [ExpensesTab] Refrescando providers...');
        ref.refresh(categoriesProvider);
        ref.refresh(expensesProvider);
        ref.refresh(currentHouseholdProvider);
        print('✅ [ExpensesTab] Providers refrescados');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gasto eliminado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _navigateToAddExpense(BuildContext context) {
    showAddExpenseSheet(context, ref);
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gastos'),
        content: const Text(
          'Aquí puedes ver, agregar y gestionar todos los gastos del hogar.\n\n'
          'Los gastos se descuentan del balance compartido y se categorizan '
          'para llevar un control de tu presupuesto mensual.\n\n'
          'Filtra por categoría para ver gastos específicos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _editExpense(BuildContext context, Expense expense) {
    showEditExpenseSheet(context, ref, expense);
  }

  void _sortExpenses(List<Expense> expenses, List<Category> categories) {
    switch (_sortCriteria) {
      case ExpenseSortCriteria.amount:
        expenses.sort((a, b) => _sortAscending 
            ? a.amount.compareTo(b.amount)
            : b.amount.compareTo(a.amount));
        break;
      case ExpenseSortCriteria.date:
        expenses.sort((a, b) => _sortAscending
            ? a.date.compareTo(b.date)
            : b.date.compareTo(a.date));
        break;
      case ExpenseSortCriteria.category:
        expenses.sort((a, b) {
          final catA = categories.firstWhere((c) => c.id == a.categoryId,
              orElse: () => Category(id: '', name: 'Sin categoría', monthlyLimit: 0, icon: '❓', color: '#808080'));
          final catB = categories.firstWhere((c) => c.id == b.categoryId,
              orElse: () => Category(id: '', name: 'Sin categoría', monthlyLimit: 0, icon: '❓', color: '#808080'));
          return _sortAscending
              ? catA.name.compareTo(catB.name)
              : catB.name.compareTo(catA.name);
        });
        break;
      case ExpenseSortCriteria.person:
        expenses.sort((a, b) => _sortAscending
            ? (a.byDisplayName ?? '').compareTo(b.byDisplayName ?? '')
            : (b.byDisplayName ?? '').compareTo(a.byDisplayName ?? ''));
        break;
    }
  }

  void _showSortDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                'Ordenar gastos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Opciones de ordenamiento
              _buildSortOptionWithState(Icons.attach_money, 'Monto', ExpenseSortCriteria.amount, setModalState),
              _buildSortOptionWithState(Icons.calendar_today, 'Fecha', ExpenseSortCriteria.date, setModalState),
              _buildSortOptionWithState(Icons.category, 'Categoría', ExpenseSortCriteria.category, setModalState),
              _buildSortOptionWithState(Icons.person, 'Persona', ExpenseSortCriteria.person, setModalState),
              
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
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Desc')),
                      ButtonSegment(value: true, label: Text('Asc')),
                    ],
                    selected: {_sortAscending},
                    onSelectionChanged: (Set<bool> selection) {
                      setState(() {
                        _sortAscending = selection.first;
                      });
                      setModalState(() {
                        _sortAscending = selection.first;
                      });
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Botón cerrar
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(IconData icon, String label, ExpenseSortCriteria criteria) {
    final isSelected = _sortCriteria == criteria;
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
      onTap: () {
        setState(() {
          _sortCriteria = criteria;
        });
      },
    );
  }

  Widget _buildSortOptionWithState(IconData icon, String label, ExpenseSortCriteria criteria, StateSetter setModalState) {
    final isSelected = _sortCriteria == criteria;
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
      onTap: () {
        setState(() {
          _sortCriteria = criteria;
        });
        setModalState(() {
          _sortCriteria = criteria;
        });
      },
    );
  }
}

class _CategorySearchDialog extends StatefulWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final Function(String?) onCategorySelected;

  const _CategorySearchDialog({
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  State<_CategorySearchDialog> createState() => _CategorySearchDialogState();
}

class _CategorySearchDialogState extends State<_CategorySearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final filteredCategories = _searchQuery.isEmpty
        ? widget.categories
        : widget.categories
            .where((c) =>
                c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Text(
                    'Seleccionar categoría',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade200 : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: TextStyle(
                  color: isDark ? Colors.grey.shade200 : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar categoría...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                ),
                autofocus: false,
              ),
            ),

            const SizedBox(height: 16),

            // "All" option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('📋', style: TextStyle(fontSize: 24)),
                  ),
                ),
                title: Text(
                  'Todas las categorías',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade200 : Colors.black87,
                  ),
                ),
                trailing: widget.selectedCategoryId == null
                    ? Icon(
                        Icons.check_circle,
                        color: isDark
                            ? Colors.greenAccent.shade400
                            : Colors.green.shade600,
                      )
                    : null,
                selected: widget.selectedCategoryId == null,
                selectedTileColor: isDark
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Theme.of(context).primaryColor.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => widget.onCategorySelected(null),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),

            // Categories list
            Expanded(
              child: filteredCategories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron categorías',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        final category = filteredCategories[index];
                        final isSelected = category.id == widget.selectedCategoryId;
                        
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _parseColor(category.color).withOpacity(isDark ? 0.3 : 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                category.icon ?? '📁',
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade200 : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Límite: ${CurrencyFormatter.format(category.monthlyLimit)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: isDark
                                      ? Colors.greenAccent.shade400
                                      : Colors.green.shade600,
                                )
                              : null,
                          selected: isSelected,
                          selectedTileColor: isDark
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Theme.of(context).primaryColor.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () => widget.onCategorySelected(category.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ExpenseDetailsSheet extends StatelessWidget {
  final Expense expense;
  final Category? category;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ExpenseDetailsSheet({
    required this.expense,
    required this.category,
    required this.onDelete,
    required this.onEdit,
  });

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
    return Container(
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
                  color: _parseColor(category?.color).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    category?.icon ?? '❓',
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
                      expense.note.isEmpty ? 'Gasto sin descripción' : expense.note,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      category?.name ?? 'Sin categoría',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow(
            'Monto',
            CurrencyFormatter.format(expense.amount),
            Icons.attach_money,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Fecha',
            DateFormatter.formatDate(expense.date),
            Icons.calendar_today,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
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
                  onPressed: onEdit,
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
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
