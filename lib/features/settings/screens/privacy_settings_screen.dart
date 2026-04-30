import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/config/platform_feature_access.dart';
import '../../../models/auth_and_user/privacy_settings_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/privacy_settings_service.dart';
import '../../../theme/colors.dart';
import '../widgets/privacy_widgets.dart';
import '../../../widgets/common/fz_glass_loader.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _showNameOnLeaderboards = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!ref.read(isFullyAuthenticatedProvider)) {
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
  }) async {
    if (!ref.read(isFullyAuthenticatedProvider)) return;

    final previous = PrivacySettingsModel(
      showNameOnLeaderboards: _showNameOnLeaderboards,
    );
    final next = previous.copyWith(
      showNameOnLeaderboards: showNameOnLeaderboards,
    );

    setState(() {
      _showNameOnLeaderboards = next.showNameOnLeaderboards;
      _saving = true;
      _error = null;
    });

    try {
      await PrivacySettingsService.saveSettings(next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showNameOnLeaderboards = previous.showNameOnLeaderboards;
        _error = 'Could not save your privacy settings.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final isVerified = ref.watch(isFullyAuthenticatedProvider);
    final profileRoute = ref
        .watch(platformFeatureAccessProvider)
        .routeFor('profile');

    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            PrivacySettingsHeader(
              onBack: () => context.go(profileRoute),
              muted: muted,
              textColor: textColor,
            ),
            Expanded(
              child: _loading
                  ? const FzGlassLoader(message: 'Syncing...')
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
                            const PrivacySourceCard(
                              child: Column(
                                children: [
                                  GuaranteeRow(
                                    icon: LucideIcons.smartphone,
                                    iconColor: FzColors.primary,
                                    title: 'Phone Number Hidden',
                                    description:
                                        'Your WhatsApp/Phone number is encrypted and stored server-side only. It is never exposed to other users, club admins, or in public leaderboards.',
                                    showDivider: true,
                                  ),
                                  GuaranteeRow(
                                    icon: LucideIcons.shield,
                                    iconColor: FzColors.primary,
                                    title: 'Anonymous Rewards',
                                    description:
                                        'Prediction rewards and token transfers are logged using your Fan ID and reward or amount metadata only. Exact phone numbers are not exposed publicly.',
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
                            PrivacySourceCard(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  VisibilityControlRow(
                                    title: 'Display Name on Leaderboards',
                                    description:
                                        'Show your custom display name instead of your anonymous Fan ID on public leaderboards.',
                                    value: _showNameOnLeaderboards,
                                    enabled: isVerified && !_saving,
                                    showDivider: false,
                                    onChanged: (value) => _updateSettings(
                                      showNameOnLeaderboards: value,
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
