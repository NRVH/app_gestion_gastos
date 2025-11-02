import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/household_provider.dart';

class CreateHouseholdPage extends ConsumerStatefulWidget {
  const CreateHouseholdPage({super.key});

  @override
  ConsumerState<CreateHouseholdPage> createState() => _CreateHouseholdPageState();
}

class _CreateHouseholdPageState extends ConsumerState<CreateHouseholdPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Usuario no autenticado');

      final householdId = await ref.read(firestoreServiceProvider).createHousehold(
            name: _nameController.text.trim(),
            month: DateFormatter.getCurrentMonth(),
            monthTarget: 0.0, // Se calculará automáticamente de las categorías
            ownerUid: user.uid,
            ownerDisplayName: user.displayName ?? 'Usuario',
            ownerShare: 0.5, // Por defecto 50%, se recalculará con los salarios
          );

      if (!mounted) return;

      ref.read(currentHouseholdIdProvider.notifier).state = householdId;
      
      // Mostrar diálogo de bienvenida
      _showWelcomeDialog(context);
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

  void _showWelcomeDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¡Hogar creado!'),
        content: const Text(
          'Ahora debes:\n\n'
          '1. Agregar categorías de gastos fijos (renta, servicios, comida, etc.)\n'
          '2. Invitar a tu pareja con el código\n'
          '3. Ambos configurar sus salarios mensuales\n\n'
          'Los porcentajes se calcularán automáticamente.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed(AppRouter.manageCategories);
            },
            child: const Text('Agregar categorías'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Hogar'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.home_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Crear tu hogar',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Dale un nombre a tu hogar compartido',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del hogar',
                    prefixIcon: Icon(Icons.home_outlined),
                    hintText: 'Ej: Casa González',
                    helperText: 'Luego configurarás categorías, salarios y porcentajes',
                  ),
                  validator: (value) => Validators.required(value, fieldName: 'El nombre'),
                  enabled: !_isLoading,
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createHousehold,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear hogar'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).pushReplacementNamed(
                            AppRouter.joinHousehold,
                          );
                        },
                  child: const Text('¿Ya tienes un hogar? Únete'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
