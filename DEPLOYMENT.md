# 🚀 Guía de Despliegue

## 📱 Despliegue en Android (Google Play)

### Paso 1: Configurar Keystore

```bash
# Generar keystore
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Anotar:
# - Contraseña del keystore
# - Contraseña de la key
# - Alias: upload
```

### Paso 2: Crear key.properties

Crear archivo `android/key.properties`:
```properties
storePassword=tu_store_password
keyPassword=tu_key_password
keyAlias=upload
storeFile=/Users/tu-usuario/upload-keystore.jks
```

### Paso 3: Configurar build.gradle

En `android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    
    defaultConfig {
        applicationId "com.tuempresa.appgestiongastos"
        minSdkVersion 21
        targetSdkVersion 33
        versionCode 1
        versionName "1.0.0"
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

### Paso 4: Build APK/AAB

```bash
# Para APK (testing)
flutter build apk --release

# Para AAB (Google Play - recomendado)
flutter build appbundle --release

# Salida:
# build/app/outputs/bundle/release/app-release.aab
```

### Paso 5: Google Play Console

1. Ve a [Google Play Console](https://play.google.com/console)
2. Crear nueva aplicación
3. Completar:
   - Ficha de la tienda (descripción, capturas)
   - Clasificación de contenido
   - Precios y distribución
4. Subir AAB en "Producción"
5. Enviar a revisión

---

## 🍎 Despliegue en iOS (App Store)

### Paso 1: Configurar Bundle ID

En Xcode:
1. Abrir `ios/Runner.xcworkspace`
2. Seleccionar Runner → General
3. Bundle Identifier: `com.tuempresa.appgestiongastos`
4. Team: Tu cuenta de developer

### Paso 2: Certificados y Perfiles

En [Apple Developer](https://developer.apple.com):
1. Certificates → Crear iOS Distribution Certificate
2. Identifiers → Crear App ID con Push Notifications
3. Profiles → Crear App Store Distribution Profile

### Paso 3: Capabilities

En Xcode, habilitar:
- ✅ Push Notifications
- ✅ Background Modes → Remote notifications
- ✅ Sign in with Apple (opcional)

### Paso 4: Build IPA

```bash
# Desde raíz del proyecto
flutter build ios --release

# Abrir Xcode
open ios/Runner.xcworkspace

# En Xcode:
# 1. Product → Archive
# 2. Window → Organizer
# 3. Distribute App → App Store Connect
# 4. Upload
```

### Paso 5: App Store Connect

1. Ve a [App Store Connect](https://appstoreconnect.apple.com)
2. Mis Apps → + → Nueva App
3. Completar:
   - Información de la app
   - Precios y disponibilidad
   - Capturas de pantalla (5.5", 6.5")
   - Descripción, palabras clave
4. Enviar a revisión

---

## 🌐 Despliegue Web (Firebase Hosting)

### Paso 1: Build Web

```bash
flutter build web --release
```

### Paso 2: Deploy a Firebase

```bash
firebase deploy --only hosting
```

### Paso 3: Custom Domain (opcional)

```bash
firebase hosting:channel:deploy production
```

URL: https://tu-proyecto.web.app

---

## ☁️ Cloud Functions en Producción

### Deploy Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### Monitoreo de Functions

```bash
# Ver logs en tiempo real
firebase functions:log --only onContributionCreated

# Ver métricas
# Firebase Console → Functions → Métricas
```

---

## 🔒 Checklist de Seguridad Pre-Deploy

- [ ] Firebase Rules desplegadas y probadas
- [ ] API Keys protegidas (no expuestas en código)
- [ ] Manejo de errores implementado
- [ ] Validación de datos en Cloud Functions
- [ ] HTTPS en todas las comunicaciones
- [ ] Tokens FCM actualizados correctamente
- [ ] Testing en dispositivos reales
- [ ] Política de privacidad publicada
- [ ] Términos y condiciones disponibles

---

## 📊 Configurar Analytics

### Firebase Analytics

```dart
dependencies:
  firebase_analytics: ^10.7.4

// lib/main.dart
import 'package:firebase_analytics/firebase_analytics.dart';

final analytics = FirebaseAnalytics.instance;

// Trackear eventos
await analytics.logEvent(
  name: 'add_expense',
  parameters: {
    'amount': 1000,
    'category': 'Food',
  },
);
```

### Crashlytics

```dart
dependencies:
  firebase_crashlytics: ^3.4.8

// lib/main.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Capturar errores de Flutter
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

// Capturar errores async
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

---

## 🎯 Testing Pre-Producción

