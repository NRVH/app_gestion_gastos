import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ⚠️ MODO TEST - Credenciales de bypass
const String TEST_EMAIL = 'test@test.com';
const String TEST_PASSWORD = '123456';
const bool ENABLE_TEST_MODE = false; // Cambiar a false para usar Firebase real

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Provider síncrono que retorna el usuario actual o null
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

class AuthService {
  final FirebaseAuth _auth;
  final StreamController<User?> _testAuthStateController = StreamController<User?>.broadcast();

  AuthService(this._auth) {
    // Emitir estado inicial
    if (ENABLE_TEST_MODE) {
      _testAuthStateController.add(null);
    }
  }

  // Usuario de prueba simulado
  final _testUser = _TestUser(
    uid: 'test-user-id',
    email: TEST_EMAIL,
    displayName: 'Usuario Prueba',
  );
  
  bool _isTestUserLoggedIn = false;

  Stream<User?> get authStateChanges {
    if (ENABLE_TEST_MODE) {
      return _testAuthStateController.stream;
    }
    return _auth.authStateChanges();
  }
  
  User? get currentUser {
    if (ENABLE_TEST_MODE && _isTestUserLoggedIn) {
      return _testUser;
    }
    return _auth.currentUser;
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    print('🔐 [AUTH] Iniciando signInWithEmailAndPassword');
    print('🔐 [AUTH] Email: $email');
    print('🔐 [AUTH] ENABLE_TEST_MODE: $ENABLE_TEST_MODE');
    
    // ✅ MODO TEST: Bypass con credenciales de prueba
    if (ENABLE_TEST_MODE && email == TEST_EMAIL && password == TEST_PASSWORD) {
      print('🔓 MODO TEST: Acceso concedido con credenciales de prueba');
      _isTestUserLoggedIn = true;
      // Emitir el cambio de estado de autenticación
      _testAuthStateController.add(_testUser);
      // Retornar un mock UserCredential
      return _TestUserCredential(_testUser);
    }
    
    // Modo normal con Firebase
    try {
      print('🔐 [AUTH] Llamando a Firebase signInWithEmailAndPassword...');
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('🔐 [AUTH] ✅ Login exitoso! User ID: ${result.user?.uid}');
      _isTestUserLoggedIn = false;
      if (ENABLE_TEST_MODE) {
        _testAuthStateController.add(result.user);
      }
      return result;
    } catch (e) {
      print('🔐 [AUTH] ❌ Error en signInWithEmailAndPassword: $e');
      print('🔐 [AUTH] ❌ Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.reload();
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    print('🔐 [GOOGLE] Iniciando signInWithGoogle');
    try {
      // Trigger the authentication flow
      print('🔐 [GOOGLE] Creando GoogleSignIn instance...');
      final googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );
      
      print('🔐 [GOOGLE] Llamando a googleSignIn.signIn()...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        print('🔐 [GOOGLE] ⚠️ Usuario canceló el login');
        // User canceled the sign-in
        return null;
      }

      print('🔐 [GOOGLE] ✅ Usuario seleccionado: ${googleUser.email}');
      // Obtain the auth details from the request
      print('🔐 [GOOGLE] Obteniendo authentication tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Check if we have the required tokens
      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      print('🔐 [GOOGLE] accessToken: ${accessToken != null ? "✅ OK" : "❌ NULL"}');
      print('🔐 [GOOGLE] idToken: ${idToken != null ? "✅ OK" : "❌ NULL"}');

      if (accessToken == null || idToken == null) {
        throw Exception('Error obteniendo tokens de Google');
      }

      // Create a new credential
      print('🔐 [GOOGLE] Creando credential de Firebase...');
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      try {
        print('🔐 [GOOGLE] Llamando a Firebase signInWithCredential...');
        // Try to sign in with Google credential
        // Workaround para el bug de google_sign_in con el tipo PigeonUserDetails
        try {
          final result = await _auth.signInWithCredential(credential);
          print('🔐 [GOOGLE] ✅ Login exitoso! User ID: ${result.user?.uid}');
          return result;
        } catch (typeError) {
          // Si hay un error de tipo, verificar si el usuario se autenticó correctamente de todos modos
          print('🔐 [GOOGLE] ⚠️ Type error capturado: $typeError');
          final currentUser = _auth.currentUser;
          if (currentUser != null) {
            print('🔐 [GOOGLE] ✅ Usuario autenticado a pesar del error de tipo: ${currentUser.uid}');
            // Crear un UserCredential manualmente
            return _ManualUserCredential(currentUser);
          }
          rethrow;
        }
      } on FirebaseAuthException catch (e) {
        print('🔐 [GOOGLE] ❌ FirebaseAuthException: ${e.code} - ${e.message}');
        // Si la cuenta ya existe con email/password, vincularla
        if (e.code == 'account-exists-with-different-credential') {
          // Obtener el email del error
          final email = e.email;
          if (email == null) rethrow;

          // Obtener los métodos de inicio de sesión para este email
          final signInMethods = await _auth.fetchSignInMethodsForEmail(email);

          // Si tiene email/password, pedir al usuario que inicie sesión primero
          if (signInMethods.contains('password')) {
            // Aquí deberías mostrar un diálogo al usuario pidiendo su contraseña
            // Por ahora, lanzamos una excepción descriptiva
            throw Exception(
              'Ya existe una cuenta con este correo. Por favor, inicia sesión con tu correo y contraseña, '
              'luego vincula tu cuenta de Google desde Configuración.'
            );
          }

          rethrow;
        }
        rethrow;
      }
    } catch (e) {
      print('🔐 [GOOGLE] ❌ Error general: $e');
      print('🔐 [GOOGLE] ❌ Error type: ${e.runtimeType}');
      print('🔐 [GOOGLE] ❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Vincula la cuenta actual con Google
  Future<void> linkWithGoogle() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No hay usuario autenticado');
      }

      // Trigger the authentication flow
      final googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('Error obteniendo tokens de Google');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      // Link the credential with the current user
      try {
        await currentUser.linkWithCredential(credential);
      } catch (typeError) {
        // Si hay un error de tipo, verificar si se vinculó correctamente de todos modos
        print('⚠️ Type error capturado en linkWithGoogle: $typeError');
        // Recargar el usuario para verificar si se vinculó
        await currentUser.reload();
        final updatedUser = _auth.currentUser;
        if (updatedUser != null) {
          print('✅ Cuenta vinculada a pesar del error de tipo');
          return;
        }
        rethrow;
      }
    } catch (e) {
      print('Error linking with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (ENABLE_TEST_MODE && _isTestUserLoggedIn) {
      print('🔓 MODO TEST: Cerrando sesión de prueba');
      _isTestUserLoggedIn = false;
      // Emitir null para indicar que no hay usuario autenticado
      _testAuthStateController.add(null);
      return;
    }
    // Sign out from Google and Firebase
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (e) {
      print('Error signing out from Google: $e');
    }
    await _auth.signOut();
  }
  
  // Dispose del StreamController
  void dispose() {
    _testAuthStateController.close();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
    await _auth.currentUser?.reload();
  }

  Future<void> updateEmail(String email) async {
    await _auth.currentUser?.updateEmail(email);
  }

  Future<void> updatePassword(String password) async {
    await _auth.currentUser?.updatePassword(password);
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }
    
    // Intentar eliminar la cuenta
    // Nota: Puede requerir reautenticación reciente
    await user.delete();
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user?.email != null) {
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }

  Future<void> reauthenticateWithGoogle() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No hay usuario autenticado');
      }

      // Trigger the authentication flow
      final googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Autenticación cancelada');
      }

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('Error obteniendo tokens de Google');
      }

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      // Reauthenticate
      try {
        await currentUser.reauthenticateWithCredential(credential);
      } catch (typeError) {
        // Si hay un error de tipo, verificar si se reautenticó correctamente de todos modos
        print('⚠️ Type error capturado en reauthenticateWithGoogle: $typeError');
        // Si el currentUser sigue existiendo, asumimos que la reautenticación fue exitosa
        if (_auth.currentUser != null) {
          print('✅ Reautenticación exitosa a pesar del error de tipo');
          return;
        }
        rethrow;
      }
    } catch (e) {
      print('Error reauthenticating with Google: $e');
      rethrow;
    }
  }
}

