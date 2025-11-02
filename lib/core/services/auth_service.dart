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
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
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
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _isTestUserLoggedIn = false;
      if (ENABLE_TEST_MODE) {
        _testAuthStateController.add(result.user);
      }
      return result;
    } catch (e) {
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
    try {
      // Trigger the authentication flow
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Check if we have the required tokens
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

      try {
        // Try to sign in with Google credential
        return await _auth.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
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
      print('Error signing in with Google: $e');
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
      final googleSignIn = GoogleSignIn(scopes: ['email']);
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
      await currentUser.linkWithCredential(credential);
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
    await _auth.currentUser?.delete();
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
}

// 🧪 Clase simulada de User para modo TEST
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
