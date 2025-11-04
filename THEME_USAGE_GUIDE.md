# Guía de Uso: Sistema de Tematización con Acentos Dinámicos

## 📋 Resumen de Cambios

Se ha implementado un sistema de tematización refinado inspirado en Material You y One UI que permite:

- ✅ Mantener fondos y superficies coherentes con Material Design 3
- ✅ Aplicar colores de acento solo en elementos específicos
- ✅ Usar colores funcionales para tipos de contenido (ingresos, egresos, categorías)
- ✅ Botón FAB en rosa destacado
- ✅ Compatibilidad total con modo claro y oscuro

---

## 📁 Archivos Modificados

### Nuevos Archivos Creados:

1. **`lib/core/config/app_colors.dart`**
   - Define la paleta de acentos disponibles
   - Contiene colores funcionales (ingresos, egresos, categorías, FAB)
   - Métodos helper para obtener colores según el contexto

2. **`lib/core/utils/theme_extensions.dart`**
   - Extensions para acceder fácilmente a colores desde `BuildContext`
   - Widgets helper: `TransactionColorBox`, `CategoryChip`, `TransactionIndicator`

3. **`THEME_USAGE_GUIDE.md`** (este archivo)
   - Documentación completa del nuevo sistema

### Archivos Modificados:

1. **`lib/core/config/theme_config.dart`**
   - Cambio de `AppColorScheme` enum a sistema de acentos con `String`
   - Nuevo provider: `accentColorProvider`
   - Temas optimizados para no afectar fondos globales

2. **`lib/main.dart`**
   - Actualizado para usar `accentColorProvider` en lugar de `colorSchemeProvider`

3. **`lib/features/settings/presentation/pages/settings_page.dart`**
   - Selector visual mejorado para colores de acento (grid con vista previa)
   - Actualizado para usar el nuevo sistema

---

## 🎨 Colores Disponibles

### Paleta de Acentos (seleccionables por el usuario)

```dart
AppColors.accentPalette = {
  'blue': Color(0xFF3D5AFE),
  'red': Color(0xFFE53935),
  'green': Color(0xFF4CAF50),
  'yellow': Color(0xFFFFB300),
  'purple': Color(0xFF9C27B0),
  'orange': Color(0xFFFF6E40),
  'teal': Color(0xFF00897B),
  'pink': Color(0xFFFF4081),
}
```

### Colores Funcionales (fijos, no cambian con el acento)

```dart
// Ingresos (verde)
AppColors.income = Color(0xFF4CAF50)

// Egresos (rojo)
AppColors.expense = Color(0xFFE53935)

// Categorías (amarillo)
AppColors.category = Color(0xFFFFB300)

// Botón FAB (rosa)
AppColors.fabPrimary = Color(0xFFFF4081)
```

### Fondos y Superficies

```dart
// Modo Oscuro
AppColors.darkBackground = Color(0xFF121212)
AppColors.darkSurface = Color(0xFF1E1E1E)

// Modo Claro
AppColors.lightBackground = Color(0xFFFAFAFA)
AppColors.lightSurface = Color(0xFFFFFFFF)
```

---

## 💡 Cómo Usar los Colores

### Opción 1: Usando Extensions (Recomendado)

```dart
import 'package:app_gestion_gastos/core/utils/theme_extensions.dart';

Widget build(BuildContext context) {
  // Obtener colores funcionales
  final incomeColor = context.incomeColor;
  final expenseColor = context.expenseColor;
  final categoryColor = context.categoryColor;
  final fabColor = context.fabColor;
  
  // Obtener color según tipo
  final transactionColor = context.transactionColor(isIncome: true);
  
  // Obtener variante según el tema actual
  final variantColor = context.transactionColorVariant(isIncome: false);
  
  // Verificar si es modo oscuro
  final isDark = context.isDarkMode;
}
```

### Opción 2: Usando AppColors Directamente

```dart
import 'package:app_gestion_gastos/core/config/app_colors.dart';

Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  // Colores funcionales
  final incomeColor = AppColors.income;
  final expenseColor = AppColors.expense;
  final categoryColor = AppColors.getCategoryColor(isDark);
  
  // Color de acento actual (desde provider)
  final accentColor = AppColors.getAccentColor('blue');
}
```

---

## 🔧 Ejemplos de Implementación

### 1. FloatingActionButton (FAB)

El FAB ya está configurado globalmente en el tema con el color rosa:

```dart
FloatingActionButton(
  onPressed: () {
    // Acción
  },
  child: Icon(Icons.add),
)
// Automáticamente usa AppColors.fabPrimary (rosa)
```

Si necesitas sobrescribir el color:

```dart
FloatingActionButton(
  onPressed: () {},
  backgroundColor: context.fabColor, // O cualquier otro color
  child: Icon(Icons.add),
)
```

### 2. Tarjetas de Transacciones (Ingresos/Egresos)

```dart
Card(
  child: ListTile(
    leading: TransactionIndicator(
      isIncome: transaction.isIncome,
    ),
    title: Text(transaction.description),
    trailing: Text(
      CurrencyFormatter.format(transaction.amount),
      style: TextStyle(
        color: context.transactionColor(transaction.isIncome),
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
)
```

### 3. Botones de Acción (Agregar Ingreso/Egreso)

