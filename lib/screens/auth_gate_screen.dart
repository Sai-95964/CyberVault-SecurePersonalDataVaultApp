import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';

/// Decides initial route: SetPassword (first time) or Login.
class AuthGateScreen extends StatefulWidget {
  static const routeName = '/';

  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    try {
      if (!mounted) return;
      // Always show sign-in first; create account is linked from login.
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    } catch (e, st) {
      debugPrint('AuthGate navigation failed: $e\n$st');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
