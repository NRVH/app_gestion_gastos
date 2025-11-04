import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';
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
              'NFTB Wallet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Para nosotros',
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
