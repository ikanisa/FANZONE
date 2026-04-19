import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/privacy_settings_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/privacy_settings_service.dart';
import '../../../theme/colors.dart';

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
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _SettingsHeader(
              onBack: () => context.go('/profile'),
              muted: muted,
              textColor: textColor,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                          children: [
                            if ((_error ?? '').isNotEmpty) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: FzColors.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: FzColors.error.withValues(
                                      alpha: 0.24,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: FzColors.error,
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              'Core Guarantees'.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: muted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const _SourceCard(
                              child: Column(
                                children: [
                                  _GuaranteeRow(
                                    icon: LucideIcons.smartphone,
                                    iconColor: Color(0xFF25D366),
                                    title: 'Phone Number Hidden',
                                    description:
                                        'Your WhatsApp/Phone number is encrypted and stored server-side only. It is never exposed to other users, club admins, or in public leaderboards.',
                                    showDivider: true,
                                  ),
                                  _GuaranteeRow(
                                    icon: LucideIcons.shield,
                                    iconColor: FzColors.accent,
                                    title: 'Anonymous Contributions',
                                    description:
                                        'MoMo contributions to fan clubs are logged using your Fan ID and amount bracket only. Exact amounts and phone numbers are not recorded.',
                                    showDivider: false,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Visibility Controls'.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: muted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SourceCard(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  _VisibilityControlRow(
                                    title: 'Display Name on Leaderboards',
                                    description:
                                        'Show your custom display name instead of your anonymous Fan ID on public leaderboards.',
                                    value: _showNameOnLeaderboards,
                                    enabled: isVerified && !_saving,
                                    showDivider: true,
                                    onChanged: (value) => _updateSettings(
                                      showNameOnLeaderboards: value,
                                    ),
                                  ),
                                  _VisibilityControlRow(
                                    title: 'Allow Friends to Find Me',
                                    description:
                                        'Allow other users who have your phone number in their contacts to find your Fan ID.',
                                    value: _allowFanDiscovery,
                                    enabled: isVerified && !_saving,
                                    showDivider: false,
                                    onChanged: (value) => _updateSettings(
                                      allowFanDiscovery: value,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isVerified) ...[
                              const SizedBox(height: 12),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '* Verification required to change visibility settings.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: FzColors.coral,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.onBack,
    required this.muted,
    required this.textColor,
  });

  final VoidCallback onBack;
  final Color muted;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: (isDark ? FzColors.darkSurface : FzColors.lightSurface)
            .withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(LucideIcons.chevronLeft, color: textColor),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Privacy',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: child,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                ),
              )
            : null,
      ),
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: muted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityControlRow extends StatelessWidget {
  const _VisibilityControlRow({
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.showDivider,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final bool showDivider;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!enabled) ...[
                        const SizedBox(width: 8),
                        Icon(LucideIcons.lock, size: 12, color: muted),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: muted, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          _SourceToggle(
            value: value && enabled,
            enabled: enabled,
            onTap: enabled ? () => onChanged(!value) : null,
          ),
        ],
      ),
    );
  }
}

class _SourceToggle extends StatelessWidget {
  const _SourceToggle({
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final bool value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = value ? FzColors.accent : _trackColor(context);
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 24,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: value ? 28 : 4,
                top: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _trackColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
  }
}
