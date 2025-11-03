# 🔔 Guía de Depuración de Notificaciones

## ✅ Cambios Realizados en el Código

### 1. `main.dart`
- ✅ Registrado el background message handler
- ✅ Logs añadidos para tracking

### 2. `splash_page.dart`
- ✅ Escucha mensajes en foreground (onMessage)
- ✅ Escucha cuando usuario toca notificación (onMessageOpenedApp)
- ✅ Verifica si app se abrió desde notificación (getInitialMessage)
- ✅ Logs detallados para debugging

### 3. `messaging_service.dart`
- ✅ Ya configurado correctamente

## 🚀 Pasos para Verificar y Arreglar

### Paso 1: Verificar que las Cloud Functions estén desplegadas

Ejecuta este comando en la terminal:

```bash
cd functions
npm install
firebase deploy --only functions
```

Deberías ver algo como:
```
✔  functions[onContributionCreated] Successful create operation.
✔  functions[onExpenseCreated] Successful create operation.
✔  functions[sendMonthClosureNotification] Successful create operation.
```

### Paso 2: Verificar permisos de notificaciones en el dispositivo

1. **Compilar la app con los nuevos cambios:**
```bash
flutter build apk --release
```

2. **Instalar en el dispositivo:**
```bash
flutter install
```

3. **Verificar permisos:** La app pedirá permiso para notificaciones al iniciar

### Paso 3: Verificar tokens FCM en Firestore

1. Abre Firebase Console → Firestore Database
2. Ve a: `households/{tu-household-id}/members/{tu-uid}`
3. Verifica que el campo `fcmTokens` tenga un array con al menos un token:
```json
{
  "fcmTokens": [
    "dA3kF5gH7jK9...largo-token-aquí"
  ]
}
```

### Paso 4: Verificar logs en tiempo real

Cuando agregues un gasto o aportación, deberías ver estos logs:

**En la app (logcat/consola):**
```
🔔 [Main] Firebase Messaging background handler registrado
🔔 [Splash] FCM Token obtenido: dA3kF5gH7jK9...
🔔 [Splash] Token guardado en household: abc123
```

**En Firebase Console → Functions → Logs:**
```
Successfully sent expense notification: { successCount: 1, failureCount: 0 }
```

### Paso 5: Probar notificaciones

#### Prueba 1: Agregar un gasto
1. Usuario A agrega un gasto de $100
2. Usuario B debería recibir notificación: "💸 Nuevo gasto - Usuario A gastó $100 en Categoría"

#### Prueba 2: Agregar una aportación
1. Usuario A agrega una aportación de $500
2. Usuario B debería recibir notificación: "💰 Nueva aportación - Usuario A aportó $500"

## 🐛 Problemas Comunes y Soluciones

### Problema: "No se reciben notificaciones"

**Solución 1:** Verificar que las Cloud Functions estén desplegadas
```bash
firebase functions:list
```

**Solución 2:** Verificar logs de las Cloud Functions
```bash
firebase functions:log
```

**Solución 3:** Verificar que los tokens FCM estén guardados en Firestore
- Ve a Firestore Console
- Verifica `households/{id}/members/{uid}/fcmTokens`

**Solución 4:** Verificar permisos en el dispositivo
- Android: Configuración → Apps → Tu App → Notificaciones → Activar

### Problema: "Error al obtener token FCM"

**Causa:** No hay `google-services.json` válido o configuración incorrecta

**Solución:**
1. Ve a Firebase Console → Configuración del proyecto → Android
2. Descarga `google-services.json` actualizado
3. Colócalo en `android/app/google-services.json`
4. Reconstruye: `flutter clean && flutter build apk`

### Problema: "Cloud Functions no se ejecutan"

**Causa:** Firestore triggers no configurados o Firebase Blaze plan requerido

**Solución:**
1. Verifica que estás en el plan Blaze de Firebase (necesario para Cloud Functions)
2. Ve a Firebase Console → Functions
3. Verifica que las 3 funciones aparezcan como "desplegadas"

### Problema: "Notificaciones solo en foreground"

**Causa:** Android requiere notificación local en foreground

**Solución:** Ya está configurado el listener en `splash_page.dart`. Las notificaciones en background deberían funcionar automáticamente.

## 📱 Verificación Manual con Firebase Console

Puedes enviar una notificación de prueba:

1. Firebase Console → Cloud Messaging
2. "Enviar mensaje de prueba"
3. Pegar el FCM token de Firestore
4. Enviar

Si esta notificación llega, el problema está en las Cloud Functions, no en la app.

## 🔍 Comandos de Depuración

### Ver logs en tiempo real (Flutter)
```bash
flutter logs
```

### Ver logs de Cloud Functions
```bash
firebase functions:log --only onExpenseCreated
firebase functions:log --only onContributionCreated
```

### Ver logs de Android
```bash
adb logcat | grep -i "firebase\|fcm\|notification"
```

## ✨ Verificación de Funcionalidad Completa

Checklist:
- [ ] Cloud Functions desplegadas (`firebase deploy --only functions`)
- [ ] App con nuevos cambios instalada
- [ ] Permisos de notificaciones aceptados
- [ ] Tokens FCM guardados en Firestore (verificar en console)
- [ ] Log aparece: "🔔 [Splash] Token guardado en household"
- [ ] Al agregar gasto, log en Functions: "Successfully sent expense notification"
- [ ] Usuario 2 recibe notificación cuando Usuario 1 agrega gasto/aportación

## 🚨 Siguiente Paso Inmediato

**Despliega las Cloud Functions AHORA:**

```bash
cd /Users/noevazquez/Documents/Flutter/app_gestion_gastos/functions
npm install
firebase login
firebase use --add  # Selecciona tu proyecto
firebase deploy --only functions
```

Luego:
```bash
cd ..
flutter build apk --release
```

Instala la nueva APK y prueba agregando un gasto. Deberías ver notificaciones. 🎉
