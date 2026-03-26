import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../models/data_inputs_settings.dart';
import '../../services/health_service.dart';

class WearablesConnectionsScreen extends StatefulWidget {
  const WearablesConnectionsScreen({super.key});

  @override
  State<WearablesConnectionsScreen> createState() => _WearablesConnectionsScreenState();
}

class _WearablesConnectionsScreenState extends State<WearablesConnectionsScreen> {
  bool _isLoading = true;
  DataInputsSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final defaults = DataInputsSettings.defaults(user.id!).copyWith(
      stepGoal: user.dailyStepsGoal,
    );
    final resolved = (await userState.db.getDataInputsSettings(user.id!)) ?? defaults;
    var next = resolved;

    // Don't override user's preference on every load
    // Trust what they've chosen. Only verify if they claim to be connected.
    try {
      if (Platform.isIOS && next.appleHealthConnected) {
        final authorized = await HealthService().hasPermissions();
        if (!authorized) {
          // User said they connected but permissions aren't granted - show helpful message
          next = next.copyWith(appleHealthConnected: false);
        }
      } else if (Platform.isAndroid && next.googleFitConnected) {
        final authorized = await HealthService().hasPermissions();
        if (!authorized) {
          // User said they connected but permissions aren't granted - show helpful message
          next = next.copyWith(googleFitConnected: false);
        }
      }
    } catch (e) {
      // Silently fail if health service is unavailable (e.g., debugger disconnect)
      // ignore: avoid_print
      print('Warning: Could not check health permissions: $e');
    }

    await userState.db.createOrUpdateDataInputsSettings(next);

    setState(() {
      _settings = next;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings(DataInputsSettings next) async {
    final userState = Provider.of<UserState>(context, listen: false);
    await userState.db.createOrUpdateDataInputsSettings(next);
    setState(() => _settings = next);
  }

  Future<void> _connectAppleHealth() async {
    final current = _settings;
    if (current == null) return;
    
    // Request permissions (shows system dialog)
    await HealthService().requestPermissions();
    
    // Check if actually granted
    final authorized = await HealthService().hasPermissions();
    if (!mounted) return;
    
    if (authorized) {
      await _saveSettings(current.copyWith(appleHealthConnected: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Apple Health connected! Data will sync automatically.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You can enable this anytime in the Health app settings.'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Open Health',
            onPressed: _openHealthAppOrStore,
          ),
        ),
      );
    }
  }

  Future<void> _connectGoogleFit() async {
    final current = _settings;
    if (current == null) return;
    
    // Request permissions (shows system dialog)
    await HealthService().requestPermissions();
    
    // Check if actually granted
    final authorized = await HealthService().hasPermissions();
    if (!mounted) return;
    
    if (authorized) {
      await _saveSettings(current.copyWith(googleFitConnected: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Google Fit connected! Data will sync automatically.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You can enable this anytime in Health Connect settings.'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Open Health Connect',
            onPressed: _openHealthAppOrStore,
          ),
        ),
      );
    }
  }

  Future<void> _openHealthAppOrStore() async {
    try {
      if (Platform.isIOS) {
        final healthUri = Uri.parse('x-apple-health://');
        if (await canLaunchUrl(healthUri)) {
          await launchUrl(healthUri, mode: LaunchMode.externalApplication);
          return;
        }
        await openAppSettings();
        return;
      }

      if (Platform.isAndroid) {
        final healthConnectUri = Uri.parse('android-app://com.google.android.apps.healthdata');
        if (await canLaunchUrl(healthConnectUri)) {
          await launchUrl(healthConnectUri, mode: LaunchMode.externalApplication);
          return;
        }

        final googleFitUri = Uri.parse('android-app://com.google.android.apps.fitness');
        if (await canLaunchUrl(googleFitUri)) {
          await launchUrl(googleFitUri, mode: LaunchMode.externalApplication);
          return;
        }

        final playStoreUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
        );
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Wearables & Health Data'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Connect Apple Health / Google Fit and choose what to import.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.5),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  children: [
                    _ConnectionRow(
                      icon: Icons.apple,
                      title: 'Apple Health',
                      connected: settings?.appleHealthConnected ?? false,
                      onConnect: _connectAppleHealth,
                      onDisconnect: () => _saveSettings(
                        settings!.copyWith(appleHealthConnected: false),
                      ),
                    ),
                    const _SectionDivider(),
                    _ConnectionRow(
                      icon: Icons.android,
                      title: 'Google Fit / Health Connect',
                      connected: settings?.googleFitConnected ?? false,
                      onConnect: _connectGoogleFit,
                      onDisconnect: () => _saveSettings(
                        settings!.copyWith(googleFitConnected: false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.black.withOpacity(0.06),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool connected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _ConnectionRow({
    required this.icon,
    required this.title,
    required this.connected,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  connected ? 'Connected' : 'Not connected',
                  style: TextStyle(
                    fontSize: 13,
                    color: connected
                        ? Palette.forestGreen.withOpacity(0.9)
                        : Colors.black.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: connected ? onDisconnect : onConnect,
            style: TextButton.styleFrom(
              foregroundColor: connected
                  ? Colors.redAccent
                  : Palette.forestGreen.withOpacity(0.9),
            ),
            child: Text(connected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }
}
