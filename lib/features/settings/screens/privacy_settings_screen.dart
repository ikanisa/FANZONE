import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/privacy_settings_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/privacy_settings_service.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';

/// Privacy settings screen — backend-backed visibility controls and
/// release-safe copy around what the app actually exposes.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _showNameOnLeaderboards = false;
  bool _allowFanDiscovery = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!ref.read(isAuthenticatedProvider)) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    try {
      final settings = await PrivacySettingsService.getSettings();
      if (!mounted) return;
      setState(() {
        _showNameOnLeaderboards = settings.showNameOnLeaderboards;
        _allowFanDiscovery = settings.allowFanDiscovery;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your privacy settings.';
      });
    }
  }

  Future<void> _updateSettings({
    bool? showNameOnLeaderboards,
    bool? allowFanDiscovery,
  }) async {
    if (!ref.read(isAuthenticatedProvider)) return;

    final previous = PrivacySettingsModel(
      showNameOnLeaderboards: _showNameOnLeaderboards,
      allowFanDiscovery: _allowFanDiscovery,
    );
    final next = previous.copyWith(
      showNameOnLeaderboards: showNameOnLeaderboards,
      allowFanDiscovery: allowFanDiscovery,
    );

    setState(() {
      _showNameOnLeaderboards = next.showNameOnLeaderboards;
      _allowFanDiscovery = next.allowFanDiscovery;
      _saving = true;
      _error = null;
    });

    try {
      await PrivacySettingsService.saveSettings(next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showNameOnLeaderboards = previous.showNameOnLeaderboards;
        _allowFanDiscovery = previous.allowFanDiscovery;
        _error = 'Could not save your privacy settings.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final isVerified = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'SETTINGS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'Privacy',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                if ((_error ?? '').isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FzColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FzColors.error,
                      ),
                    ),
                  ),
                ],
                Text(
                  'CORE GUARANTEES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                const FzCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _GuaranteeRow(
                        icon: LucideIcons.smartphone,
                        iconColor: FzColors.accent,
                        title: 'Phone Number Hidden',
                        description:
                            'Your phone number is used for sign-in only. It is not shown in public leaderboards, supporter registries, or pool surfaces.',
                        showDivider: true,
                      ),
                      _GuaranteeRow(
                        icon: LucideIcons.shield,
                        iconColor: FzColors.accent,
                        title: 'Fan Identity Stays Private',
                        description:
                            'Public fan spaces use your FANZONE identity only. Personal account data stays inside secured backend records.',
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'VISIBILITY CONTROLS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                FzCard(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    children: [
                      _VisibilityToggle(
                        title: 'Display Name on Leaderboards',
                        description:
                            'Use your display name on public leaderboards instead of your Fan ID.',
                        value: _showNameOnLeaderboards,
                        enabled: isVerified && !_saving,
                        onChanged: (value) =>
                            _updateSettings(showNameOnLeaderboards: value),
                        showDivider: true,
                      ),
                      _VisibilityToggle(
                        title: 'Allow Future Fan Discovery',
                        description:
                            'Store your preference for privacy-safe fan discovery if this feature is enabled later. FANZONE does not access contacts today.',
                        value: _allowFanDiscovery,
                        enabled: isVerified && !_saving,
                        onChanged: (value) =>
                            _updateSettings(allowFanDiscovery: value),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                if (!isVerified) ...[
                  const SizedBox(height: 10),
                  const Text(
                    '* Sign in to manage profile visibility settings.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: FzColors.maltaRed,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _GuaranteeRow extends StatelessWidget {
  const _GuaranteeRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.showDivider,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 70,
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
      ],
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.showDivider,
  });

  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (!enabled)
                          Icon(LucideIcons.lock, size: 12, color: muted),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: Switch.adaptive(
                  value: value && enabled,
                  onChanged: enabled ? onChanged : null,
                  activeColor: FzColors.accent,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 14,
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
      ],
    );
  }
}