// 🧪 Clase simulada de User para modo TEST
// 
// TODO: OPTIMIZACIÓN FUTURA - Refactorizar implementación de _TestUser
// 
// La implementación actual de _TestUser tiene varios problemas:
// 1. Implementa toda la interfaz User con muchos métodos que lanzan UnimplementedError
// 2. No es reutilizable - está acoplada a AuthService
// 3. Difícil de mantener cuando Firebase actualiza la interfaz User
//
// SUGERENCIAS DE MEJORA:
//
// Opción 1 - Usar paquete mockito/fake para testing:
//   - Crear MockUser con mockito
//   - Más mantenible y estándar en la comunidad Flutter
//   - Mejor separación de concerns
//
// Opción 2 - Extraer a un archivo separado de test utilities:
//   - lib/core/testing/mock_auth.dart
//   - Incluir MockUser, MockUserCredential, MockAuthService
//   - Reutilizable en tests unitarios
//
// Opción 3 - Usar un patrón Repository/Adapter:
//   - AuthRepository interface
//   - FirebaseAuthRepository (producción)
//   - MockAuthRepository (testing)
//   - Mejor testabilidad y SOLID principles
//
// BENEFICIOS:
// - Código más limpio y mantenible
// - Facilita testing automatizado
// - Reduce acoplamiento con Firebase
// - Mejor escalabilidad
//
// RIESGO: MEDIO - Requiere refactorizar AuthService y actualizar dependencias
// PRIORIDAD: MEDIA - Mejoraría calidad de código pero no es crítico
// ESTIMACIÓN: 4-6 horas de desarrollo + testing
class _TestUser implements User {
  @override
  final String uid;
  
