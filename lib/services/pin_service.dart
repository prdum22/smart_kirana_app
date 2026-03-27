import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _pinKey(String userId) => 'app_pin_$userId';

  Future<void> setPin({
    required String userId,
    required String pin,
  }) async {
    await _storage.write(key: _pinKey(userId), value: pin);
  }

  Future<String?> getPin(String userId) async {
    return _storage.read(key: _pinKey(userId));
  }

  Future<bool> hasPin(String userId) async {
    final pin = await getPin(userId);
    return pin != null && pin.length == 4;
  }

  Future<bool> verifyPin({
    required String userId,
    required String pin,
  }) async {
    final saved = await getPin(userId);
    return saved != null && saved == pin;
  }

  Future<void> clearPin(String userId) async {
    await _storage.delete(key: _pinKey(userId));
  }
}

