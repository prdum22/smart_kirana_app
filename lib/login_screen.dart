import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String? initialUserId;
  final String? initialPassword;
  final bool showRegister;
  final Future<void> Function({
    required String userId,
    required String password,
    required bool rememberUserId,
  })
  onLogin;
  final VoidCallback? onOpenRegister;

  const LoginScreen({
    super.key,
    required this.onLogin,
    this.initialUserId,
    this.initialPassword,
    this.onOpenRegister,
    this.showRegister = true,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberUserId = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;
  bool _showResendVerification = false;

  @override
  void initState() {
    super.initState();
    _userIdController.text = widget.initialUserId ?? '';
    _passwordController.text = widget.initialPassword ?? '';
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.onLogin(
        userId: _userIdController.text.trim(),
        password: _passwordController.text,
        rememberUserId: _rememberUserId,
      );
    } catch (e) {
      setState(() {
        String errorMsg = e.toString().replaceFirst('Exception: ', '');
        _showResendVerification = false;
        
        if (errorMsg.contains('CONFIGURATION_NOT_FOUND')) {
          errorMsg = 'Developer Error: Email/Password login is not enabled in Firebase Console.';
        } else if (errorMsg == 'email_not_verified') {
          errorMsg = 'Please verify your email before logging in. Check your inbox.';
          _showResendVerification = true;
        }
        
        _error = errorMsg;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Smart Kirana Login',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _userIdController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'User ID (Email)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter user ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter password';
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _rememberUserId,
                        title: const Text('Remember Login Info / लॉगिन याद रखें'),
                        onChanged: (v) =>
                            setState(() => _rememberUserId = v ?? true),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        if (_showResendVerification) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () async {
                              try {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sending link...')),
                                );
                                await AuthService().resendVerificationEmail(
                                  _userIdController.text.trim(),
                                  _passwordController.text,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Verification link sent! Check your inbox.')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: ${e.toString()}')),
                                  );
                                }
                              }
                            },
                            child: const Text('Resend Verification Link'),
                          ),
                        ]
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Login'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          final email = _userIdController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid email ID above to reset password'),
                              ),
                            );
                            return;
                          }
                          try {
                            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password reset link sent to your email! / लिंक भेज दिया गया है'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Forgot Password'),
                      ),
                      if (widget.showRegister && widget.onOpenRegister != null)
                        TextButton(
                          onPressed: widget.onOpenRegister,
                          child: const Text('Create new account'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

