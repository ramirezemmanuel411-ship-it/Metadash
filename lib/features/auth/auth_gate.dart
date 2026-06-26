import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:metadash/app_shell.dart';
import 'package:metadash/features/auth/sign_in_screen.dart';
import 'package:metadash/features/user_selection/create_user_flow.dart';
import 'package:metadash/providers/user_state.dart';
import 'package:metadash/services/auth_service.dart';
import 'package:metadash/shared/palette.dart';

/// Top-level gate that decides what the signed-in (or signed-out) user sees.
///
/// Flow:
///   not authenticated      -> [SignInScreen]
///   authenticated, profile -> [AppShell]
///   authenticated, no profile yet -> [CreateUserFlow] onboarding, then AppShell
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.userState, this.authService});

  final UserState userState;
  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    final auth = authService ?? AuthService();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoading();
        }
        final account = snapshot.data;
        if (account == null) {
          return SignInScreen(authService: auth);
        }
        return _ProfileResolver(
          key: ValueKey(account.uid),
          userState: userState,
          account: account,
          authService: auth,
        );
      },
    );
  }
}

/// Bridges a Firebase account to a local [UserProfile]: links an existing
/// profile by email, or runs onboarding to create one.
class _ProfileResolver extends StatefulWidget {
  const _ProfileResolver({
    super.key,
    required this.userState,
    required this.account,
    required this.authService,
  });

  final UserState userState;
  final User account;
  final AuthService authService;

  @override
  State<_ProfileResolver> createState() => _ProfileResolverState();
}

class _ProfileResolverState extends State<_ProfileResolver> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final email = widget.account.email;

    // Right profile already loaded in memory.
    if (widget.userState.isLoggedIn &&
        widget.userState.currentUser?.email == email) {
      if (mounted) setState(() => _ready = true);
      return;
    }

    if (email == null || email.isEmpty) {
      // Provider returned no email — can't link or create a profile.
      await widget.authService.signOut();
      return;
    }

    // Returning account → re-link its existing local profile.
    if (await widget.userState.loginByEmail(email)) {
      if (mounted) setState(() => _ready = true);
      return;
    }

    // New account → collect metabolic profile via onboarding.
    if (!mounted) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateUserFlow(
          userState: widget.userState,
          initialEmail: email,
          initialName: widget.account.displayName,
        ),
      ),
    );
    if (!mounted) return;
    if (completed == true && widget.userState.isLoggedIn) {
      setState(() => _ready = true);
    } else {
      // Abandoned onboarding → back to sign-in.
      await widget.authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && widget.userState.isLoggedIn) {
      return AppShell(userState: widget.userState);
    }
    return const _AuthLoading();
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Palette.nightBackground : Palette.dayBackground,
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Palette.forestGreen),
        ),
      ),
    );
  }
}
