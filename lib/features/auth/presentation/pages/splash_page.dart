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
    
    // Inicializar servicio de notificaciones
    try {
      print('🔔 [Splash] Iniciando servicio de notificaciones para user: ${user.uid}');
      final messagingService = ref.read(messagingServiceProvider);
      await messagingService.initialize();
      print('🔔 [Splash] Servicio de notificaciones inicializado');
      
      // Obtener el token y guardarlo en Firestore
      print('🔔 [Splash] Solicitando FCM token...');
      final token = await messagingService.getToken();
      if (token != null) {
        print('🔔 [Splash] FCM Token obtenido: $token');
        
        // Guardar token en Firestore para todos los households del usuario
        final firestoreService = ref.read(firestoreServiceProvider);
        print('🔔 [Splash] Obteniendo households del usuario...');
        final households = await firestoreService.watchUserHouseholds(user.uid).first;
        print('🔔 [Splash] Households encontrados: ${households.length}');
        
        for (final household in households) {
          print('🔔 [Splash] Guardando token en household: ${household.id}');
          await firestoreService.updateFcmToken(household.id, user.uid, token);
          print('🔔 [Splash] ✅ Token guardado exitosamente en household: ${household.id}');
        }
      } else {
        print('⚠️ [Splash] No se pudo obtener el FCM token');
        print('⚠️ [Splash] El usuario pudo haber denegado los permisos de notificación');
      }
      
      // Listener para actualizar token cuando se refresque
      messagingService.onTokenRefresh.listen((newToken) async {
        print('🔔 [Splash] Token refrescado: $newToken');
        final firestoreService = ref.read(firestoreServiceProvider);
        final households = await firestoreService.watchUserHouseholds(user.uid).first;
        
        for (final household in households) {
          await firestoreService.updateFcmToken(household.id, user.uid, newToken);
        }
      });
      
      // Escuchar mensajes cuando la app está en foreground
      messagingService.onMessage.listen((message) {
        print('🔔 [Foreground] Mensaje recibido: ${message.notification?.title}');
        print('🔔 [Foreground] Body: ${message.notification?.body}');
        print('🔔 [Foreground] Data: ${message.data}');
        
        // Mostrar notificación local o snackbar
        // TODO: Implementar notificación local si se requiere
      });
      
      // Escuchar cuando el usuario toca una notificación
      messagingService.onMessageOpenedApp.listen((message) {
        print('🔔 [Tapped] Usuario tocó notificación: ${message.notification?.title}');
        print('🔔 [Tapped] Data: ${message.data}');
        
        // TODO: Navegar a la pantalla correspondiente según message.data['type']
      });
      
      // Verificar si la app se abrió desde una notificación
      final initialMessage = await messagingService.getInitialMessage();
      if (initialMessage != null) {
        print('🔔 [Initial] App abierta desde notificación: ${initialMessage.notification?.title}');
        print('🔔 [Initial] Data: ${initialMessage.data}');
        
        // TODO: Navegar a la pantalla correspondiente
      }
    } catch (e) {
      print('❌ [Splash] Error al inicializar notificaciones: $e');
      // No bloqueamos la app si falla el servicio de notificaciones
    }
    
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
