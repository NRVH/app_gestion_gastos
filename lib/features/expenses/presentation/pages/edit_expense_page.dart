import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/providers/expense_provider.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/formatters.dart';

class EditExpensePage extends ConsumerStatefulWidget {
  final Expense expense;

  const EditExpensePage({
    super.key,
    required this.expense,
  });

  @override
  ConsumerState<EditExpensePage> createState() => _EditExpensePageState();
}

class _EditExpensePageState extends ConsumerState<EditExpensePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String? _selectedCategoryId;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.expense.amount.toString(),
    );
    _noteController = TextEditingController(text: widget.expense.note);
    _selectedCategoryId = widget.expense.categoryId;
    _selectedDate = widget.expense.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final householdId = ref.read(currentHouseholdIdProvider);
      final categories = ref.read(categoriesProvider).value ?? [];
      final category = categories.firstWhere((c) => c.id == _selectedCategoryId);

      if (householdId == null) {
        throw Exception('No hay hogar activo');
      }

      final newAmount = double.parse(_amountController.text);
      final amountDiff = newAmount - widget.expense.amount;

      print('✏️ [EditExpense] Editando gasto: ${widget.expense.id}');
      print('✏️ [EditExpense] Monto anterior: ${widget.expense.amount}, Nuevo monto: $newAmount, Diferencia: $amountDiff');
      
      await ref.read(firestoreServiceProvider).updateExpense(
            householdId,
            widget.expense.id,
            _selectedCategoryId!,
            {
              'categoryId': _selectedCategoryId!,
              'categoryName': category.name,
              'amount': newAmount,
              'date': _selectedDate,
              'note': _noteController.text.trim(),
            },
            amountDiff,
          );

      print('✅ [EditExpense] Gasto editado exitosamente');

      if (!mounted) return;

      // Esperar un momento para que Firestore termine de actualizar
      await Future.delayed(const Duration(milliseconds: 500));

      // Refrescar providers para forzar actualización inmediata
      print('🔄 [EditExpense] Refrescando providers...');
      ref.refresh(categoriesProvider);
      ref.refresh(expensesProvider);
      ref.refresh(currentHouseholdProvider);
      print('✅ [EditExpense] Providers refrescados');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gasto actualizado')),
      );
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Gasto'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Text('No hay categorías disponibles'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category.id,
                        child: Row(
                          children: [
                            if (category.icon != null)
                              Text(category.icon!, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(category.name),
                          ],
                        ),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null) return 'Selecciona una categoría';
                      return null;
                    },
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixIcon: Icon(Icons.attach_money),
                      prefixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: Validators.amount,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Fecha'),
                    subtitle: Text(DateFormatter.formatDate(_selectedDate)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _selectDate,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                      prefixIcon: Icon(Icons.notes),
                      hintText: 'Descripción del gasto',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isLoading ? null : _updateExpense,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar cambios'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
