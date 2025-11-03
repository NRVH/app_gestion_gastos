import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/messaging_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/household_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  // Inicializar notificaciones en segundo plano sin bloquear el flujo principal
  void _initializeNotificationsInBackground(String userId) {
    Future.microtask(() async {
      try {
        print('🔔 [Background] Iniciando servicio de notificaciones para user: $userId');
        final messagingService = ref.read(messagingServiceProvider);
        await messagingService.initialize();
        print('🔔 [Background] Servicio de notificaciones inicializado');
        
        // Obtener el token y guardarlo en Firestore
        print('🔔 [Background] Solicitando FCM token...');
        final token = await messagingService.getToken();
        if (token != null) {
          print('🔔 [Background] FCM Token obtenido: $token');
          
          // Guardar token en Firestore para todos los households del usuario
          final firestoreService = ref.read(firestoreServiceProvider);
          print('🔔 [Background] Obteniendo households del usuario...');
          final households = await firestoreService.watchUserHouseholds(userId).first;
          print('🔔 [Background] Households encontrados: ${households.length}');
          
          for (final household in households) {
            print('🔔 [Background] Guardando token en household: ${household.id}');
            await firestoreService.updateFcmToken(household.id, userId, token);
            print('🔔 [Background] ✅ Token guardado exitosamente en household: ${household.id}');
          }
        } else {
          print('⚠️ [Background] No se pudo obtener el FCM token');
        }
        
        // Listener para actualizar token cuando se refresque
        messagingService.onTokenRefresh.listen((newToken) async {
          print('🔔 [Background] Token refrescado: $newToken');
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
        print('❌ [Background] Error al inicializar notificaciones: $e');
      }
    });
  }

  Future<void> _checkAuth() async {
    // Esperar a que Firebase Auth se inicialice
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    // Esperar al estado de autenticación
    final authState = await ref.read(authStateProvider.future);
    
    if (!mounted) return;
    
    if (authState == null) {
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
      return;
    }
    
    final user = authState;
    
    // Inicializar servicio de notificaciones EN SEGUNDO PLANO (sin await)
    _initializeNotificationsInBackground(user.uid);
    
    try {
      // Check if user has a household
      final households = await ref.read(userHouseholdsProvider.future);
      
      if (!mounted) return;
      
      if (households.isEmpty) {
        print('🏠 [Splash] Usuario no tiene households, redirigiendo a crear/unir');
        Navigator.of(context).pushReplacementNamed(AppRouter.createHousehold);
      } else {
        print('🏠 [Splash] Usuario tiene ${households.length} household(s)');
        
        // Verificar si ya hay un household seleccionado guardado
        final savedHouseholdId = ref.read(currentHouseholdIdProvider);
        print('🏠 [Splash] Household guardado en SharedPreferences: $savedHouseholdId');
        
        // Si existe un household guardado y el usuario sigue siendo miembro, mantenerlo
        if (savedHouseholdId != null && 
            households.any((h) => h.id == savedHouseholdId)) {
          print('🏠 [Splash] Manteniendo household guardado: $savedHouseholdId');
          // No es necesario setHouseholdId, ya está en SharedPreferences
        } else {
          // Si no hay household guardado o ya no es miembro, seleccionar el primero
          print('🏠 [Splash] Seleccionando primer household: ${households.first.id}');
          await ref.read(currentHouseholdIdProvider.notifier).setHouseholdId(households.first.id);
        }
        
        Navigator.of(context).pushReplacementNamed(AppRouter.home);
      }
    } catch (e) {
      // Si hay error al obtener households (ej: permisos), redirigir a crear/unirse
      print('❌ [Splash] Error al verificar households: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRouter.createHousehold);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Gestión de Gastos',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Para parejas',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
