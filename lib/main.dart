import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/theme_config.dart';
import 'core/config/app_palettes.dart';
import 'core/router/app_router.dart';
import 'core/providers/household_provider.dart';
import 'core/services/messaging_service.dart';
import 'firebase_options.dart';

// Background message handler (debe ser función de nivel superior)
// Solo funciona en móviles (Android/iOS), no en Web
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('🔔 [Background] Mensaje recibido: ${message.notification?.title}');
  print('🔔 [Background] Body: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar formato de fechas en español
  await initializeDateFormatting('es_ES', null);
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Registrar el handler de mensajes en background solo en móvil
  // Firebase Messaging background handler no está soportado en Web
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('🔔 [Main] Firebase Messaging background handler registrado');
  } else {
    print('🌐 [Main] Ejecutando en Web - Background messaging no disponible');
  }
  
  // Inicializar SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final paletteId = ref.watch(appPaletteProvider);
    final palette = AppPalettes.getPalette(paletteId);
    
    return MaterialApp(
      title: 'Gestión Gastos Parejas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(palette),
      darkTheme: AppTheme.darkTheme(palette),
      themeMode: themeMode,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.splash,
    );
  }
}
