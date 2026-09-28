import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/auth_failure.dart';
import '../../../domain/repositories/auth_repository.dart';

/// After a successful sign-up, `AuthGate` picks up the new session via
/// `authStateChanges` and moves on to the name step automatically — this
/// screen has nothing more to do than pop back to `SignInScreen`'s stack
/// position (which `AuthGate` will have already replaced by then).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      setState(() {
        _errorMessage = 'Enter a valid email and a password of at least 6 characters.';
        _infoMessage = null;
      });
      return;
    }

    final authRepository = context.read<AuthRepository>();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await authRepository.signUp(email: email, password: password);
      if (!mounted) return;
      if (!authRepository.isSignedIn) {
        // Email confirmation required before a session exists.
        setState(() {
          _infoMessage = 'Check your email to confirm your account, then sign in.';
        });
      }
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join HWC',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('A calm companion for your everyday wellness.'),
                const SizedBox(height: 32),
                TextField(
                  key: const Key('signUpEmailField'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('signUpPasswordField'),
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (min 6 characters)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    key: const Key('signUpErrorMessage'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                if (_infoMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _infoMessage!,
                    key: const Key('signUpInfoMessage'),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('signUpButton'),
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
