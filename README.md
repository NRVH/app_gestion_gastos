# 📱 App Gestión Gastos para Parejas

Una aplicación móvil Flutter completa para parejas que comparten gastos mensuales. Permite gestionar aportaciones, gastos, categorías y seguimiento mensual con notificaciones push.

## ✨ Características Principales

- 🏠 **Gestión de Hogar**: Crea o únete a un hogar compartido
- 💰 **Aportaciones**: Registra contribuciones mensuales con seguimiento por porcentaje
- 💸 **Gastos**: Registra gastos por categoría con límites mensuales
- 📊 **Categorías**: Crea y gestiona categorías con límites y alertas
- 📈 **Dashboard**: Vista completa del progreso mensual, personal y por categoría
- 🔔 **Notificaciones Push**: Alertas automáticas de gastos y aportaciones
- 🌙 **Modo Oscuro**: Soporte completo para tema claro/oscuro
- 🎨 **Temas Personalizables**: 5 esquemas de color diferentes
- 📅 **Cierre de Mes**: Función para cerrar mes y llevar saldo al siguiente

## 🏗️ Arquitectura

### Estructura del Proyecto

```
lib/
├── core/
│   ├── config/
│   │   └── theme_config.dart          # Configuración de temas
│   ├── models/
│   │   ├── household.dart             # Modelo de hogar
│   │   ├── member.dart                # Modelo de miembro
│   │   ├── category.dart              # Modelo de categoría
│   │   ├── expense.dart               # Modelo de gasto
│   │   ├── contribution.dart          # Modelo de aportación
│   │   └── month_history.dart         # Modelo de historial mensual
│   ├── providers/
│   │   ├── household_provider.dart    # Providers de hogar
│   │   ├── member_provider.dart       # Providers de miembros
│   │   ├── category_provider.dart     # Providers de categorías
│   │   ├── expense_provider.dart      # Providers de gastos
│   │   └── contribution_provider.dart # Providers de aportaciones
│   ├── router/
│   │   └── app_router.dart            # Rutas de la aplicación
│   ├── services/
│   │   ├── auth_service.dart          # Servicio de autenticación
│   │   ├── firestore_service.dart     # Servicio de Firestore
│   │   └── messaging_service.dart     # Servicio de FCM
│   └── utils/
│       ├── formatters.dart            # Formatters de moneda, fecha, etc.
│       └── validators.dart            # Validadores de formularios
├── features/
│   ├── auth/
│   │   └── presentation/
│   │       └── pages/
│   │           ├── splash_page.dart
│   │           ├── login_page.dart
│   │           └── register_page.dart
│   ├── home/
│   │   └── presentation/
│   │       ├── pages/
│   │       │   └── home_page.dart
│   │       └── widgets/
│   │           ├── month_summary_card.dart
│   │           ├── personal_summary_card.dart
│   │           └── category_list_card.dart
│   ├── household/
│   │   └── presentation/
│   │       └── pages/
│   │           ├── create_household_page.dart
│   │           └── join_household_page.dart
│   ├── expenses/
│   │   └── presentation/
│   │       └── pages/
│   │           └── add_expense_page.dart
│   ├── contributions/
│   │   └── presentation/
│   │       └── pages/
│   │           └── add_contribution_page.dart
│   ├── categories/
│   │   └── presentation/
│   │       └── pages/
│   │           └── manage_categories_page.dart
│   └── settings/
│       └── presentation/
│           └── pages/
│               └── settings_page.dart
└── main.dart
```

### Modelo de Datos Firestore

#### Collection: `households/{householdId}`
```json
{
  "id": "household_id",
  "name": "Casa González",
  "month": "2025-11",
  "monthTarget": 76025.0,
  "monthPool": 50000.0,
  "carryOver": 5000.0,
  "members": ["user_uid_1", "user_uid_2"],
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2025-11-01T00:00:00Z"
}
```

#### Subcollection: `households/{householdId}/members/{uid}`
```json
{
  "uid": "user_uid_1",
  "displayName": "Juan González",
  "email": "juan@example.com",
  "role": "owner",
  "share": 0.7333,
  "contributedThisMonth": 35000.0,
  "fcmTokens": ["token1", "token2"],
  "joinedAt": "2025-01-01T00:00:00Z"
}
```

#### Subcollection: `households/{householdId}/categories/{categoryId}`
```json
{
  "id": "category_id",
  "name": "Hipoteca",
  "monthlyLimit": 20000.0,
  "spentThisMonth": 20000.0,
  "dueDay": 5,
  "canGoNegative": false,
  "icon": "🏠",
  "color": "#FF5722",
  "createdAt": "2025-01-01T00:00:00Z"
}
```

