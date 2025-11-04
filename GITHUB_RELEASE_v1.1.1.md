# 🐛 v1.1.1 - Corrección Sistema de Actualizaciones

**Tipo:** Hotfix  
**Fecha:** 4 de noviembre de 2025

---

## 🎯 ¿Qué se arregló?

Esta versión corrige **problemas críticos** en el sistema de actualizaciones que afectaban la experiencia de los usuarios al actualizar la app.

### 🐛 Problemas Resueltos

#### 1. **Errores obsoletos en changelog**
- ❌ **Antes:** Mostraba "Excepción: No hay releases publicados en GitHub" en releases válidos
- ✅ **Ahora:** Limpia automáticamente errores antiguos cuando detecta un release válido

#### 2. **Notificación incorrecta después de actualizar**
- ❌ **Antes:** Después de instalar v1.1.0, seguía mostrando "actualización disponible v1.1.0"
- ✅ **Ahora:** Detecta correctamente que la versión ya está instalada y limpia el caché

#### 3. **Caché obsoleto acumulado**
- ❌ **Antes:** Guardaba errores de red y problemas de conexión indefinidamente
- ✅ **Ahora:** Limpia caché automáticamente en errores 404, timeouts, y problemas de conexión

---

## ✨ Mejoras Implementadas

- 🧹 **Limpieza automática de caché** en errores de API (404, 403, 500)
- 🔍 **Verificación de versión instalada** al iniciar la app
- 🚀 **Prevención de notificaciones duplicadas** después de actualizar
- 🛡️ **Gestión mejorada de errores** de red y timeout

---

## 📦 Información Técnica

**Versión:** 1.1.1+6  
**Tamaño:** ~62 MB  
**Android Mínimo:** 5.0 (API 21+)  
**Android Target:** 14 (API 34)

---

## 🚀 ¿Cómo actualizar?

1. Descarga `app-gestion-gastos-v1.1.1.apk` abajo
2. Instala sobre tu versión actual
3. ¡Listo! El sistema de actualizaciones funcionará correctamente

---

## 📝 Recomendación

**Se recomienda actualizar inmediatamente** para garantizar el correcto funcionamiento del sistema de actualizaciones automáticas en futuras versiones.

---

**Changelog Completo:** Ver [RELEASE_NOTES_v1.1.1.md](./RELEASE_NOTES_v1.1.1.md)  
**Comparación:** https://github.com/NRVH/app_gestion_gastos/compare/v1.1.0...v1.1.1
