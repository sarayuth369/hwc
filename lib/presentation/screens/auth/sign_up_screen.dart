import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/auth_failure.dart';
import '../../../domain/repositories/auth_repository.dart';

/// After a successful sign-up, `AuthGate` picks up the new session via
/// `authStateChanges` and moves on to the name step automatically — this
/// screen has nothing more to do than pop back to `SignInScreen`'s stack
/// position (which `AuthGate` will have already replaced by then).
///
/// The confirmation-required path needs the same handling for a *later*
/// session: the user leaves this screen showing "check your email",
/// backgrounds the app, taps the confirmation link (which resumes the app
/// via the deep link and creates a session), and returns to find this
/// screen still on top, exactly where they left it — `AuthGate` has
/// already swapped underneath by then, same as the immediate-session case,
/// just delayed. This screen listens for that and pops itself the moment
/// it happens, so returning from the email link lands on Welcome/Home
/// directly instead of requiring a manual "Back to sign in" tap.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;
  StreamSubscription<bool>? _authSubscription;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _watchForConfirmation(AuthRepository authRepository) {
    _authSubscription ??= authRepository.authStateChanges.listen((signedIn) {
      if (signedIn && mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_emailPattern.hasMatch(email)) {
      setState(() {
        _errorMessage = 'Enter a valid email address.';
        _infoMessage = null;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters.';
        _infoMessage = null;
      });
      return;
    }
    if (password != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
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
      if (authRepository.isSignedIn) {
        // A session already exists (no email confirmation required by this
        // Supabase project's settings) -- `AuthGate` has already rebuilt
        // itself into the name-capture/Home flow underneath this pushed
        // route, but that rebuild is invisible until this route is popped.
        // Without this pop the user appeared stuck back on Create Account.
        Navigator.of(context).pop();
        return;
      }
      // Email confirmation required before a session exists. Start
      // watching now -- the confirmation may complete while this screen
      // is still showing (see the class doc comment above).
      _watchForConfirmation(authRepository);
      setState(() {
        _infoMessage = "Check your email — we've sent a confirmation link. "
            "Tap it and you'll come straight back into the app.";
      });
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
                const SizedBox(height: 16),
                TextField(
                  key: const Key('signUpConfirmPasswordField'),
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
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
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('signUpBackToSignInButton'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to sign in'),
                  ),
                ] else ...[
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
