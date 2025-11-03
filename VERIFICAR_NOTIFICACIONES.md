# 🔔 Verificación Rápida de Notificaciones

## ✅ Paso 1: Compilar e Instalar la Nueva APK

Ya estás compilando con `flutter build apk --release`. Una vez termine:

1. Instala la APK en ambos dispositivos (tuyo y de tu esposa)
2. Abre la app en AMBOS dispositivos
3. Asegúrate de que ambos acepten los permisos de notificaciones

## 🔍 Paso 2: Verificar Tokens en Firestore

1. **Ve a Firebase Console:** https://console.firebase.google.com
2. **Selecciona tu proyecto**
3. **Ve a Firestore Database**
4. **Navega a:** `households` → (tu household) → `members`
5. **Verifica cada miembro:**

Debe verse así:
```
members
  ├── usuario1_uid
  │   ├── displayName: "Tu Nombre"
  │   ├── fcmTokens: ["dA3kF5gH7jK9..."] ✅ DEBE TENER AL MENOS 1 TOKEN
  │   └── ...
  └── usuario2_uid
      ├── displayName: "Esposa"
      ├── fcmTokens: ["eB4lG6hJ8kL0..."] ✅ DEBE TENER AL MENOS 1 TOKEN
      └── ...
```

### ⚠️ SI NO HAY TOKENS:

**Causa 1:** La app no está pidiendo permisos
- **Solución:** Desinstala la app, reinstala, y acepta los permisos

**Causa 2:** Hay un error en la inicialización
- **Solución:** Abre la app y ve los logs con `adb logcat | grep "🔔"`

**Causa 3:** Los tokens se están guardando pero en el household incorrecto
- **Solución:** Verifica que estés viendo el household correcto en Firestore

## 📱 Paso 3: Ver Logs en Tiempo Real

En tu computadora, ejecuta:

```bash
# Si usas Android
adb logcat | grep "🔔"
```

Deberías ver al abrir la app:
```
🔔 [Main] Firebase Messaging background handler registrado
🔔 [Splash] FCM Token obtenido: dA3k...
🔔 [Splash] Token guardado en household: abc123
```

## 🧪 Paso 4: Probar Notificaciones

### Prueba A: Tu agregas un gasto
1. En TU dispositivo, agrega un gasto de $10
2. En el dispositivo de TU ESPOSA, debería llegar: "💸 Nuevo gasto - Tu Nombre gastó $10.00 en Categoría"

### Prueba B: Tu esposa agrega una aportación  
1. En el dispositivo de TU ESPOSA, agrega una aportación de $100
2. En TU dispositivo, debería llegar: "💰 Nueva aportación - Esposa aportó $100.00"

## 🐛 Si NO Llegan Notificaciones

### Verificación 1: Logs de Cloud Functions

```bash
firebase functions:log --only onExpenseCreated
```

Deberías ver cuando alguien agrega un gasto:
```
Successfully sent expense notification: { successCount: 1, failureCount: 0 }
```

Si ves `failureCount: 1`, hay un problema con los tokens.

### Verificación 2: Prueba Manual desde Firebase Console

1. Ve a Firebase Console → Cloud Messaging → "Enviar tu primer mensaje"
2. Título: "Prueba"
3. Mensaje: "Probando notificaciones"
4. En "Dispositivo de prueba", pega el token FCM de Firestore
5. Envía

**Si esta notificación NO llega:** El problema es el token o permisos del dispositivo.
**Si esta notificación SÍ llega:** El problema es que las Cloud Functions no se están ejecutando.

## 🔧 Soluciones Comunes

### Problema: "User granted permission: AuthorizationStatus.denied"

**Solución:**
```bash
# Desinstalar app
adb uninstall com.example.app_gestion_gastos

# Reinstalar (después del build)
adb install build/app/outputs/flutter-apk/app-release.apk

# Abrir app y ACEPTAR permisos
```

### Problema: "No se pudo obtener el FCM token"

**Solución:** Verifica que `google-services.json` esté en `android/app/`

```bash
ls -la android/app/google-services.json
```

Si no existe, descárgalo de Firebase Console.

### Problema: "Cloud Functions no envían notificaciones"

**Verificar que estén desplegadas:**
```bash
firebase functions:list
```

Debes ver:
- ✅ onContributionCreated
- ✅ onExpenseCreated  
- ✅ sendMonthClosureNotification

**Si no aparecen, redesplegar:**
```bash
cd functions
firebase deploy --only functions
```

## 📊 Checklist Final

Verifica estos puntos:

- [ ] APK con nuevos cambios instalada en AMBOS dispositivos
- [ ] Ambos dispositivos aceptaron permisos de notificaciones
- [ ] Tokens FCM aparecen en Firestore para AMBOS miembros
- [ ] Log "🔔 [Splash] Token guardado" aparece al abrir app
- [ ] Cloud Functions listadas con `firebase functions:list`
- [ ] Notificación manual desde Firebase Console llega correctamente
- [ ] Al agregar gasto, logs muestran "Successfully sent notification"

## 🎯 Siguiente Acción INMEDIATA

1. **Espera a que termine** `flutter build apk --release`
2. **Instala la APK** en ambos dispositivos
3. **Abre la app** en ambos dispositivos
4. **Ve a Firestore Console** y verifica que haya tokens en `fcmTokens`
5. **Prueba agregando un gasto** en un dispositivo
6. **Verifica si llega notificación** al otro dispositivo

**Comparte los logs** que veas al abrir la app (busca los que empiezan con 🔔)
