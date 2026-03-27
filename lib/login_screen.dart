import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final String? initialUserId;
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

  @override
  void initState() {
    super.initState();
    _userIdController.text = widget.initialUserId ?? '';
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
        _error = e.toString().replaceFirst('Exception: ', '');
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
                        value: _rememberUserId,
                        title: const Text('Remember User ID'),
                        onChanged: (v) =>
                            setState(() => _rememberUserId = v ?? true),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
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
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Forgot Password: coming soon'),
                            ),
                          );
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

