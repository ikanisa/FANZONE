import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/config/platform_feature_access.dart';
import '../../../features/profile/providers/profile_identity_provider.dart';
import '../../../features/venue_dashboard/providers/venue_dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/favorite_teams_provider.dart';
import '../../../services/push_notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../services/wallet_service.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../widgets/profile_sections.dart';

/// User profile screen with real auth data, FET balance, quick links, and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletServiceProvider);
    final hasSession = ref.watch(isAuthenticatedProvider);
    final isVerified = ref.watch(isFullyAuthenticatedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final favoriteTeamsAsync = ref.watch(favoriteTeamRecordsProvider);
    final isVenueOwner = ref.watch(isVenueOwnerProvider);
    final profileIdentity = ref.watch(profileIdentityProvider).valueOrNull;
    final featureAccess = ref.watch(platformFeatureAccessProvider);
    final showWallet =
        hasSession &&
        featureAccess.isVisible('wallet', surface: PlatformSurface.route);
    final showPredictions =
        featureAccess.isVisible('predictions', surface: PlatformSurface.route);
    final showLeaderboard = featureAccess.isVisible(
      'leaderboard',
      surface: PlatformSurface.route,
    );
    final showSettings = featureAccess.isVisible(
      'settings',
      surface: PlatformSurface.route,
    );
    final showInbox =
        isVerified &&
        featureAccess.isVisible(
          'notifications',
          surface: PlatformSurface.route,
        );
    final predictionRoute = featureAccess.routeFor('predictions');
    final leaderboardRoute = featureAccess.routeFor('leaderboard');
    final walletRoute = featureAccess.routeFor('wallet');
    final settingsRoute = featureAccess.routeFor('settings');
    final notificationsRoute = featureAccess.routeFor('notifications');

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
                  if (showSettings)
                    Tooltip(
                      message: 'Open settings',
                      child: InkWell(
                        onTap: () => context.push(settingsRoute),
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
              hasSession: hasSession,
              isVerified: isVerified,
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
              onWalletTap: () => context.push(walletRoute),
              onVerifyPhone: () => showSignInRequiredSheet(
                context,
                title: 'Verify WhatsApp',
                message:
                    'Verify your number to unlock wallet transfers, notifications, and saved predictions.',
                from: '/profile',
              ),
            ),

            const SizedBox(height: 12),

            ProfileQuickLinksCard(
              showLeaderboard: showLeaderboard,
              showWallet: showWallet,
              showPredictions: showPredictions,
              isVenueOwner: isVenueOwner,
              onPredictionsTap: () => context.go(predictionRoute),
              onLeaderboardTap: () => context.push(leaderboardRoute),
              onWalletTap: () => context.push(walletRoute),
              onVenueDashboardTap: () => context.push('/venue-dashboard'),
            ),

            const SizedBox(height: 16),

            ProfileAccountLinksCard(
              onHelp: () =>
                  _launchUrl(context, 'https://fanzone.ikanisa.com/help'),
              showInbox: showInbox,
              showSettings: showSettings,
              showVerifyAction: !isVerified,
              onVerifyPhone: () => showSignInRequiredSheet(
                context,
                title: 'Verify WhatsApp',
                message:
                    'Verify your number to unlock wallet transfers, notifications, and saved predictions.',
                from: '/profile',
              ),
              showSignOut: hasSession,
              onInboxTap: () => context.push(notificationsRoute),
              onSettingsTap: () => context.push(settingsRoute),
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
                  Text(
                    '${AppConfig.appName} v${AppConfig.appVersion}',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: muted,
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
