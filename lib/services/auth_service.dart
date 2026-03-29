import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String _rememberedEmailKey = 'remembered_email';
  static const String _rememberedPasswordKey = 'remembered_password';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  Future<UserCredential> login({
    required String userId,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: userId.trim(),
      password: password,
    );
    
    // Check if the email is verified
    if (credential.user != null && !credential.user!.emailVerified) {
      // Force sign out so they can't bypass verification via token caching
      await _auth.signOut(); 
      throw Exception('email_not_verified');
    }

    return credential;
  }

  Future<UserCredential> register({
    required String userId,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: userId.trim(),
      password: password,
    );
    
    // Send verification email directly after creating the account
    if (credential.user != null && !credential.user!.emailVerified) {
      await credential.user!.sendEmailVerification();
    }
    
    return credential;
  }

  Future<void> resendVerificationEmail(String email, String password) async {
    // To send a verification email, we must log them in briefly.
    // If it succeeds, we check verification status.
    final credential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    if (credential.user != null) {
      await credential.user!.sendEmailVerification();
      await _auth.signOut();
    }
  }

  Future<void> logout() => _auth.signOut();

  Future<void> rememberCredentials(String email, String password) async {
    await _secureStorage.write(key: _rememberedEmailKey, value: email.trim());
    await _secureStorage.write(key: _rememberedPasswordKey, value: password);
  }

  Future<void> clearRememberedCredentials() async {
    await _secureStorage.delete(key: _rememberedEmailKey);
    await _secureStorage.delete(key: _rememberedPasswordKey);
  }

  Future<Map<String, String>> getRememberedCredentials() async {
    final email = await _secureStorage.read(key: _rememberedEmailKey);
    final password = await _secureStorage.read(key: _rememberedPasswordKey);
    
    return {
      'email': (email?.trim().isEmpty == true ? null : email) ?? '',
      'password': password ?? '',
    };
  }

  Future<String?> getRememberedUserId() async {
    final email = await _secureStorage.read(key: _rememberedEmailKey);
    return email?.trim().isEmpty == true ? null : email;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}
