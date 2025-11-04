import 'package:flutter/material.dart';

/// Sistema de paletas de colores completas para la aplicación
/// Inspirado en Material You / One UI con múltiples colores por paleta

// ============================================================================
// ENUMERACIÓN DE PALETAS DISPONIBLES
// ============================================================================

enum AppPaletteId {
  oceanBlue,
  sakuraPink,
  sunsetOrange,
  forestGreen,
  galaxyPurple,
  autumnBrown,
}

// ============================================================================
// MODELO DE PALETA
// ============================================================================

class AppPalette {
  /// Color principal - Botones principales, FAB, botón "Procesar"
  final Color primary;
  
  /// Color secundario - Tabs activos, iconos principales
  final Color secondary;
  
  /// Color terciario - Chips, etiquetas, pequeños acentos
  final Color tertiary;
  
  /// Color de peligro - Botones de eliminar / acciones destructivas
  final Color danger;
  
  /// Color de éxito - Estados de éxito (si aplica)
  final Color success;
  
  /// Color de advertencia - Avisos / badges de advertencia / categorías
  final Color warning;
  
  /// Nombre legible de la paleta
  final String displayName;

  const AppPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.danger,
    required this.success,
    required this.warning,
    required this.displayName,
  });
}

// ============================================================================
// DEFINICIÓN DE PALETAS
// ============================================================================

class AppPalettes {
  /// Ocean Blue - Azul intenso con toques turquesa y naranja
  static const oceanBlue = AppPalette(
    primary: Color(0xFF0D47A1),       // Azul intenso
    secondary: Color(0xFF00ACC1),     // Turquesa brillante
    tertiary: Color(0xFFFF6F00),      // Naranja/acento cálido
    danger: Color(0xFFD32F2F),        // Rojo fuerte
    success: Color(0xFF388E3C),       // Verde oscuro
    warning: Color(0xFFF57C00),       // Naranja advertencia
    displayName: 'Ocean Blue',
  );

  /// Sakura Pink - Rosa fuerte con morado y verde brillante
  static const sakuraPink = AppPalette(
    primary: Color(0xFFE91E63),       // Rosa fuerte
    secondary: Color(0xFF9C27B0),     // Morado
    tertiary: Color(0xFF00E676),      // Verde brillante
    danger: Color(0xFFC62828),        // Rojo oscuro
    success: Color(0xFF4CAF50),       // Verde medio
    warning: Color(0xFFFFC107),       // Amarillo advertencia
    displayName: 'Sakura Pink',
  );

  /// Sunset Orange - Naranja, rojo anaranjado y amarillo
  static const sunsetOrange = AppPalette(
    primary: Color(0xFFFF6D00),       // Naranja intenso
    secondary: Color(0xFFFF3D00),     // Rojo anaranjado
    tertiary: Color(0xFFFFD600),      // Amarillo brillante
    danger: Color(0xFFD50000),        // Rojo puro
    success: Color(0xFF43A047),       // Verde balanceado
    warning: Color(0xFFFF8F00),       // Naranja medio
    displayName: 'Sunset Orange',
  );

  /// Forest Green - Verde oscuro, verde medio y azul profundo
  static const forestGreen = AppPalette(
    primary: Color(0xFF2E7D32),       // Verde oscuro
    secondary: Color(0xFF66BB6A),     // Verde medio
    tertiary: Color(0xFF1565C0),      // Azul profundo
    danger: Color(0xFFD84315),        // Rojo terracota
    success: Color(0xFF4CAF50),       // Verde éxito
    warning: Color(0xFFFFA726),       // Naranja suave
    displayName: 'Forest Green',
  );

  /// Galaxy Purple - Morado intenso, magenta y azul eléctrico
  static const galaxyPurple = AppPalette(
    primary: Color(0xFF6A1B9A),       // Morado intenso
    secondary: Color(0xFFD81B60),     // Magenta
    tertiary: Color(0xFF2962FF),      // Azul eléctrico
    danger: Color(0xFFD32F2F),        // Rojo vibrante
    success: Color(0xFF43A047),       // Verde
    warning: Color(0xFFFB8C00),       // Naranja ámbar
    displayName: 'Galaxy Purple',
  );

  /// Autumn Brown - Café oscuro, naranja quemado y verde oliva
  static const autumnBrown = AppPalette(
    primary: Color(0xFF4E342E),       // Café oscuro
    secondary: Color(0xFFD84315),     // Naranja quemado
    tertiary: Color(0xFF689F38),      // Verde oliva
    danger: Color(0xFFC62828),        // Rojo oscuro
    success: Color(0xFF558B2F),       // Verde oscuro
    warning: Color(0xFFF57F17),       // Amarillo mostaza
    displayName: 'Autumn Brown',
  );

  /// Mapa de todas las paletas disponibles
  static const Map<AppPaletteId, AppPalette> palettes = {
    AppPaletteId.oceanBlue: oceanBlue,
    AppPaletteId.sakuraPink: sakuraPink,
    AppPaletteId.sunsetOrange: sunsetOrange,
    AppPaletteId.forestGreen: forestGreen,
    AppPaletteId.galaxyPurple: galaxyPurple,
    AppPaletteId.autumnBrown: autumnBrown,
  };

  /// Obtiene una paleta por su ID
  static AppPalette getPalette(AppPaletteId id) {
    return palettes[id]!;
  }

  /// Obtiene el nombre legible de una paleta
  static String getDisplayName(AppPaletteId id) {
    return palettes[id]!.displayName;
  }
}

// ============================================================================
// EXTENSION PARA ACCESO FÁCIL DESDE CONTEXT (requiere Riverpod)
// ============================================================================
// Esta extension se implementará en theme_config.dart donde está el provider
