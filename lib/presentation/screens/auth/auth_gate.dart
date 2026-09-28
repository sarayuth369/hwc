import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/user_profile.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/profile_repository.dart';
import '../home/home_shell.dart';
import '../onboarding/onboarding_screen.dart';
import 'sign_in_screen.dart';

/// Boot-time gate: signed out -> auth flow; signed in but no display name
/// yet -> the existing name-capture onboarding step; otherwise -> the Home
/// shell. Listens to `AuthRepository.authStateChanges` so sign-in/sign-out
/// from anywhere in the app swaps the whole tree without manual navigation.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = context.read<AuthRepository>();
    return StreamBuilder<bool>(
      stream: authRepository.authStateChanges,
      initialData: authRepository.isSignedIn,
      builder: (context, snapshot) {
        final signedIn = snapshot.data ?? false;
        if (!signedIn) return const SignInScreen();
        return const _PostSignInGate();
      },
    );
  }
}

class _PostSignInGate extends StatefulWidget {
  const _PostSignInGate();

  @override
  State<_PostSignInGate> createState() => _PostSignInGateState();
}

class _PostSignInGateState extends State<_PostSignInGate> {
  late final Future<UserProfile?> _profileFuture =
      context.read<ProfileRepository>().fetchProfile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final hasName = (snapshot.data?.displayName ?? '').trim().isNotEmpty;
        return hasName ? const HomeShell() : const OnboardingScreen();
      },
    );
  }
}
