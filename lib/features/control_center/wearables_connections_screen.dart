import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../models/data_inputs_settings.dart';
import '../../services/health_service.dart';
import '../../engine/wearable_calibration.dart';

class WearablesConnectionsScreen extends StatefulWidget {
  const WearablesConnectionsScreen({super.key});

  @override
  State<WearablesConnectionsScreen> createState() =>
      _WearablesConnectionsScreenState();
}

class _WearablesConnectionsScreenState
    extends State<WearablesConnectionsScreen> {
  bool _isLoading = true;
  DataInputsSettings? _settings;

  // Ordered list of selectable device options
  static const _devices = [
    _DeviceOption('Apple Watch', WearableFamily.appleWatch, Icons.watch_rounded, Color(0xFF1C1C1E)),
    _DeviceOption('Garmin', WearableFamily.garmin, Icons.gps_fixed_rounded, Color(0xFF006DC6)),
    _DeviceOption('Fitbit / Sense', WearableFamily.fitbit, Icons.monitor_heart_rounded, Color(0xFF00B0B9)),
    _DeviceOption('WHOOP', WearableFamily.whoop, Icons.bolt_rounded, Color(0xFF1A1A2E)),
    _DeviceOption('Samsung Galaxy Watch', WearableFamily.samsungGalaxyWatch, Icons.watch_outlined, Color(0xFF1428A0)),
    _DeviceOption('Polar', WearableFamily.polar, Icons.favorite_rounded, Color(0xFFD0021B)),
    _DeviceOption('Oura Ring', WearableFamily.oura, Icons.circle_outlined, Color(0xFF2D2D2D)),
    _DeviceOption('Pixel Watch', WearableFamily.pixelWatch, Icons.watch_rounded, Color(0xFF4285F4)),
    _DeviceOption('Other / Unknown', WearableFamily.unknown, Icons.device_unknown_rounded, null),
  ];

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

    final defaults = DataInputsSettings.defaults(
      user.id!,
    ).copyWith(stepGoal: user.dailyStepsGoal);
    final resolved =
        (await userState.db.getDataInputsSettings(user.id!)) ?? defaults;
    var next = resolved;

    try {
      if (Platform.isIOS && next.appleHealthConnected) {
        final authorized = await HealthService().hasPermissions();
        if (!authorized) {
          next = next.copyWith(appleHealthConnected: false);
        }
      } else if (Platform.isAndroid && next.googleFitConnected) {
        final authorized = await HealthService().hasPermissions();
        if (!authorized) {
          next = next.copyWith(googleFitConnected: false);
        }
      }
    } catch (e) {
      debugPrint('Warning: Could not check health permissions: $e');
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
    final messenger = ScaffoldMessenger.of(context);
    await HealthService().requestPermissions();
    final authorized = await HealthService().hasPermissions();
    if (!mounted) return;
    if (authorized) {
      await _saveSettings(current.copyWith(appleHealthConnected: true));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✓ Apple Health connected! Data will sync automatically.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('You can enable this anytime in the Health app settings.'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: 'Open Health', onPressed: _openHealthAppOrStore),
        ),
      );
    }
  }

  Future<void> _connectGoogleFit() async {
    final current = _settings;
    if (current == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await HealthService().requestPermissions();
    final authorized = await HealthService().hasPermissions();
    if (!mounted) return;
    if (authorized) {
      await _saveSettings(current.copyWith(googleFitConnected: true));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✓ Google Fit connected! Data will sync automatically.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('You can enable this anytime in Health Connect settings.'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: 'Open Health Connect', onPressed: _openHealthAppOrStore),
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
    final colors = context.colors;
    final settings = _settings;
    final currentFamily = WearableCalibration.fromStorageString(settings?.wearableFamily);
    final multiplier = WearableCalibration.multiplierFor(currentFamily);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: const Text('Wearables & Health Data'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── Health platform connection ─────────────────────────
                _SectionLabel('HEALTH PLATFORM'),
                const SizedBox(height: 8),
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
                const SizedBox(height: 24),

                // ── Device picker ────────────────────────────────────
                _SectionLabel('YOUR WEARABLE DEVICE'),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Tell MetaDash which device you wear so we can apply the correct calorie accuracy correction to your TDEE.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                _SectionCard(
                  children: _devices.asMap().entries.map((e) {
                    final isLast = e.key == _devices.length - 1;
                    final device = e.value;
                    final isSelected = currentFamily == device.family;
                    return Column(
                      children: [
                        _DeviceRow(
                          device: device,
                          isSelected: isSelected,
                          onTap: () => _saveSettings(
                            settings!.copyWith(
                              wearableFamily: WearableCalibration.toStorageString(device.family),
                            ),
                          ),
                        ),
                        if (!isLast) const _SectionDivider(),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── Calibration info card ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 16, color: colors.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Calorie Accuracy Correction',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _CalibrationStat(
                              label: 'Device',
                              value: _devices
                                  .firstWhere((d) => d.family == currentFamily,
                                      orElse: () => _devices.last)
                                  .name,
                            ),
                          ),
                          Expanded(
                            child: _CalibrationStat(
                              label: 'Multiplier',
                              value: '${(multiplier * 100).toStringAsFixed(0)}%',
                            ),
                          ),
                          Expanded(
                            child: _CalibrationStat(
                              label: 'Overcounts by',
                              value: '~${((1 - multiplier) * 100).toStringAsFixed(0)}%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'All wearables overestimate active calories. MetaDash scales reported workout calories by your device\'s correction factor before factoring them into your TDEE.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Data class ──────────────────────────────────────────────────────────────

class _DeviceOption {
  final String name;
  final WearableFamily family;
  final IconData icon;
  final Color? color;

  const _DeviceOption(this.name, this.family, this.icon, this.color);
}

// ── Section helpers ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: context.colors.textMuted,
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: context.colors.textMuted.withValues(alpha: 0.03),
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
      color: context.colors.divider.withValues(alpha: 0.06),
    );
  }
}

// ── Connection row ──────────────────────────────────────────────────────────

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
          Icon(icon, size: 20, color: context.colors.textPrimary.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  connected ? 'Connected' : 'Not connected',
                  style: TextStyle(
                    fontSize: 13,
                    color: connected
                        ? context.colors.accent.withValues(alpha: 0.9)
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: connected ? onDisconnect : onConnect,
            style: TextButton.styleFrom(
              foregroundColor: connected
                  ? Theme.of(context).colorScheme.error
                  : context.colors.accent.withValues(alpha: 0.9),
            ),
            child: Text(connected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }
}

// ── Device row ──────────────────────────────────────────────────────────────

class _DeviceRow extends StatelessWidget {
  final _DeviceOption device;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceRow({
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final deviceColor = device.color ?? colors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: deviceColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(device.icon, size: 18, color: deviceColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? colors.accent : colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${(WearableCalibration.multiplierFor(device.family) * 100).toStringAsFixed(0)}% calorie accuracy correction applied',
                    style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colors.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? colors.accent : colors.divider,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Calibration stat tile ───────────────────────────────────────────────────

class _CalibrationStat extends StatelessWidget {
  final String label;
  final String value;

  const _CalibrationStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colors.accent,
          ),
        ),
      ],
    );
  }
}