#### Subcollection: `households/{householdId}/expenses/{expenseId}`
```json
{
  "id": "expense_id",
  "by": "user_uid_1",
  "byDisplayName": "Juan González",
  "categoryId": "category_id",
  "categoryName": "Hipoteca",
  "amount": 20000.0,
  "date": "2025-11-05T00:00:00Z",
  "note": "Pago mensual hipoteca",
  "createdAt": "2025-11-05T10:30:00Z"
}
```

#### Subcollection: `households/{householdId}/contributions/{contributionId}`
```json
{
  "id": "contribution_id",
  "by": "user_uid_1",
  "byDisplayName": "Juan González",
  "amount": 35000.0,
  "date": "2025-11-01T00:00:00Z",
  "note": "Aportación mensual",
  "createdAt": "2025-11-01T08:00:00Z"
}
```

#### Subcollection: `households/{householdId}/months/{YYYY-MM}`
```json
{
  "id": "2025-10",
  "householdId": "household_id",
  "monthTarget": 76025.0,
  "totalContributed": 80000.0,
  "totalSpent": 75000.0,
  "carryOverToNext": 5000.0,
  "closedAt": "2025-10-31T23:59:59Z",
  "memberContributions": {
    "user_uid_1": 55000.0,
    "user_uid_2": 25000.0
  },
  "categorySpending": {
    "category_id_1": 20000.0,
    "category_id_2": 15000.0
  }
}
```

## 🚀 Instalación y Configuración

### Prerrequisitos

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Firebase CLI
- Node.js (>=18) para Cloud Functions
- Android Studio / Xcode para desarrollo

### Paso 1: Clonar e Instalar Dependencias

```bash
cd app_gestion_gastos
flutter pub get
```

### Paso 2: Configurar Firebase

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/)

2. Habilita los siguientes servicios:
   - Authentication (Email/Password)
   - Cloud Firestore
   - Cloud Messaging
   - Cloud Functions

3. Instala FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

4. Configura Firebase para tu proyecto:
```bash
flutterfire configure --project=tu-proyecto-id
```

Esto generará automáticamente el archivo `lib/firebase_options.dart` con las credenciales correctas.

### Paso 3: Configurar Firestore

1. Ve a Firebase Console → Firestore Database
2. Crea una base de datos en modo producción
3. Aplica las reglas de seguridad desde `firestore.rules`:

```bash
firebase deploy --only firestore:rules
```

### Paso 4: Configurar Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

### Paso 5: Configurar FCM (Notificaciones Push)

#### Android
1. Descarga `google-services.json` desde Firebase Console
2. Colócalo en `android/app/`
3. Actualiza `android/app/build.gradle`:

```gradle
dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

#### iOS
1. Descarga `GoogleService-Info.plist` desde Firebase Console
2. Colócalo en `ios/Runner/`
3. Configura capabilities en Xcode:
   - Push Notifications
   - Background Modes → Remote notifications

### Paso 6: Generar Código (Freezed & JSON Serializable)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Paso 7: Ejecutar la App

```bash
flutter run
```

## 📋 Funcionalidades Implementadas

### ✅ Autenticación
- [x] Registro con email/password
- [x] Login
- [x] Recuperación de contraseña
- [x] Cierre de sesión

### ✅ Gestión de Hogar
- [x] Crear hogar con meta mensual
- [x] Unirse a hogar con código
- [x] Compartir código de hogar
- [x] Vista de miembros del hogar

### ✅ Aportaciones
- [x] Registrar aportación
- [x] Ver historial de aportaciones
- [x] Actualización automática de saldos
- [x] Notificación push a otros miembros

### ✅ Gastos
- [x] Registrar gasto por categoría
- [x] Ver historial de gastos
- [x] Actualización automática de categorías
- [x] Notificación push a otros miembros

### ✅ Categorías
- [x] Crear categorías con límites
- [x] Editar categorías
- [x] Eliminar categorías
- [x] Alertas visuales cuando se supera el límite
- [x] Iconos personalizables (emojis)

### ✅ Dashboard
- [x] Resumen del mes (disponible, meta, progreso)
- [x] Resumen personal (te tocaba, aportado, falta)
- [x] Lista de categorías con progreso
- [x] Indicadores visuales de estado

### ✅ Cierre de Mes
- [x] Función para cerrar mes
- [x] Crear historial mensual
- [x] Transferir saldo a siguiente mes
- [x] Resetear contadores
- [x] Notificación a todos los miembros

### ✅ Configuración
- [x] Modo claro/oscuro/sistema
- [x] 5 esquemas de color
- [x] Perfil de usuario
- [x] Cerrar sesión

## 🎯 Casos de Uso Principales

### Caso 1: Crear Hogar y Agregar Pareja

```dart
// Usuario 1: Crear hogar
final householdId = await firestoreService.createHousehold(
  name: 'Casa González',
  month: '2025-11',
  monthTarget: 76025.0,
  ownerUid: user.uid,
  ownerDisplayName: 'Juan',
  ownerShare: 0.7333, // 73.33%
);

// Usuario 1: Compartir código del hogar
print('Código: $householdId');

