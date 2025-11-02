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
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final user = ref.read(currentUserProvider);
    
    if (user == null) {
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
      return;
    }
    
    // Inicializar servicio de notificaciones
    try {
      final messagingService = ref.read(messagingServiceProvider);
      await messagingService.initialize();
      
      // Obtener el token y guardarlo en Firestore
      final token = await messagingService.getToken();
      if (token != null) {
        print('FCM Token obtenido: $token');
        
        // Guardar token en Firestore para todos los households del usuario
        final firestoreService = ref.read(firestoreServiceProvider);
        final households = await firestoreService.watchUserHouseholds(user.uid).first;
        
        for (final household in households) {
          await firestoreService.updateFcmToken(household.id, user.uid, token);
          print('Token guardado en household: ${household.id}');
        }
      }
      
      // Listener para actualizar token cuando se refresque
      messagingService.onTokenRefresh.listen((newToken) async {
        print('Token refrescado: $newToken');
        final firestoreService = ref.read(firestoreServiceProvider);
        final households = await firestoreService.watchUserHouseholds(user.uid).first;
        
        for (final household in households) {
          await firestoreService.updateFcmToken(household.id, user.uid, newToken);
        }
      });
    } catch (e) {
      print('Error al inicializar notificaciones: $e');
      // No bloqueamos la app si falla el servicio de notificaciones
    }
    
    try {
      // Check if user has a household
      final households = await ref.read(userHouseholdsProvider.future);
      
      if (!mounted) return;
      
      if (households.isEmpty) {
        Navigator.of(context).pushReplacementNamed(AppRouter.createHousehold);
      } else {
        // Set the first household as current
        ref.read(currentHouseholdIdProvider.notifier).state = households.first.id;
        Navigator.of(context).pushReplacementNamed(AppRouter.home);
      }
    } catch (e) {
      // Si hay error al obtener households (ej: permisos), redirigir a crear/unirse
      print('Error al verificar households: $e');
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
