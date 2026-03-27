import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'billing_screen.dart';
import 'customer_screen.dart';
import 'ledger_screen.dart';
import 'daily_report_screen.dart';
import 'login_screen.dart';
import 'pin_screen.dart';
import 'register_screen.dart';
import 'set_pin_screen.dart';
import 'services/auth_service.dart';
import 'services/pin_service.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartKiranaApp());
}

class SmartKiranaApp extends StatelessWidget {
  const SmartKiranaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Kirana',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.grey.shade100,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

enum _GateStage { loading, login, register, setPin, pin, home }

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final _authService = AuthService();
  final _sessionService = SessionService();
  final _pinService = PinService();

  _GateStage _stage = _GateStage.loading;
  String? _rememberedUserId;
  bool _pinResetMode = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lockOnResume();
    }
  }

  Future<void> _lockOnResume() async {
    if (_uid == null || _stage == _GateStage.login || _stage == _GateStage.register) {
      return;
    }
    final valid = await _sessionService.isSessionValidFor(_uid!);
    if (!valid) {
      if (!mounted) return;
      setState(() => _stage = _GateStage.login);
      return;
    }
    final hasPin = await _pinService.hasPin(_uid!);
    if (!mounted) return;
    if (hasPin && _stage == _GateStage.home) {
      setState(() => _stage = _GateStage.pin);
    }
  }

  Future<void> _init() async {
    _rememberedUserId = await _authService.getRememberedUserId();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;
    if (user == null) {
      if (!mounted) return;
      setState(() => _stage = _GateStage.login);
      return;
    }

    final valid = await _sessionService.isSessionValidFor(user.uid);
    if (!valid) {
      if (!mounted) return;
      setState(() => _stage = _GateStage.login);
      return;
    }

    final hasPin = await _pinService.hasPin(user.uid);
    if (!mounted) return;
    setState(() => _stage = hasPin ? _GateStage.pin : _GateStage.setPin);
  }

  Future<void> _handleLogin({
    required String userId,
    required String password,
    required bool rememberUserId,
  }) async {
    final credential = await _authService.login(userId: userId, password: password);
    final uid = credential.user?.uid;
    if (uid == null) throw Exception('Login failed');

    if (rememberUserId) {
      await _authService.rememberUserId(userId);
    } else {
      await _authService.clearRememberedUserId();
    }

    await _sessionService.startSession(uid);
    _uid = uid;

    final hasPin = await _pinService.hasPin(uid);
    if (!mounted) return;
    setState(() {
      if (_pinResetMode) {
        _stage = _GateStage.setPin;
        _pinResetMode = false;
      } else {
        _stage = hasPin ? _GateStage.pin : _GateStage.setPin;
      }
    });
  }

  Future<void> _handleRegister({
    required String userId,
    required String password,
  }) async {
    await _authService.register(userId: userId, password: password);
    // Return to login after registration
    await _authService.logout();
    if (!mounted) return;
    setState(() {
      _rememberedUserId = userId;
      _stage = _GateStage.login;
    });
  }

  Future<void> _handleSetPin(String pin) async {
    final uid = _uid ?? _authService.currentUserId;
    if (uid == null) throw Exception('Session missing');
    await _pinService.setPin(userId: uid, pin: pin);
    if (!mounted) return;
    setState(() => _stage = _GateStage.home);
  }

  Future<bool> _handleVerifyPin(String pin) async {
    final uid = _uid ?? _authService.currentUserId;
    if (uid == null) return false;
    final ok = await _pinService.verifyPin(userId: uid, pin: pin);
    if (!mounted) return false;
    if (ok) setState(() => _stage = _GateStage.home);
    return ok;
  }

  void _openPasswordForPinReset() {
    setState(() {
      _pinResetMode = true;
      _stage = _GateStage.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _GateStage.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _GateStage.login:
        return LoginScreen(
          initialUserId: _rememberedUserId,
          onLogin: _handleLogin,
          onOpenRegister: () => setState(() => _stage = _GateStage.register),
        );
      case _GateStage.register:
        return RegisterScreen(
          onRegister: _handleRegister,
          onBackToLogin: () => setState(() => _stage = _GateStage.login),
        );
      case _GateStage.setPin:
        return SetPinScreen(
          isReset: _pinResetMode,
          onSavePin: _handleSetPin,
        );
      case _GateStage.pin:
        return PinScreen(
          onVerifyPin: _handleVerifyPin,
          onLoginWithPassword: _openPasswordForPinReset,
        );
      case _GateStage.home:
        return const HomeScreen();
    }
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget buildButton(
    BuildContext context, {
    required IconData icon,
    required String englishText,
    required String hindiText,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.indigo.shade100),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.indigo.withValues(alpha: 0.08),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: Colors.indigo.shade700),
              const SizedBox(height: 8),
              Text(
                englishText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hindiText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.indigo.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openPlaceholder(BuildContext context, String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title page coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Kirana / स्मार्ट किराना'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            buildButton(
              context,
              icon: Icons.receipt_long,
              englishText: 'New Bill',
              hindiText: 'नया बिल',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BillingScreen()),
                );
              },
            ),
            buildButton(
              context,
              icon: Icons.people,
              englishText: 'Customers',
              hindiText: 'ग्राहक',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerScreen()),
                );
              },
            ),
            buildButton(
              context,
              icon: Icons.book,
              englishText: 'Ledger',
              hindiText: 'उधार खाता',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LedgerScreen()),
                );
              },
            ),
            buildButton(
              context,
              icon: Icons.bar_chart,
              englishText: 'Daily Report',
              hindiText: 'रोज़ की रिपोर्ट',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailyReportScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
