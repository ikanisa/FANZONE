import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_feature_access.dart';
import '../../../models/auth_and_user/privacy_settings_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/privacy_settings_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../widgets/privacy_widgets.dart';
import '../../../widgets/common/fz_glass_loader.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _showNameInPoolActivity = false;
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
        _showNameInPoolActivity = settings.showNameInPoolActivity;
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

  Future<void> _updateSettings({bool? showNameInPoolActivity}) async {
    if (!ref.read(isFullyAuthenticatedProvider)) return;

    final previous = PrivacySettingsModel(
      showNameInPoolActivity: _showNameInPoolActivity,
    );
    final next = previous.copyWith(
      showNameInPoolActivity: showNameInPoolActivity,
    );

    setState(() {
      _showNameInPoolActivity = next.showNameInPoolActivity;
      _saving = true;
      _error = null;
    });

    try {
      await PrivacySettingsService.saveSettings(next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showNameInPoolActivity = previous.showNameInPoolActivity;
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
                              'Visibility Controls'.toUpperCase(),
                              style: FzTypography.sectionLabel(
                                Theme.of(context).brightness,
                              ).copyWith(color: muted),
                            ),
                            const SizedBox(height: 12),
                            if (!isVerified)
                              PrivacySourceCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Verify WhatsApp to manage privacy controls.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton(
                                      onPressed: () => context.go(
                                        '/login?from=${Uri.encodeComponent('/settings/privacy')}',
                                      ),
                                      child: const Text('Verify WhatsApp'),
                                    ),
                                  ],
                                ),
                              )
                            else
                              PrivacySourceCard(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    VisibilityControlRow(
                                      title: 'Display Name in Pool Activity',
                                      description:
                                          'Show your display name instead of your Fan ID on pool and share-card surfaces.',
                                      value: _showNameInPoolActivity,
                                      enabled: !_saving,
                                      showDivider: false,
                                      onChanged: (value) => _updateSettings(
                                        showNameInPoolActivity: value,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
