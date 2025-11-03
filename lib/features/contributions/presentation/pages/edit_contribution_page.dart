import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/member_provider.dart';
import '../../../../core/models/contribution.dart';
import '../../../../core/models/member.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/formatters.dart';

class EditContributionPage extends ConsumerStatefulWidget {
  final Contribution contribution;

  const EditContributionPage({
    super.key,
    required this.contribution,
  });

  @override
  ConsumerState<EditContributionPage> createState() => _EditContributionPageState();
}

class _EditContributionPageState extends ConsumerState<EditContributionPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String? _selectedMemberId;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.contribution.amount.toString(),
    );
    _noteController = TextEditingController(text: widget.contribution.note);
    _selectedMemberId = widget.contribution.by; // 'by' is the userId
    _selectedDate = widget.contribution.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _updateContribution() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMemberId == null || _selectedMemberId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un miembro')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final householdId = ref.read(currentHouseholdIdProvider);
      final members = ref.read(householdMembersProvider).value ?? [];
      final member = members.firstWhere((m) => m.uid == _selectedMemberId);

      if (householdId == null) {
        throw Exception('No hay hogar activo');
      }

      final newAmount = double.parse(_amountController.text);
      final amountDiff = newAmount - widget.contribution.amount;

      await ref.read(firestoreServiceProvider).updateContribution(
            householdId,
            widget.contribution.id,
            _selectedMemberId!, // 'by' userId
            {
              'by': _selectedMemberId!,
              'byDisplayName': member.displayName,
              'amount': newAmount,
              'date': _selectedDate,
              'note': _noteController.text.trim(),
            },
            amountDiff,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aporte actualizado')),
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
    final membersAsync = ref.watch(householdMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Aporte'),
      ),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text('No hay miembros disponibles'),
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
                    value: _selectedMemberId,
                    decoration: const InputDecoration(
                      labelText: 'Miembro',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: members.map((member) {
                      return DropdownMenuItem<String>(
                        value: member.uid, // Use uid
                        child: Text(member.displayName),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null) return 'Selecciona un miembro';
                      return null;
                    },
                    onChanged: (value) {
                      setState(() => _selectedMemberId = value);
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
                      hintText: 'Descripción del aporte',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isLoading ? null : _updateContribution,
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
