import 'package:flutter/material.dart';
import '../../core/services/security_service.dart';
import '../theme/app_theme.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  String? _error;

  void _onDigitPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _error = null;
      });
      if (_enteredPin.length == 4) {
        _verify();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  Future<void> _verify() async {
    final success = await SecurityService.instance.verifyPin(_enteredPin);
    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        _enteredPin = '';
        _error = 'Incorrect PIN';
      });
    }
  }

  Future<void> _forgotPin() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your School Name to reset PIN to "1234":', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'School Name', hintText: 'Exact school name'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );

    if (ok == true && controller.text.isNotEmpty) {
      final success = await SecurityService.instance.resetPinWithRecovery(controller.text);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN reset to "1234"')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification failed. School name is incorrect.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Logo
            Center(
              child: Image.asset(
                'assets/images/logo.PNG',
                height: 100,
                errorBuilder: (ctx, _, __) => const Icon(Icons.school, size: 80, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 20),
            const Text('App Locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Enter 4-digit PIN to continue', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 40),
            
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16, height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _enteredPin.length ? AppTheme.primary : AppTheme.primary.withOpacity(0.2),
                ),
              )),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
            const Spacer(),
            
            // Keypad
            _buildKeypad(),
            
            const SizedBox(height: 20),
            TextButton(onPressed: _forgotPin, child: const Text('Forgot PIN?', style: TextStyle(fontSize: 13))),
            
            // Footer Credit
            const Padding(
              padding: EdgeInsets.only(bottom: 20, top: 10),
              child: Text('Developed by Engr. Hamza Asad', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['1', '2', '3'].map(_buildKey).toList()),
          const SizedBox(height: 15),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['4', '5', '6'].map(_buildKey).toList()),
          const SizedBox(height: 15),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['7', '8', '9'].map(_buildKey).toList()),
          const SizedBox(height: 15),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            const SizedBox(width: 60),
            _buildKey('0'),
            SizedBox(
              width: 60,
              child: IconButton(onPressed: _onBackspace, icon: const Icon(Icons.backspace_outlined, color: AppTheme.textSecondary)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildKey(String label) {
    return InkWell(
      onTap: () => _onDigitPress(label),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 60, height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
