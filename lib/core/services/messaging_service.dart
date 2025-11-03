import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final messagingServiceProvider = Provider<MessagingService>((ref) {
  return MessagingService(FirebaseMessaging.instance);
});

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}

class MessagingService {
  final FirebaseMessaging _messaging;

  MessagingService(this._messaging);

  Future<void> initialize() async {
    print('🔔 [MessagingService] Solicitando permisos de notificación...');
    
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('🔔 [MessagingService] Estado de permisos: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('🔔 [MessagingService] ✅ Permisos autorizados');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('🔔 [MessagingService] ⚠️ Permisos provisionales');
    } else {
      print('🔔 [MessagingService] ❌ Permisos denegados o no determinados');
    }

    // Get FCM token
    print('🔔 [MessagingService] Obteniendo FCM token...');
    final token = await _messaging.getToken();
    if (token != null) {
      print('🔔 [MessagingService] ✅ FCM Token obtenido: ${token.substring(0, 20)}...');
    } else {
      print('🔔 [MessagingService] ❌ No se pudo obtener FCM token');
    }

    // Listen to token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      print('🔔 [MessagingService] Token refrescado: ${newToken.substring(0, 20)}...');
      // TODO: Update token in Firestore
    });
  }

  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> getInitialMessage() async {
    return await _messaging.getInitialMessage();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