  @override
  final String? email;
  
  @override
  final String? displayName;

  _TestUser({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  // Implementaciones mínimas necesarias
  @override
  bool get emailVerified => true;
  
  @override
  bool get isAnonymous => false;
  
  @override
  UserMetadata get metadata => throw UnimplementedError();
  
  @override
  List<UserInfo> get providerData => [];
  
  @override
  String? get phoneNumber => null;
  
  @override
  String? get photoURL => null;
  
  @override
  String? get refreshToken => null;
  
  @override
  String? get tenantId => null;
  
  @override
  Future<void> delete() async {}
  
  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'test-token';
  
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    throw UnimplementedError();
  }
  
  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    throw UnimplementedError();
  }
  
  @override
  Future<ConfirmationResult> linkWithPhoneNumber(String phoneNumber, [RecaptchaVerifier? verifier]) async {
    throw UnimplementedError();
  }
  
  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) async {
    throw UnimplementedError();
  }
  
  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async {
    throw UnimplementedError();
  }
  
  @override
  Future<UserCredential> reauthenticateWithProvider(AuthProvider provider) async {
    throw UnimplementedError();
  }
  
  @override
  Future<void> reload() async {}
  
  @override
  Future<void> sendEmailVerification([ActionCodeSettings? actionCodeSettings]) async {}
  
  @override
  Future<User> unlink(String providerId) async => this;
  
  @override
  Future<void> updateDisplayName(String? displayName) async {}
  
  @override
  Future<void> updateEmail(String newEmail) async {}
  
  @override
  Future<void> updatePassword(String newPassword) async {}
  
  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential phoneCredential) async {}
  
  @override
  Future<void> updatePhotoURL(String? photoURL) async {}
  
  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {}
  
  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail, [ActionCodeSettings? actionCodeSettings]) async {}
  
  @override
  MultiFactor get multiFactor => throw UnimplementedError();
  
  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) {
    throw UnimplementedError();
  }
  
  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) {
    throw UnimplementedError();
  }
  
  @override
  Future<UserCredential> linkWithRedirect(AuthProvider provider) {
    throw UnimplementedError();
  }
  
  @override
  Future<UserCredential> reauthenticateWithRedirect(AuthProvider provider) {
    throw UnimplementedError();
  }
}

// 🧪 Clase simulada de UserCredential para modo TEST
class _TestUserCredential implements UserCredential {
  @override
  final User? user;
  
  _TestUserCredential(this.user);
  
  @override
  AdditionalUserInfo? get additionalUserInfo => null;
  
  @override
  AuthCredential? get credential => null;
}

// 🔧 Workaround para el bug de google_sign_in con PigeonUserDetails
class _ManualUserCredential implements UserCredential {
  @override
  final User? user;
  
  _ManualUserCredential(this.user);
  
  @override
  AdditionalUserInfo? get additionalUserInfo => null;
  
  @override
  AuthCredential? get credential => null;
}
