# 📱 Sistema de Actualización Automática

## 🎯 Descripción General

La aplicación ahora cuenta con un sistema profesional de actualización automática basado en GitHub Releases. El sistema detecta nuevas versiones automáticamente y permite a los usuarios actualizar la app sin necesidad de descargar e instalar manualmente.

## ✨ Características

### 1. **Detección Automática**
- Verifica actualizaciones cada 24 horas automáticamente
- Check inicial al abrir la app
- Cache inteligente para evitar consultas innecesarias

### 2. **Badge de Notificación**
- Badge naranja en el tab "Config" cuando hay actualización disponible
- Visual y no intrusivo

### 3. **UI Profesional**
- Pantalla dedicada con toda la información del release
- Muestra versión, fecha, tamaño y changelog
- Progress bar durante la descarga
- Diseño adaptado para modo claro y oscuro

### 4. **Descarga e Instalación**
- Descarga directa del APK desde GitHub Releases
- Barra de progreso en tiempo real
- Apertura automática del instalador
- Manejo robusto de errores

## 🚀 Cómo Funciona

### Para Usuarios:

1. **Notificación**: Cuando hay una actualización, aparece un badge naranja en "Config"
2. **Navegación**: Ir a Config → "Buscar actualizaciones"
3. **Detalles**: Ver información completa del release (versión, changelog, tamaño)
4. **Actualizar**: Tocar "Descargar e Instalar"
5. **Instalación**: La app descarga el APK y abre el instalador de Android

### Para Desarrolladores:

#### Crear un Release:

1. **Subir cambios a GitHub**:
```bash
git add .
git commit -m "feat: Nuevas características..."
git push origin master
```

2. **Crear un tag**:
```bash
git tag v1.0.1
git push origin v1.0.1
```

3. **Crear Release en GitHub**:
   - Ve a tu repositorio → Releases → "Create a new release"
   - Selecciona el tag que acabas de crear (ej: `v1.0.1`)
   - Título: `Versión 1.0.1`
   - Descripción: Changelog con los cambios (usa Markdown)
   - Adjuntar el APK: `app-release.apk`
   - Publicar release

4. **Actualizar versión en pubspec.yaml**:
```yaml
version: 1.0.1+2  # Incrementar versión y build number
```

## 📋 Estructura del Sistema

### Servicios

#### `update_service.dart`
- **Responsabilidad**: Interactuar con GitHub API y manejar descargas
- **Métodos principales**:
  - `checkForUpdates()`: Consulta GitHub API por nuevos releases
  - `downloadAndInstall()`: Descarga APK y abre instalador
  - Cache y persistencia con SharedPreferences

### Providers

#### `update_provider.dart`
- **Estado**: Actualización disponible, progreso, errores
- **Notifier**: Maneja la lógica de actualización
- **Providers derivados**: `hasUpdateAvailableProvider` para el badge

### UI

#### `SettingsPage`
- Sección "Actualización" con información de versión
- Botón para verificar actualizaciones manualmente
- Navegación a página de detalles

#### `UpdateDetailsPage`
- Header con icono y versión
- Información del release (fecha, tamaño)
- Changelog completo
- Botón de descarga con progress bar
- Manejo de errores visuales

#### `MainPage`
- Badge naranja en tab "Config"
- Check automático al iniciar la app

## 🔧 Configuración

### Cambiar repositorio

Si necesitas cambiar el repositorio de GitHub, edita `update_service.dart`:

```dart
static const String _githubOwner = 'TU_USUARIO';
static const String _githubRepo = 'TU_REPOSITORIO';
```

### Personalizar intervalo de verificación

Cambia el intervalo de verificación automática en `update_service.dart`:

```dart
bool _shouldCheckForUpdates() {
  if (_lastCheck == null) return true;
  final now = DateTime.now();
  final difference = now.difference(_lastCheck!);
  return difference.inHours >= 24; // Cambiar 24 por el valor deseado
}
```

## 🎨 Personalización Visual

### Colores

Los colores se adaptan automáticamente al tema (claro/oscuro). Para personalizar:

- **Badge**: Naranja (`Colors.orange`)
- **Botón principal**: Color primario del tema
- **Progress bar**: Color primario del tema

### Textos

Todos los textos están en español. Para cambiarlos, busca en:
- `settings_page.dart`: Sección de actualización
- `update_details_page.dart`: Pantalla de detalles

## 📱 Permisos Requeridos

### Android

El sistema requiere permisos para:
- **Internet**: Descargar actualizaciones
- **Instalar paquetes**: El usuario debe aceptar instalar desde fuentes desconocidas

En `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

## 🐛 Troubleshooting

### La app no detecta actualizaciones

1. Verifica que el release esté publicado en GitHub
2. Asegúrate de que el tag tiene formato `vX.Y.Z` (ej: `v1.0.1`)
3. Verifica que el APK esté adjunto al release
4. Revisa la conexión a internet

### El instalador no se abre

1. Verifica que el APK se haya descargado correctamente
2. El usuario debe permitir instalar desde fuentes desconocidas
3. Revisa los logs con `flutter logs`

### Errores de comparación de versiones

1. Asegúrate de que `pubspec.yaml` tenga el formato correcto: `version: X.Y.Z+BUILD`
2. El tag en GitHub debe ser `vX.Y.Z`
3. La versión en `pubspec.yaml` debe coincidir con el tag (sin la 'v')

## 📊 Monitoreo

El sistema imprime logs detallados en consola:

```
🔍 [Update] Verificando actualizaciones en GitHub...
📱 [Update] Versión actual: 1.0.0
🆕 [Update] Última versión en GitHub: 1.0.1
✨ [Update] ¡Nueva versión disponible!
⬇️ [Update] Descargando APK desde: https://...
⬇️ [Update] Progreso: 50.0%
✅ [Update] APK descargado: /data/...
📦 [Update] Abriendo instalador...
```

## 🔒 Seguridad

- **HTTPS**: Todas las comunicaciones usan HTTPS
- **GitHub API**: Autenticidad de los releases verificada
- **No auto-instalación**: Requiere confirmación del usuario
- **Cache seguro**: Usa SharedPreferences de forma segura

## 🎯 Buenas Prácticas

1. **Semantic Versioning**: Usa versionado semántico (MAJOR.MINOR.PATCH)
2. **Changelog detallado**: Incluye changelog completo en cada release
3. **Testing**: Prueba cada release antes de publicar
4. **Tamaño del APK**: Optimiza el tamaño del APK antes de publicar
5. **Rollback**: Mantén versiones anteriores por si necesitas rollback

## 📝 Ejemplo de Changelog

```markdown
## 🎉 Versión 1.0.1

### ✨ Nuevas Características
- Sistema de actualización automática
- Badge de notificación en Config
- Página de detalles de actualización con changelog

### 🐛 Correcciones
- Corregido problema de inicio de sesión lento
- Arreglado ordenamiento de categorías

### 🎨 Mejoras
- Optimización de colores en modo oscuro
- Mejor rendimiento en listas grandes

### 📦 Tamaño
- APK: 57.6 MB
```

## 🚀 Próximas Mejoras

Posibles mejoras futuras:
- [ ] Actualizaciones delta (solo cambios)
- [ ] Notificaciones push para actualizaciones críticas
- [ ] Opción de actualización silenciosa
- [ ] Historial de versiones
- [ ] Rollback automático si falla

---

**Última actualización**: 2 de noviembre de 2025
**Versión del sistema**: 1.0.0
