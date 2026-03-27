import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _rememberedUserIdKey = 'remembered_user_id';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  Future<UserCredential> login({
    required String userId,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: userId.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String userId,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: userId.trim(),
      password: password,
    );
  }

  Future<void> logout() => _auth.signOut();

  Future<void> rememberUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedUserIdKey, userId.trim());
  }

  Future<void> clearRememberedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedUserIdKey);
  }

  Future<String?> getRememberedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_rememberedUserIdKey);
    return value?.trim().isEmpty == true ? null : value;
  }
}

