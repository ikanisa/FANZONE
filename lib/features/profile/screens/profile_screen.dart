import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/config/feature_flags.dart';
import '../../../features/profile/providers/profile_identity_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/favorite_teams_provider.dart';
import '../../../services/push_notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../services/wallet_service.dart';
import '../../../widgets/common/fz_wordmark.dart';
import '../widgets/profile_sections.dart';

/// User profile screen with real auth data, FET balance, quick links, and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletServiceProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final favoriteTeamsAsync = ref.watch(favoriteTeamRecordsProvider);
    final profileIdentity = ref.watch(profileIdentityProvider).valueOrNull;
    final flags = ref.watch(featureFlagsProvider);
    final showWallet = isAuthenticated && flags.wallet;
    final showPredictions = isAuthenticated && flags.predictions;
    const showClubs = true;
    final showRewards = isAuthenticated && (flags.rewards || flags.marketplace);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),

            // Header title
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profile',
                      style: FzTypography.display(
                        size: 36,
                        letterSpacing: 0.4,
                        color: isDark ? FzColors.darkText : FzColors.lightText,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Open settings',
                    child: InkWell(
                      onTap: () => context.go('/settings'),
                      borderRadius: FzRadii.fullRadius,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? FzColors.darkSurface2
                              : FzColors.lightSurface2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? FzColors.darkBorder
                                : FzColors.lightBorder,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.settings,
                          size: 18,
                          color: muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            ProfileHeaderCard(
              isAuthenticated: isAuthenticated,
              fanId: fanId,
              favoriteTeamsAsync: favoriteTeamsAsync,
              profileIdentity: profileIdentity,
              isDark: isDark,
              muted: muted,
              balanceAsync: balanceAsync,
              showWallet: showWallet,
              onSelectIdentity: () => showProfileIdentityPicker(
                context,
                ref,
                teams: favoriteTeamsAsync.valueOrNull ?? const [],
                selectedTeamId: profileIdentity?.teamId,
              ),
              onWalletTap: () => context.go('/wallet'),
              onVerifyPhone: () => context.go('/login'),
            ),

            const SizedBox(height: 12),

            ProfileQuickLinksCard(
              showClubs: showClubs,
              showWallet: showWallet,
              showPredictions: showPredictions,
              showRewards: showRewards,
            ),

            const SizedBox(height: 16),

            ProfileAccountLinksCard(
              onHelp: () => _launchUrl(context, 'https://fanzone.mt/help'),
              showVerifyAction: !isAuthenticated,
              onVerifyPhone: () => context.go('/login'),
              showSignOut: isAuthenticated,
              onSignOut: () async {
                final authService = ref.read(authServiceProvider);
                final pushService = ref.read(pushNotificationServiceProvider);
                ref.read(authExitIntentProvider.notifier).state =
                    AuthExitIntent.manualSignOut;
                await pushService.unregisterCurrentToken();
                await authService.signOut();
                if (context.mounted) {
                  context.go('/');
                }
              },
            ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.only(top: 24, bottom: 100),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text.rich(
                    TextSpan(
                      children: FzWordmark.spansForText(
                        '${AppConfig.appName} v${AppConfig.appVersion}',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