### 1. Testing en TestFlight (iOS)

```bash
# Build y subir a TestFlight
flutter build ios --release
# Upload desde Xcode Organizer

# Invitar beta testers desde App Store Connect
```

### 2. Testing en Internal Testing (Android)

```bash
# Subir AAB a Internal Testing track
# Google Play Console → Testing → Internal Testing
# Compartir link con testers
```

### 3. Checklist de Testing

- [ ] Login/Registro funciona
- [ ] Crear hogar funciona
- [ ] Unirse a hogar con código
- [ ] Agregar aportación actualiza saldos
- [ ] Agregar gasto actualiza categorías
- [ ] Notificaciones push llegan
- [ ] Tema claro/oscuro funciona
- [ ] App funciona offline (cache)
- [ ] No hay memory leaks
- [ ] Performance aceptable (60fps)

---

## 📈 Post-Deploy Monitoring

### 1. Firebase Console

Monitorear:
- **Performance**: Tiempo de carga, latencia
- **Crashlytics**: Crashes y errores
- **Analytics**: Usuarios activos, eventos
- **Firestore**: Lecturas/escrituras

### 2. Play Console / App Store

Revisar:
- Reseñas y calificaciones
- Crashes reportados
- Métricas de instalación
- Tasa de retención

### 3. Alertas

Configurar en Firebase:
- Alertas de presupuesto (Firestore, Functions)
- Alertas de crash rate > 1%
- Alertas de performance degradation

---

## 🔄 Actualizaciones

### Versioning

En `pubspec.yaml`:
```yaml
version: 1.0.0+1
#       ↑     ↑
#       |     Build number
#       Version name
```

Incrementar:
- **Patch** (1.0.X): Bug fixes
- **Minor** (1.X.0): Nuevas features
- **Major** (X.0.0): Breaking changes

### Deploy Update

```bash
# Actualizar versión
# pubspec.yaml: version: 1.1.0+2

# Build
flutter build appbundle --release  # Android
flutter build ios --release        # iOS

# Deploy
# Subir a Play Console / App Store Connect
```

### Over-the-Air Updates (opcional)

```dart
dependencies:
  firebase_remote_config: ^4.3.8

// Forzar actualización si versión < mínima
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.fetchAndActivate();
final minVersion = remoteConfig.getString('min_app_version');

if (currentVersion < minVersion) {
  // Mostrar diálogo "Actualización requerida"
  showUpdateDialog(context);
}
```

---

## 💰 Monetización (opcional)

### 1. In-App Purchases

```dart
dependencies:
  in_app_purchase: ^3.1.13

// Ofrecer:
- Plan Premium: sin anuncios, reportes avanzados
- Múltiples hogares
- Export ilimitado
```

### 2. AdMob

```dart
dependencies:
  google_mobile_ads: ^4.0.0

// Mostrar:
- Banner ads en bottom
- Interstitial al abrir reporte
- Rewarded ad para unlock features
```

### 3. Suscripciones

```dart
// RevenueCat para gestionar suscripciones
dependencies:
  purchases_flutter: ^6.7.0

// Planes:
- Básico: gratis, 1 hogar
- Premium: $49 MXN/mes, hogares ilimitados
- Familiar: $99 MXN/mes, 5 hogares, reportes avanzados
```

---

## 🎉 Launch Checklist

- [ ] App probada en 5+ dispositivos reales
- [ ] Todas las features funcionan correctamente
- [ ] Performance optimizado (< 3s cold start)
- [ ] Capturas de pantalla profesionales
- [ ] Video preview (opcional pero recomendado)
- [ ] Descripción optimizada para SEO
- [ ] Keywords relevantes (Android/iOS)
- [ ] Política de privacidad URL activa
- [ ] Email de soporte configurado
- [ ] Sitio web o landing page (opcional)
- [ ] Social media preparado para anuncio
- [ ] Press kit preparado (logos, banners)

---

## 📣 Marketing Post-Launch

1. **Product Hunt**: Publicar el día del launch
2. **Reddit**: r/FlutterDev, r/SideProject
3. **Twitter/X**: Thread explicando features
4. **LinkedIn**: Post profesional
5. **Email**: A lista de early adopters
6. **Blog Post**: "Building X with Flutter"

---

## 🆘 Soporte

Configurar:
1. **Email**: soporte@tuapp.com
2. **Chat**: Intercom, Zendesk
3. **FAQ**: En la app y website
4. **Comunidad**: Discord, Telegram
5. **Feedback**: In-app feedback form

---

¡Éxito en tu lanzamiento! 🚀
