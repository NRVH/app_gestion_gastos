import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'app_palettes.dart';

// ============================================================================
// PROVIDERS DE TEMATIZACIÓN
// ============================================================================

/// Provider para el modo de tema (claro/oscuro/sistema)
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString('themeMode') ?? 'system';
    state = ThemeMode.values.firstWhere(
      (mode) => mode.name == themeModeString,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  void toggleTheme() {
    if (state == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}

// ============================================================================
// PROVIDER DE PALETA DINÁMICA
// ============================================================================

/// Provider para la paleta de colores seleccionada por el usuario
final appPaletteProvider =
    StateNotifierProvider<AppPaletteNotifier, AppPaletteId>(
  (ref) => AppPaletteNotifier(),
);

class AppPaletteNotifier extends StateNotifier<AppPaletteId> {
  AppPaletteNotifier() : super(AppPaletteId.oceanBlue) {
    _loadPalette();
  }

  Future<void> _loadPalette() async {
    final prefs = await SharedPreferences.getInstance();
    final paletteName = prefs.getString('appPalette') ?? 'oceanBlue';
    
    // Convertir el nombre a AppPaletteId
    try {
      state = AppPaletteId.values.firstWhere(
        (id) => id.name == paletteName,
        orElse: () => AppPaletteId.oceanBlue,
      );
    } catch (e) {
      state = AppPaletteId.oceanBlue; // Fallback seguro
    }
  }

  Future<void> setPalette(AppPaletteId paletteId) async {
    state = paletteId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appPalette', paletteId.name);
  }

  /// Obtiene la paleta actual completa
  AppPalette getCurrentPalette() {
    return AppPalettes.getPalette(state);
  }
}

// ============================================================================
// PROVIDER DE ACENTO DINÁMICO (LEGACY - Mantener para compatibilidad)
// ============================================================================

/// Provider legacy para retrocompatibilidad con código existente
@Deprecated('Use appPaletteProvider instead')
final accentColorProvider =
    StateNotifierProvider<AccentColorNotifier, String>(
  (ref) => AccentColorNotifier(ref),
);

@Deprecated('Use AppPaletteNotifier instead')
class AccentColorNotifier extends StateNotifier<String> {
  final Ref _ref;
  
  AccentColorNotifier(this._ref) : super('oceanBlue') {
    // Sincronizar con el nuevo provider
    _ref.listen<AppPaletteId>(appPaletteProvider, (previous, next) {
      state = next.name;
    });
  }

  Future<void> setAccentColor(String paletteName) async {
    try {
      final paletteId = AppPaletteId.values.firstWhere(
        (id) => id.name == paletteName,
        orElse: () => AppPaletteId.oceanBlue,
      );
      await _ref.read(appPaletteProvider.notifier).setPalette(paletteId);
    } catch (e) {
      // Fallback silencioso
    }
  }

  Color getCurrentAccentColor() {
    final paletteId = _ref.read(appPaletteProvider);
    return AppPalettes.getPalette(paletteId).primary;
  }
}

// ============================================================================
// SISTEMA DE TEMAS CON PALETAS COMPLETAS
// ============================================================================

class AppTheme {
  /// Tema claro con paleta completa (Material You refinado)
  static ThemeData lightTheme(AppPalette palette) {
    // Generar ColorScheme con Material 3 usando el color primario como semilla
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: Brightness.light,
      // Sobrescribir colores específicos para mantener coherencia
      surface: AppColors.lightSurface,
      background: AppColors.lightBackground,
      primary: palette.primary,
      secondary: palette.secondary,
      tertiary: palette.tertiary,
      error: palette.danger,
    );
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      
      // ========================================================================
      // SUPERFICIES Y FONDOS (sin afectar por el acento del usuario)
      // ========================================================================
      scaffoldBackgroundColor: AppColors.lightBackground,
      
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.transparent, // Evita tinte del acento
      ),
      
      cardTheme: CardThemeData(
        elevation: 2,
        color: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent, // Evita tinte del acento
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // ========================================================================
      // COMPONENTES CON ACENTO LOCALIZADO
      // ========================================================================
      
      // FloatingActionButton usa el color primario de la paleta
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // Campos de texto con borde de acento al enfocarse
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: palette.secondary, // Usa el color secundario
            width: 2,
          ),
        ),
      ),
      
      // Botones elevados usan el acento del ColorScheme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // Chips y selecciones usan el acento
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceVariant,
        selectedColor: colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Switch y checkbox con acento
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return palette.secondary;
          }
          return null;
        }),
      ),
      
      // Tab bar con color secundario
      tabBarTheme: TabBarThemeData(
        labelColor: palette.secondary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: palette.secondary,
      ),
    );
  }

  /// Tema oscuro con paleta completa (Material You refinado)
  static ThemeData darkTheme(AppPalette palette) {
    // Generar ColorScheme con Material 3 usando el color primario como semilla
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: Brightness.dark,
      // Sobrescribir colores específicos para mantener coherencia
      surface: AppColors.darkSurface,
      background: AppColors.darkBackground,
      primary: palette.primary,
      secondary: palette.secondary,
      tertiary: palette.tertiary,
      error: palette.danger,
    );
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      
      // ========================================================================
      // SUPERFICIES Y FONDOS (sin afectar por el acento del usuario)
      // ========================================================================
      scaffoldBackgroundColor: AppColors.darkBackground,
      
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent, // Evita tinte del acento
      ),
      
      cardTheme: CardThemeData(
        elevation: 2,
        color: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent, // Evita tinte del acento
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // ========================================================================
      // COMPONENTES CON ACENTO LOCALIZADO
      // ========================================================================
      
      // FloatingActionButton usa el color primario de la paleta
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // Campos de texto con borde de acento al enfocarse
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: palette.secondary, // Usa el color secundario
            width: 2,
          ),
        ),
      ),
      
      // Botones elevados usan el acento del ColorScheme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // Chips y selecciones usan el acento
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        selectedColor: colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Switch y checkbox con acento
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return palette.secondary;
          }
          return null;
        }),
      ),
      
      // Tab bar con color secundario
      tabBarTheme: TabBarThemeData(
        labelColor: palette.secondary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: palette.secondary,
      ),
    );
  }
}

// ============================================================================
// EXTENSION PARA ACCESO FÁCIL A LA PALETA DESDE CUALQUIER WIDGET
// ============================================================================

extension AppPaletteContextExtension on BuildContext {
  /// Acceso rápido a la paleta actual desde cualquier widget con Riverpod
  /// Uso: context.appPalette.primary
  /// 
  /// Requiere que el widget esté envuelto en ProviderScope o sea ConsumerWidget
  AppPalette get appPalette {
    // Intentar obtener el ProviderContainer del contexto
    try {
      // Buscar el ProviderScope más cercano
      final container = ProviderScope.containerOf(this, listen: false);
      final paletteId = container.read(appPaletteProvider);
      return AppPalettes.getPalette(paletteId);
    } catch (e) {
      // Fallback en caso de que no haya ProviderScope
      return AppPalettes.oceanBlue;
    }
  }
  
  /// Versión reactiva para widgets que necesitan reconstruirse al cambiar la paleta
  /// Solo funciona en ConsumerWidget o widgets con acceso a WidgetRef
  AppPalette watchAppPalette(WidgetRef ref) {
    final paletteId = ref.watch(appPaletteProvider);
    return AppPalettes.getPalette(paletteId);
  }
}
