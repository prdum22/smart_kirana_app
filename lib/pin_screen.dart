import 'package:flutter/material.dart';

class PinScreen extends StatefulWidget {
  final Future<bool> Function(String pin) onVerifyPin;
  final VoidCallback onLoginWithPassword;

  const PinScreen({
    super.key,
    required this.onVerifyPin,
    required this.onLoginWithPassword,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  bool _loading = false;
  String? _error;

  Future<void> _appendDigit(String d) async {
    if (_loading || _pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length != 4) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await widget.onVerifyPin(_pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _pin = '';
        _error = 'Wrong PIN. Please try again.';
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  void _backspace() {
    if (_loading || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _dot(bool filled) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Colors.indigo : Colors.indigo.shade100,
      ),
    );
  }

  Widget _key(String label, {VoidCallback? onTap}) {
    return SizedBox(
      width: 72,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Enter 4-digit PIN',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) => _dot(i < _pin.length)),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                if (_loading) ...[
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(strokeWidth: 2),
                ],
                const SizedBox(height: 20),
                Wrap(
                  runSpacing: 10,
                  spacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                      _key(d, onTap: () => _appendDigit(d)),
                    _key('0', onTap: () => _appendDigit('0')),
                    _key('⌫', onTap: _backspace),
                  ],
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _loading ? null : widget.onLoginWithPassword,
                  child: const Text('Login with Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

