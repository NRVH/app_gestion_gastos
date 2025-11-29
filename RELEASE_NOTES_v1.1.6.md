# Release Notes - v1.1.6

## 🐛 Fix Crítico: Aislamiento de Meses

### Problema Resuelto

Se corrigió un bug crítico donde las categorías acumulaban todos los gastos históricos en lugar de mostrar únicamente los del mes activo actual.

### Cambios principales

#### Sistema de Mes Activo (`currentActiveMonth`)
- ✅ Nuevo campo `currentActiveMonth` en Household para aislar completamente cada mes
- ✅ Los gastos e ingresos ahora se registran con el mes activo de la aplicación
- ✅ Las categorías solo muestran gastos del mes activo actual
- ✅ Correcto manejo del cierre de mes (independiente del mes calendario)

#### Mejoras en Providers
- 🔧 Eliminado filtrado duplicado en `expense_provider.dart`
- 🔧 Eliminado filtrado duplicado en `contribution_provider.dart`
- 🔧 Optimización de queries a Firestore
- 🔧 Mejor rendimiento al consultar gastos e ingresos

#### Correcciones Técnicas
- 🔨 Queries a Firestore ahora filtran correctamente por `currentActiveMonth`
- 🔨 Sorting en memoria para evitar índices compuestos innecesarios
- 🔨 Auto-inicialización de `currentActiveMonth` si no existe
- 🔨 Consistencia entre mes activo de la app y mes calendario

### Detalles técnicos

**Archivos modificados:**
- `lib/core/models/household.dart` - Agregado campo `currentActiveMonth`
- `lib/core/services/firestore_service.dart` - Filtrado por mes activo en queries
- `lib/core/providers/expense_provider.dart` - Removido filtrado duplicado
- `lib/core/providers/contribution_provider.dart` - Removido filtrado duplicado

**Comportamiento anterior:**
- ❌ Categorías mostraban suma de TODOS los gastos históricos
- ❌ No había aislamiento real entre meses
- ❌ Inconsistencias al cerrar mes

**Comportamiento nuevo:**
- ✅ Categorías muestran SOLO gastos del mes activo
- ✅ Aislamiento completo entre meses
- ✅ Mes activo independiente del calendario
- ✅ Cierre de mes funciona correctamente

### Información de versión
- **Versión:** 1.1.6
- **Build:** 9
- **Fecha:** Noviembre 28, 2025

---

## 📦 Instalación

Para instalar esta versión, descarga el APK desde los assets de este release.

## 🔄 Actualización desde versiones anteriores

**IMPORTANTE:** Esta versión incluye cambios en la estructura de datos:
- ✅ Se agrega automáticamente el campo `currentActiveMonth` a tu household
- ✅ Migración automática sin pérdida de datos
- ✅ Compatible con versiones anteriores

Puedes instalar directamente sobre cualquier versión anterior.

---

**Nota:** Este es un fix crítico que corrige el comportamiento fundamental de las categorías y el aislamiento de meses. Se recomienda actualizar inmediatamente.