```dart
ElevatedButton.icon(
  onPressed: () => _addIncome(),
  icon: Icon(Icons.add),
  label: Text('Agregar Ingreso'),
  style: ElevatedButton.styleFrom(
    backgroundColor: context.incomeColor,
    foregroundColor: Colors.white,
  ),
)

ElevatedButton.icon(
  onPressed: () => _addExpense(),
  icon: Icon(Icons.remove),
  label: Text('Agregar Egreso'),
  style: ElevatedButton.styleFrom(
    backgroundColor: context.expenseColor,
    foregroundColor: Colors.white,
  ),
)
```

### 4. Categorías

#### Botón para agregar/editar categoría:

```dart
FloatingActionButton(
  onPressed: () => _addCategory(),
  backgroundColor: context.categoryColor,
  child: Icon(Icons.add),
)
```

#### Chip de categoría:

```dart
CategoryChip(
  label: 'Supermercado',
  icon: Icons.shopping_cart,
  isSelected: selectedCategory == 'Supermercado',
  onTap: () => setState(() => selectedCategory = 'Supermercado'),
)
```

#### Container con color de categoría:

```dart
Container(
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: context.categoryColor.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: context.categoryColor,
      width: 2,
    ),
  ),
  child: Text('Categoría'),
)
```

### 5. Indicadores Visuales

```dart
// Indicador de ingreso/egreso con ícono
TransactionIndicator(
  isIncome: true,
  size: 32,
  showIcon: true,
)

// Container con color de transacción
TransactionColorBox(
  isIncome: false,
  padding: EdgeInsets.all(16),
  child: Column(
    children: [
      Text('Total Egresos'),
      Text('\$1,234.56'),
    ],
  ),
)
```

### 6. Gráficos y Estadísticas

```dart
// Para gráficos de barras, líneas, etc.
PieChart(
  PieChartData(
    sections: [
      PieChartSectionData(
        value: incomeTotal,
        color: context.incomeColor,
        title: 'Ingresos',
      ),
      PieChartSectionData(
        value: expenseTotal,
        color: context.expenseColor,
        title: 'Egresos',
      ),
    ],
  ),
)
```

---

## ⚠️ Reglas Importantes

### ✅ HACER:

1. **Usar colores funcionales para elementos específicos:**
   - Ingresos → Verde (`context.incomeColor`)
   - Egresos → Rojo (`context.expenseColor`)
   - Categorías → Amarillo (`context.categoryColor`)
   - FAB principal → Rosa (automático por tema)

2. **Usar el acento del usuario solo en:**
   - Elementos interactivos seleccionados
   - Bordes de campos de texto al enfocarse
   - Switch, checkbox, radio buttons
   - Chips seleccionados
   - Botones de acción secundarios

3. **Dejar que el tema gestione:**
   - Fondos de Scaffold
   - Color de Cards
   - AppBar
   - Superficies generales

### ❌ NO HACER:

1. **No sobrescribir colores de fondo globales:**
   ```dart
   // ❌ MAL
   Scaffold(
     backgroundColor: Colors.blue, // No hagas esto
   )
   
   // ✅ BIEN
   Scaffold(
     // Usa el color del tema automáticamente
   )
   ```

2. **No usar el acento del usuario para ingresos/egresos:**
   ```dart
   // ❌ MAL
   Text(
     amount,
     style: TextStyle(color: Theme.of(context).colorScheme.primary),
   )
   
   // ✅ BIEN
   Text(
     amount,
     style: TextStyle(color: context.transactionColor(isIncome)),
   )
   ```

3. **No mezclar colores de acento con colores funcionales:**
   - Los colores funcionales (verde, rojo, amarillo) son independientes del acento elegido

---

## 🔄 Migración de Código Existente

Si encuentras código como este:

```dart
// Antes (sistema antiguo)
backgroundColor: Theme.of(context).colorScheme.primary
```

Evalúa qué representa:

- **Si es un ingreso:** usa `context.incomeColor`
- **Si es un egreso:** usa `context.expenseColor`
- **Si es una categoría:** usa `context.categoryColor`
- **Si es el FAB principal:** no cambies nada (ya está configurado globalmente)
- **Si es un elemento interactivo:** puede seguir usando `Theme.of(context).colorScheme.primary`

---

## 🧪 Testing en Modo Claro y Oscuro

Para verificar que todo funciona correctamente:

1. Abre la app en modo claro
2. Verifica que:
   - Fondos son blancos/gris claro
   - Colores funcionales son visibles
   - El acento solo afecta elementos específicos

3. Cambia a modo oscuro
4. Verifica que:
   - Fondos son grises oscuros (#121212, #1E1E1E)
   - Colores funcionales siguen siendo visibles
   - El contraste es adecuado

5. Cambia el color de acento desde Configuración
6. Verifica que:
   - Solo los elementos específicos cambian de color
   - Los fondos permanecen iguales
   - Los colores funcionales no cambian

---

## 📞 Soporte

Si tienes dudas sobre cómo implementar un color específico, consulta:

1. `app_colors.dart` - Definiciones de colores
2. `theme_extensions.dart` - Extensions y widgets helper
3. Este archivo - Ejemplos de uso

---

**Última actualización:** Noviembre 2025
**Sistema de tema:** Material You refinado con acentos localizados
