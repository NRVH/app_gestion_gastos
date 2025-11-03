import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/messaging_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/providers/household_provider.dart';

class JoinHouseholdPage extends ConsumerStatefulWidget {
  const JoinHouseholdPage({super.key});

  @override
  ConsumerState<JoinHouseholdPage> createState() => _JoinHouseholdPageState();
}

class _JoinHouseholdPageState extends ConsumerState<JoinHouseholdPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinHousehold() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener tu información')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Intentar unirse al hogar (retorna el householdId incluso si ya eres miembro)
      final householdId = await ref.read(firestoreServiceProvider).joinHouseholdWithCode(
            _codeController.text.trim(),
            user.uid,
            user.displayName ?? 'Usuario',
          );

      if (!mounted) return;

      // Establecer el household actual
      await ref.read(currentHouseholdIdProvider.notifier).setHouseholdId(householdId);

      // Guardar el FCM token para este household
      try {
        print('🔔 [JoinHousehold] Guardando FCM token después de unirse...');
        final messagingService = ref.read(messagingServiceProvider);
        final token = await messagingService.getToken();
        
        if (token != null) {
          print('🔔 [JoinHousehold] Token obtenido: ${token.substring(0, 20)}...');
          await ref.read(firestoreServiceProvider).updateFcmToken(
            householdId,
            user.uid,
            token,
          );
          print('🔔 [JoinHousehold] ✅ Token guardado exitosamente');
        } else {
          print('⚠️ [JoinHousehold] No se pudo obtener el FCM token');
        }
      } catch (e) {
        print('❌ [JoinHousehold] Error al guardar token: $e');
        // No bloqueamos la navegación si falla el token
      }

      if (!mounted) return;

      // Navegar al home
      Navigator.of(context).pushReplacementNamed(AppRouter.home);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Bienvenido al hogar!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Mostrar error pero mantener la sesión
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unirse a Hogar'),
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
                  Icons.group_add_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Unirse a un hogar',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa el código del hogar',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Código de invitación',
                    hintText: '123456',
                    prefixIcon: Icon(Icons.pin),
                    helperText: 'Pide el código de 6 dígitos a tu pareja',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa el código';
                    }
                    if (value.length != 6) {
                      return 'El código debe tener 6 dígitos';
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _joinHousehold,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Unirse al hogar'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).pushReplacementNamed(
                            AppRouter.createHousehold,
                          );
                        },
                  child: const Text('¿Prefieres crear uno nuevo?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
