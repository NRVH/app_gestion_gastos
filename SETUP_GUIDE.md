# 🚀 Guía de Configuración Rápida

## Pasos Iniciales

### 1. Instalar Flutter y Dependencias

```bash
cd app_gestion_gastos
flutter pub get
```

### 2. Configurar Firebase

```bash
# Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurar proyecto (reemplaza con tu project-id)
flutterfire configure --project=tu-proyecto-firebase-id
```

Esto generará automáticamente `lib/firebase_options.dart`.

### 3. Habilitar Servicios en Firebase Console

Ve a https://console.firebase.google.com y en tu proyecto:

1. **Authentication**
   - Click en "Comenzar"
   - Habilita "Correo electrónico/Contraseña"

2. **Firestore Database**
   - Click en "Crear base de datos"
   - Selecciona "Modo de producción"
   - Elige ubicación (us-central1 recomendado)

3. **Cloud Messaging**
   - Ya está habilitado por defecto
   - Anota el Server Key para después

4. **Cloud Functions**
   - No requiere configuración inicial

### 4. Desplegar Reglas de Firestore

```bash
# Instalar Firebase CLI si no lo tienes
npm install -g firebase-tools

# Login
firebase login

# Inicializar en el directorio del proyecto
firebase init firestore

# Desplegar reglas
firebase deploy --only firestore:rules
```

### 5. Desplegar Cloud Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 6. Generar Código de Modelos

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 7. Configurar Android

Descarga `google-services.json` de Firebase Console y colócalo en:
```
android/app/google-services.json
```

Actualiza `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

### 8. Configurar iOS

Descarga `GoogleService-Info.plist` y colócalo en:
```
ios/Runner/GoogleService-Info.plist
```

Abre Xcode y habilita:
- Push Notifications
- Background Modes → Remote notifications

### 9. Ejecutar la App

```bash
flutter run
```

## 🎯 Probar la App

### Crear Usuario de Prueba 1

1. Abre la app
2. "¿No tienes cuenta? Regístrate"
3. Completa:
   - Nombre: Juan González
   - Email: juan@test.com
   - Contraseña: test123
4. "Crear Hogar"
   - Nombre: Casa Prueba
   - Meta mensual: 76025
   - Tu porcentaje: 73.33
5. **Copia el código del hogar** (aparece en la barra superior)

### Crear Usuario de Prueba 2

1. Cierra sesión
2. Registra nuevo usuario:
   - Nombre: María López
   - Email: maria@test.com
   - Contraseña: test123
3. "¿Ya tienes un hogar? Únete"
4. Pega el código del hogar
5. Tu porcentaje: 26.67

### Crear Categorías de Ejemplo

En cualquier de los dos usuarios:

1. Home → Botón de editar categorías
2. Crear las siguientes:

| Nombre | Límite | Emoji |
|--------|--------|-------|
| Hipoteca | 20000 | 🏠 |
| Auto | 8000 | 🚗 |
| Servicios | 5000 | 💡 |
| Supermercado | 12000 | 🛒 |
| Ocio | 5000 | 🎉 |
| Suplementos | 2000 | 💊 |
| Otros | 3000 | 📦 |

### Registrar Aportaciones

**Como Juan:**
- Botón + verde → 25000 MXN

**Como María:**
- Botón + verde → 15000 MXN

Verás que se actualiza el progreso y cada uno recibe notificación.

### Registrar Gastos

**Como Juan:**
- Botón - rojo
- Categoría: Hipoteca
- Monto: 20000
- Nota: Pago mensual

**Como María:**
- Botón - rojo
- Categoría: Supermercado
- Monto: 4500
- Nota: Compra semanal

## 📊 Ver Datos en Firestore

Ve a Firebase Console → Firestore Database y verás:

```
households/
  {id}/
    ├── (documento household)
    ├── members/
    │   ├── user_uid_1
    │   └── user_uid_2
    ├── categories/
    │   ├── cat_1
    │   └── cat_2
    ├── expenses/
    │   └── exp_1
    └── contributions/
        └── cont_1
```

## 🎨 Probar Temas

1. Home → Configuración (⚙️)
2. Tema → Oscuro
3. Color → Verde

## 🔔 Probar Notificaciones

Las notificaciones funcionan automáticamente:
1. Usuario 1 registra un gasto
2. Usuario 2 recibe notificación push instantánea
3. Al hacer tap, abre la app

**Nota:** Para iOS necesitas dispositivo físico (no simulador).

## ⚠️ Troubleshooting Rápido

### "No Firebase App"
```bash
flutterfire configure
```

### Build Errors
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Notificaciones no llegan
- Verifica que las Cloud Functions estén desplegadas
- Revisa logs: `firebase functions:log`
- Verifica tokens FCM en Firestore

### Permisos Firestore
```bash
firebase deploy --only firestore:rules
```

## ✅ Checklist de Configuración

- [ ] Flutter instalado y funcionando
- [ ] Proyecto Firebase creado
- [ ] `flutterfire configure` ejecutado
- [ ] Authentication habilitado
- [ ] Firestore creado
- [ ] Reglas de Firestore desplegadas
- [ ] Cloud Functions desplegadas
- [ ] `google-services.json` en Android
- [ ] `GoogleService-Info.plist` en iOS
- [ ] Build runner ejecutado
- [ ] App ejecuta sin errores

## 📱 Ejecutar en Dispositivo Real

### Android
```bash
flutter run -d <device-id>
```

### iOS
```bash
flutter run -d <device-id>
# O desde Xcode: Product → Run
```

## 🎓 Próximos Pasos

1. Personaliza los colores en `theme_config.dart`
2. Agrega más categorías personalizadas
3. Modifica las reglas de Firestore según tus necesidades
4. Extiende las Cloud Functions para más notificaciones
5. Agrega analytics para tracking de uso

¡Listo! Tu app está configurada y funcionando 🎉
