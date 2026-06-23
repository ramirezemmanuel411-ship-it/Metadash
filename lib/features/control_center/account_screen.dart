import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_state.dart';
import '../../services/auth_service.dart';
import '../../shared/palette.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static const _danger = Color(0xFFB3261E);

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            "You'll need to sign in again to access your dashboard."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out', style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final userState = context.read<UserState>();
    await AuthService().signOut();
    userState.logout();
    // The auth-state stream in AuthGate now routes back to the sign-in screen.
  }

  String _methodLabel(User? account) {
    final ids = account?.providerData.map((p) => p.providerId).toList() ?? [];
    if (ids.contains('google.com')) return 'Google';
    if (ids.contains('apple.com')) return 'Apple';
    if (ids.contains('password')) return 'Email & password';
    return 'Account';
  }

  @override
  Widget build(BuildContext context) {
    final account = FirebaseAuth.instance.currentUser;
    final email = account?.email ?? 'Unknown account';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Palette.dayCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Palette.forestGreen,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Palette.dayTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Signed in with ${_methodLabel(account)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Palette.dayTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout, color: _danger),
              label: const Text(
                'Sign out',
                style: TextStyle(color: _danger, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
