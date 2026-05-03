import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/config/platform_feature_access.dart';
import '../../../data/team_search_database.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/favorite_teams_provider.dart';
import '../../../services/push_notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../../ordering/providers/venue_context_provider.dart';
import '../widgets/fan_profile_editor_sheet.dart';
import '../widgets/profile_sections.dart';

/// User profile screen with profile context, preferences, and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSession = ref.watch(isAuthenticatedProvider);
    final isVerified = ref.watch(isFullyAuthenticatedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final featureAccess = ref.watch(platformFeatureAccessProvider);
    final favoriteTeamsAsync = ref.watch(favoriteTeamRecordsProvider);
    final favoriteTeams = favoriteTeamsAsync.valueOrNull ?? const [];
    final venueContext = ref.watch(venueContextProvider);
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
    final settingsRoute = featureAccess.routeFor('settings');
    final notificationsRoute = featureAccess.routeFor('notifications');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 14),
            const FzReferenceHeader(title: 'Sports Elite'),
            const SizedBox(height: 24),

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
              isDark: isDark,
              muted: muted,
              onVerifyPhone: () => showSignInRequiredSheet(
                context,
                title: 'Verify WhatsApp',
                message:
                    'Verify your number to unlock wallet transfers, notifications, and match pools.',
                from: '/profile',
              ),
            ),

            const SizedBox(height: 12),

            ProfileDetailsCard(
              countryLabel: 'Country',
              countryDetail: _countryDetail(
                favoriteTeams,
                loading: favoriteTeamsAsync.isLoading,
              ),
              favoriteTeamsLabel: 'Favorite teams',
              favoriteTeamsDetail: _favoriteTeamsDetail(
                favoriteTeams,
                loading: favoriteTeamsAsync.isLoading,
              ),
              onFavoriteTeamsTap: () {
                if (!hasSession) {
                  showSignInRequiredSheet(
                    context,
                    title: 'Verify WhatsApp',
                    message:
                        'Verify your number before saving your fan profile.',
                    from: '/profile',
                  );
                  return;
                }
                _openFanProfileEditor(context, ref, favoriteTeams);
              },
              linkedVenueLabel: 'Linked venues',
              linkedVenueDetail: _linkedVenueDetail(venueContext),
            ),

            const SizedBox(height: 12),

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
                    'Verify your number to unlock wallet transfers, notifications, and match pools.',
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

  static String _countryDetail(
    List<FavoriteTeamRecordDto> teams, {
    required bool loading,
  }) {
    if (loading) return 'Loading country preference...';
    final team = _firstTeamWithCountry(teams);
    final country = team?.teamCountry?.trim();
    final countryCode = team?.teamCountryCode?.trim().toUpperCase();
    if (country != null && country.isNotEmpty) {
      return 'Used for $country pool filters and featured matches.';
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      return 'Used for $countryCode pool filters and featured matches.';
    }
    return 'Not set. Pick favorite teams to personalize pool filters.';
  }

  static String _favoriteTeamsDetail(
    List<FavoriteTeamRecordDto> teams, {
    required bool loading,
  }) {
    if (loading) return 'Loading favorite teams...';
    if (teams.isEmpty) {
      return 'No favorite teams yet. Add teams to improve featured matches.';
    }

    final grouped = groupFanProfileTeamRecords(teams);
    final summary = <String>[];
    final local = grouped[FanProfileTeamCategory.local]?.firstOrNull;
    if (local != null && local.teamName.trim().isNotEmpty) {
      summary.add('Local: ${local.teamName.trim()}');
    }

    final europeCount =
        grouped[FanProfileTeamCategory.topEuropean]?.length ?? 0;
    if (europeCount > 0) summary.add('Europe: $europeCount');

    final nationalCount = grouped[FanProfileTeamCategory.national]?.length ?? 0;
    if (nationalCount > 0) summary.add('National: $nationalCount');

    if (summary.isNotEmpty) return summary.join(' | ');
    return 'Favorite teams saved.';
  }

  static String _linkedVenueDetail(VenueContext context) {
    final venue = context.venue;
    if (venue == null) {
      return 'No linked venue. Scan a table QR at a FANZONE bar.';
    }
    final tableNumber = context.table?.tableNumber ?? context.tableNumber;
    if (tableNumber != null && tableNumber.toString().trim().isNotEmpty) {
      return '${venue.name}, table $tableNumber';
    }
    return '${venue.name} is your current bar.';
  }

  static Future<void> _openFanProfileEditor(
    BuildContext context,
    WidgetRef ref,
    List<FavoriteTeamRecordDto> favoriteTeams,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => FanProfileEditorSheet(initialTeams: favoriteTeams),
    );

    if (saved == true) {
      ref.invalidate(favoriteTeamRecordsProvider);
    }
  }

  static FavoriteTeamRecordDto? _firstTeamWithCountry(
    List<FavoriteTeamRecordDto> teams,
  ) {
    for (final team in teams) {
      final country = team.teamCountry?.trim();
      final countryCode = team.teamCountryCode?.trim();
      if ((country != null && country.isNotEmpty) ||
          (countryCode != null && countryCode.isNotEmpty)) {
        return team;
      }
    }
    return null;
  }

  static Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
