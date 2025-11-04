import 'package:flutter/material.dart';

/// Sistema de colores de la aplicación con Material You refinado
/// Basado en acentos dinámicos localizados (inspirado en One UI)
class AppColors {
  // ============================================================================
  // PALETA DE ACENTOS DINÁMICOS (seleccionados por el usuario)
  // ============================================================================
  
  /// Mapa de colores de acento disponibles para el usuario
  static const Map<String, Color> accentPalette = {
    'blue': Color(0xFF3D5AFE),      // Índigo brillante
    'red': Color(0xFFE53935),       // Rojo vibrante
    'green': Color(0xFF4CAF50),     // Verde Material
    'yellow': Color(0xFFFFB300),    // Amarillo ámbar
    'purple': Color(0xFF9C27B0),    // Púrpura profundo
    'orange': Color(0xFFFF6E40),    // Naranja intenso
    'teal': Color(0xFF00897B),      // Verde azulado
    'pink': Color(0xFFFF4081),      // Rosa acentuado
  };

  // ============================================================================
  // COLORES FUNCIONALES (independientes del tema de usuario)
  // ============================================================================
  
  /// Color para ingresos (siempre verde, sin importar el tema del usuario)
  static const Color income = Color(0xFF4CAF50);
  static const Color incomeLight = Color(0xFF81C784);
  static const Color incomeDark = Color(0xFF388E3C);
  
  /// Color para egresos (siempre rojo, sin importar el tema del usuario)
  static const Color expense = Color(0xFFE53935);
  static const Color expenseLight = Color(0xFFEF5350);
  static const Color expenseDark = Color(0xFFC62828);
  
  /// Color para categorías (amarillo)
  static const Color category = Color(0xFFFFB300);
  static const Color categoryLight = Color(0xFFFFCA28);
  static const Color categoryDark = Color(0xFFFFA000);
  
  /// Color para el botón flotante principal (FAB) - Rosa destacado
  static const Color fabPrimary = Color(0xFFFF4081);
  static const Color fabSecondary = Color(0xFFE91E63);
  
  // ============================================================================
  // SUPERFICIES Y FONDOS (Material Design 3)
  // ============================================================================
  
  /// Colores de fondo para modo oscuro
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  
  /// Colores de fondo para modo claro
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5);
  
  // ============================================================================
  // OVERLAYS Y ESTADOS
  // ============================================================================
  
  /// Overlay para hover en modo oscuro
  static const Color darkHover = Color(0x0DFFFFFF);
  
  /// Overlay para hover en modo claro
  static const Color lightHover = Color(0x0D000000);
  
  /// Overlay para estados presionados
  static const Color darkPressed = Color(0x1AFFFFFF);
  static const Color lightPressed = Color(0x1A000000);
  
  // ============================================================================
  // UTILIDADES
  // ============================================================================
  
  /// Obtiene el color de acento basado en el nombre
  static Color getAccentColor(String accentName) {
    return accentPalette[accentName] ?? accentPalette['blue']!;
  }
  
  /// Devuelve el color apropiado basado en el tipo de transacción
  static Color getTransactionColor(bool isIncome) {
    return isIncome ? income : expense;
  }
  
  /// Devuelve una variante del color según el brillo del tema
  static Color getTransactionColorVariant(bool isIncome, bool isDark) {
    if (isIncome) {
      return isDark ? incomeLight : incomeDark;
    } else {
      return isDark ? expenseLight : expenseDark;
    }
  }
  
  /// Devuelve el color de categoría según el brillo
  static Color getCategoryColor(bool isDark) {
    return isDark ? categoryLight : categoryDark;
  }
}