// Usuario 2: Unirse al hogar
await firestoreService.joinHousehold(
  householdId: householdId,
  uid: user2.uid,
  displayName: 'María',
  share: 0.2667, // 26.67%
);
```

### Caso 2: Registrar Aportación

```dart
await firestoreService.addContribution(
  householdId: householdId,
  byUid: user.uid,
  byDisplayName: 'Juan',
  amount: 10000.0,
  date: DateTime.now(),
  note: 'Aportación quincenal',
);
// Esto automáticamente:
// 1. Suma a monthPool
// 2. Suma a contributedThisMonth del miembro
// 3. Envía notificación push a María
```

### Caso 3: Registrar Gasto

```dart
await firestoreService.addExpense(
  householdId: householdId,
  byUid: user.uid,
  byDisplayName: 'Juan',
  categoryId: categoryId,
  categoryName: 'Ocio',
  amount: 880.0,
  date: DateTime.now(),
  note: 'Cena familiar',
);
// Esto automáticamente:
// 1. Resta de monthPool
// 2. Suma a spentThisMonth de la categoría
// 3. Envía notificación push a María
// 4. La UI muestra alerta si se supera el límite
```

### Caso 4: Cerrar Mes

```dart
await firestoreService.closeMonth(
  householdId: householdId,
  household: currentHousehold,
  members: allMembers,
  categories: allCategories,
);
// Esto automáticamente:
// 1. Crea documento en months/{YYYY-MM}
// 2. Transfiere saldo a carryOver
// 3. Resetea monthPool a 0
// 4. Resetea contributedThisMonth de todos
// 5. Resetea spentThisMonth de todas las categorías
// 6. Envía notificación a todos
```

## 🔒 Seguridad

### Reglas de Firestore

Las reglas implementadas garantizan que:
- Solo usuarios autenticados pueden acceder
- Solo miembros del hogar pueden ver/editar datos
- Los usuarios solo pueden crear gastos/aportes a su nombre
- Solo el owner puede eliminar el hogar
- El historial mensual no puede ser modificado

## 🎨 Temas y Personalización

La app soporta:
- **Modos**: Claro, Oscuro, Sistema
- **Colores**: Azul, Verde, Morado, Naranja, Rojo
- Material Design 3

Los ajustes se guardan en SharedPreferences y persisten entre sesiones.

## 📊 Estado y Gestión de Datos

Utilizamos **Riverpod** para state management con:
- StreamProviders para datos en tiempo real de Firestore
- StateProviders para configuración local
- Separación clara entre UI y lógica de negocio

## 🔔 Notificaciones Push

### Configuración de Tokens FCM

```dart
final messagingService = ref.read(messagingServiceProvider);
await messagingService.initialize();

final token = await messagingService.getToken();
if (token != null) {
  await firestoreService.updateFcmToken(householdId, uid, token);
}
```

### Cloud Functions

Las funciones se disparan automáticamente en:
- `onCreate` de contributions → notifica a otros miembros
- `onCreate` de expenses → notifica a otros miembros
- Llamada manual para cierre de mes

## 🐛 Troubleshooting

### Errores Comunes

1. **"No Firebase App"**: Asegúrate de ejecutar `flutterfire configure`
2. **Build Runner**: Ejecuta `flutter pub run build_runner build --delete-conflicting-outputs`
3. **Permisos Firestore**: Verifica que las reglas estén desplegadas
4. **FCM no funciona**: Verifica certificados APNs (iOS) o google-services.json (Android)

## 📝 TODO / Mejoras Futuras

- [ ] Gráficas de gastos mensuales
- [ ] Exportar reportes en PDF
- [ ] Recordatorios de pagos próximos
- [ ] Múltiples hogares por usuario
- [ ] Compartir gastos entre categorías
- [ ] Historial detallado con filtros
- [ ] Modo offline con sincronización
- [ ] Autenticación con Google/Apple

## 🤝 Contribución

Este proyecto está abierto a mejoras. Algunas ideas:

1. **Mejoras de UX**: Animaciones, transiciones
2. **Analytics**: Integrar Firebase Analytics
3. **Tests**: Unit tests, widget tests, integration tests
4. **Internacionalización**: Soporte multi-idioma
5. **Accesibilidad**: Mejorar soporte para screen readers

## 📄 Licencia

MIT License - Siéntete libre de usar este código para tus proyectos.

## 👨‍💻 Autor

Desarrollado con ❤️ usando Flutter y Firebase.

---

## 🎓 Aprendizajes Clave

Este proyecto demuestra:
- Arquitectura limpia en Flutter
- Firebase como BaaS completo
- State management con Riverpod
- Notificaciones push end-to-end
- Material Design 3
- Firestore transactions y batch writes
- Cloud Functions con Node.js
- Seguridad con Firestore Rules

¡Disfruta desarrollando tu app de gestión de gastos! 🚀
