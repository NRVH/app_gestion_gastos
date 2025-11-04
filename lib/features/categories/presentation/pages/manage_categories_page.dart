import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/providers/member_provider.dart';
import '../../../../core/models/category.dart';
import '../../../../core/models/member.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/formatters.dart';
import '../../../household/presentation/widgets/share_household_dialog.dart';

enum CategorySortCriteria {
  name,
  budget,
  spent,
}

class ManageCategoriesPage extends ConsumerStatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  ConsumerState<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends ConsumerState<ManageCategoriesPage> {
  CategorySortCriteria _sortCriteria = CategorySortCriteria.name;
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implementar búsqueda
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

          // Verificar si debemos mostrar el botón de invitación
          final membersAsync = ref.watch(householdMembersProvider);
          final currentMemberAsync = ref.watch(currentMemberProvider);
          final showInviteButton = membersAsync.value != null &&
              currentMemberAsync.value?.role == MemberRole.owner &&
              membersAsync.value!.length == 1;

          // Ordenar categorías
          final sortedCategories = List<Category>.from(categories);
          _sortCategories(sortedCategories);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedCategories.length,
                  itemBuilder: (context, index) {
                    final category = sortedCategories[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _showEditCategoryDialog(context, category),
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
                              onPressed: () => _showEditCategoryDialog(context, category),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCategory(context, category.id, category.name),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),

              // Bottom action button - solo mostrar si es owner y está solo
              if (showInviteButton)
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
                      onPressed: () => _showInviteDialog(context),
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
        onPressed: () => _showAddCategoryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;

    final household = await ref.read(currentHouseholdProvider.future);
    if (household == null) return;

    // Generar código de invitación
    try {
      final inviteCode = await ref.read(firestoreServiceProvider).generateInviteCode(householdId);

      if (!context.mounted) return;

      await ShareHouseholdDialog.show(
        context,
        inviteCode: inviteCode,
        householdName: household.name,
        onClose: () {
          // Navegar al home después de cerrar el diálogo
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
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

  void _sortCategories(List<Category> categories) {
    switch (_sortCriteria) {
      case CategorySortCriteria.name:
        categories.sort((a, b) => _sortAscending
            ? a.name.compareTo(b.name)
            : b.name.compareTo(a.name));
        break;
      case CategorySortCriteria.budget:
        categories.sort((a, b) => _sortAscending
            ? a.monthlyLimit.compareTo(b.monthlyLimit)
            : b.monthlyLimit.compareTo(a.monthlyLimit));
        break;
      case CategorySortCriteria.spent:
        categories.sort((a, b) => _sortAscending
            ? a.spentThisMonth.compareTo(b.spentThisMonth)
            : b.spentThisMonth.compareTo(a.spentThisMonth));
        break;
    }
  }

  void _showSortDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            _buildSortOption(Icons.label, 'Nombre', CategorySortCriteria.name),
            _buildSortOption(Icons.account_balance_wallet, 'Presupuesto', CategorySortCriteria.budget),
            _buildSortOption(Icons.shopping_cart, 'Gastado', CategorySortCriteria.spent),
            
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
    );
  }

  Widget _buildSortOption(IconData icon, String label, CategorySortCriteria criteria) {
    final isSelected = _sortCriteria == criteria;
    
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: null) : null,
      onTap: () {
        setState(() {
          _sortCriteria = criteria;
        });
      },
    );
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
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  const Text(
                    'Nueva Categoría',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Preview card
            if (_previewAmount != null && _iconController.text.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
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
                            _nameController.text.isEmpty
                                ? 'Nueva Categoría'
                                : _nameController.text,
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

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Emoji field
                      TextFormField(
                        controller: _iconController,
                        decoration: InputDecoration(
                          labelText: 'Emoji',
                          hintText: '🏠 🚗 🍔 🎉',
                          prefixIcon: const Icon(Icons.emoji_emotions),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        style: const TextStyle(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Ej: Renta, Servicios, Comida',
                          prefixIcon: const Icon(Icons.label),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => Validators.required(value, fieldName: 'El nombre'),
                      ),
                      const SizedBox(height: 16),

                      // Budget field
                      TextFormField(
                        controller: _limitController,
                        decoration: InputDecoration(
                          labelText: 'Presupuesto mensual',
                          hintText: '5000',
                          prefixIcon: const Icon(Icons.attach_money),
                          prefixText: '\$ ',
                          helperText: 'Monto mensual para esta categoría',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: Validators.amount,
                      ),
                      const SizedBox(height: 24),

                      // Create button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _createCategory,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: Text(
                            _isLoading ? 'Creando...' : 'Crear Categoría',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
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
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  const Text(
                    'Editar Categoría',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Preview card
            if (_previewAmount != null && _iconController.text.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
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
                            _nameController.text.isEmpty
                                ? 'Categoría'
                                : _nameController.text,
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

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Emoji field
                      TextFormField(
                        controller: _iconController,
                        decoration: InputDecoration(
                          labelText: 'Emoji',
                          hintText: '🏠 🚗 🍔 🎉',
                          prefixIcon: const Icon(Icons.emoji_emotions),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        style: const TextStyle(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Ej: Renta, Servicios, Comida',
                          prefixIcon: const Icon(Icons.label),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => Validators.required(value, fieldName: 'El nombre'),
                      ),
                      const SizedBox(height: 16),

                      // Budget field
                      TextFormField(
                        controller: _limitController,
                        decoration: InputDecoration(
                          labelText: 'Presupuesto mensual',
                          hintText: '5000',
                          prefixIcon: const Icon(Icons.attach_money),
                          prefixText: '\$ ',
                          helperText: 'Monto mensual para esta categoría',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: Validators.amount,
                      ),
                      const SizedBox(height: 24),

                      // Update button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _updateCategory,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _isLoading ? 'Guardando...' : 'Guardar Cambios',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
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
