import 'package:flutter/material.dart';

import 'package:metadash/core/services/auth_service.dart';
import 'package:metadash/core/shared/palette.dart';

/// Entry screen for unauthenticated users. Handles email/password (sign in +
/// sign up), Google, and Apple (when enabled). On success, the auth-state
/// stream in the app's [AuthGate] takes over — this screen does nothing else.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

enum _Mode { signIn, signUp }

class _SignInScreenState extends State<SignInScreen> {
  late final AuthService _auth = widget.authService ?? AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isSignUp => _mode == _Mode.signUp;

  String? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      // Success: the AuthGate stream rebuilds the tree away from this screen.
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitEmail() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    await _run(() async {
      if (_isSignUp) {
        await _auth.signUpWithEmail(email: email, password: password);
      } else {
        await _auth.signInWithEmail(email: email, password: password);
      }
    });
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email above first, then tap reset.');
      return;
    }
    await _run(() => _auth.sendPasswordReset(email));
    if (mounted && _error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.dayBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 32),
                  _card(),
                  const SizedBox(height: 20),
                  _modeToggle(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Palette.forestGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.monitor_heart_outlined,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'MetaDash',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Palette.dayTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isSignUp
              ? 'Create your account to get started'
              : 'Sign in to your metabolic dashboard',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Palette.dayTextSecondary),
        ),
      ],
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Palette.dayCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            controller: _emailController,
            label: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: true,
            onSubmitted: (_) => _submitEmail(),
          ),
          if (!_isSignUp)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _forgotPassword,
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(color: Palette.forestGreen),
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          _primaryButton(
            label: _isSignUp ? 'Create account' : 'Sign in',
            onPressed: _loading ? null : _submitEmail,
          ),
          const SizedBox(height: 18),
          _orDivider(),
          const SizedBox(height: 18),
          _socialButton(
            label: 'Continue with Google',
            leading: _googleGlyph(),
            onPressed: _loading
                ? null
                : () => _run(() => _auth.signInWithGoogle()),
          ),
          if (AuthService.appleSignInAvailable) ...[
            const SizedBox(height: 12),
            _socialButton(
              label: 'Continue with Apple',
              leading: const Icon(
                Icons.apple,
                color: Palette.dayTextPrimary,
                size: 22,
              ),
              onPressed: _loading
                  ? null
                  : () => _run(() => _auth.signInWithApple()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      enabled: !_loading,
      textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Palette.dayTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Palette.dayTextSecondary),
        prefixIcon: Icon(icon, color: Palette.dayTextSecondary, size: 20),
        filled: true,
        fillColor: Palette.dayBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.forestGreen, width: 1.5),
        ),
      ),
    );
  }

  Widget _primaryButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Palette.forestGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required Widget leading,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Palette.dayTextPrimary,
          side: const BorderSide(color: Palette.daySecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _googleGlyph() {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Palette.daySecondary),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }

  Widget _orDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: Palette.daySecondary)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: Palette.dayTextMuted)),
        ),
        Expanded(child: Divider(color: Palette.daySecondary)),
      ],
    );
  }

  Widget _modeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp ? 'Already have an account?' : "Don't have an account?",
          style: const TextStyle(color: Palette.dayTextSecondary),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                  _mode = _isSignUp ? _Mode.signIn : _Mode.signUp;
                  _error = null;
                }),
          child: Text(
            _isSignUp ? 'Sign in' : 'Sign up',
            style: const TextStyle(
              color: Palette.forestGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
