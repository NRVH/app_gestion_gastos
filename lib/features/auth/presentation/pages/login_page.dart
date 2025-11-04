import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/messaging_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/providers/household_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Inicializa el servicio de notificaciones después del login exitoso
  Future<void> _initializeNotifications(String userId) async {
    try {
      print('🔔 [Login] Iniciando servicio de notificaciones para user: $userId');
      final messagingService = ref.read(messagingServiceProvider);
      
      // Solicitar permisos e inicializar
      await messagingService.initialize();
      print('🔔 [Login] Servicio de notificaciones inicializado');
      
      // Obtener el token y guardarlo en Firestore
      final token = await messagingService.getToken();
      if (token != null) {
        print('🔔 [Login] FCM Token obtenido: $token');
        
        // Guardar token en Firestore para todos los households del usuario
        final firestoreService = ref.read(firestoreServiceProvider);
        final households = await firestoreService.watchUserHouseholds(userId).first;
        
        for (final household in households) {
          await firestoreService.updateFcmToken(household.id, userId, token);
          print('🔔 [Login] ✅ Token guardado en household: ${household.id}');
        }
      }
      
      // Configurar listener para actualizar token cuando se refresque
      messagingService.onTokenRefresh.listen((newToken) async {
        print('🔔 [Login] Token refrescado: $newToken');
        final firestoreService = ref.read(firestoreServiceProvider);
        final households = await firestoreService.watchUserHouseholds(userId).first;
        
        for (final household in households) {
          await firestoreService.updateFcmToken(household.id, userId, newToken);
        }
      });
      
      // Escuchar mensajes cuando la app está en foreground
      messagingService.onMessage.listen((message) {
        print('🔔 [Foreground] Mensaje recibido: ${message.notification?.title}');
      });
      
      // Escuchar cuando el usuario toca una notificación
      messagingService.onMessageOpenedApp.listen((message) {
        print('🔔 [Tapped] Usuario tocó notificación: ${message.notification?.title}');
      });
      
      // Verificar si la app se abrió desde una notificación
      final initialMessage = await messagingService.getInitialMessage();
      if (initialMessage != null) {
        print('🔔 [Initial] App abierta desde notificación: ${initialMessage.notification?.title}');
      }
    } catch (e) {
      print('❌ [Login] Error al inicializar notificaciones: $e');
      // No bloqueamos el flujo de login si falla la inicialización de notificaciones
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      // Check if user has a household
      final user = ref.read(currentUserProvider);
      if (user != null) {
        // Inicializar notificaciones después del login exitoso
        await _initializeNotifications(user.uid);
        
        final households = await ref.read(userHouseholdsProvider.future);
        
        if (households.isEmpty) {
          Navigator.of(context).pushReplacementNamed(AppRouter.createHousehold);
        } else {
          await ref.read(currentHouseholdIdProvider.notifier).setHouseholdId(households.first.id);
          Navigator.of(context).pushReplacementNamed(AppRouter.home);
        }
      }
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

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final userCredential = await ref.read(authServiceProvider).signInWithGoogle();
      
      if (userCredential == null) {
        // User canceled
        setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;

      // Check if user has a household
      final user = ref.read(currentUserProvider);
      if (user != null) {
        // Inicializar notificaciones después del login exitoso
        await _initializeNotifications(user.uid);
        
        final households = await ref.read(userHouseholdsProvider.future);
        
        if (households.isEmpty) {
          Navigator.of(context).pushReplacementNamed(AppRouter.createHousehold);
        } else {
          await ref.read(currentHouseholdIdProvider.notifier).setHouseholdId(households.first.id);
          Navigator.of(context).pushReplacementNamed(AppRouter.home);
        }
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bienvenido',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inicia sesión para continuar',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: Validators.password,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'O',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Image.asset(
                      'assets/google_logo.png',
                      height: 24,
                      width: 24,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.login, size: 24);
                      },
                    ),
                    label: const Text('Iniciar sesión con Google'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).pushNamed(AppRouter.register);
                          },
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
