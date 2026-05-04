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
import '../../../providers/profile_country_provider.dart';
import '../../../services/push_notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/fz_card.dart';
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
    final profileCountryCode = ref.watch(profileCountryProvider);
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
            const FzReferenceHeader(title: 'FZ'),
            const SizedBox(height: 24),

            // Header title
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'PROFILE',
                      style: FzTypography.sportsTitle(
                        size: 36,
                        color: FzColors.darkText,
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
                message: 'Unlock wallet and pools.',
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
                    message: 'Unlock profile.',
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

            ProfileCountryPreferenceCard(
              selectedCountryCode: profileCountryCode,
              onSelected: ref
                  .read(profileCountryProvider.notifier)
                  .setCountryCode,
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
                message: 'Unlock wallet and pools.',
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
                      fontSize: 12,
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
    if (loading) return 'Loading...';
    final team = _firstTeamWithCountry(teams);
    final country = team?.teamCountry?.trim();
    final countryCode = team?.teamCountryCode?.trim().toUpperCase();
    if (country != null && country.isNotEmpty) {
      return country;
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      return countryCode;
    }
    return 'Pick teams.';
  }

  static String _favoriteTeamsDetail(
    List<FavoriteTeamRecordDto> teams, {
    required bool loading,
  }) {
    if (loading) return 'Loading...';
    if (teams.isEmpty) {
      return 'No teams.';
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
    return 'Saved.';
  }

  static String _linkedVenueDetail(VenueContext context) {
    final venue = context.venue;
    if (venue == null) {
      return 'No bar.';
    }
    final tableNumber = context.table?.tableNumber ?? context.tableNumber;
    if (tableNumber != null && tableNumber.toString().trim().isNotEmpty) {
      return '${venue.name}, table $tableNumber';
    }
    return venue.name;
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

class ProfileCountryPreferenceCard extends StatelessWidget {
  const ProfileCountryPreferenceCard({
    super.key,
    required this.selectedCountryCode,
    required this.onSelected,
  });

  final String selectedCountryCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.globe2, size: 18, color: FzColors.cyan),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Country',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Personalizes pools.',
            style: TextStyle(
              color: FzColors.darkMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FzPill(
                label: 'Malta',
                icon: LucideIcons.mapPin,
                selected: selectedCountryCode == 'MT',
                onTap: () => onSelected('MT'),
              ),
              FzPill(
                label: 'Rwanda',
                icon: LucideIcons.mapPin,
                selected: selectedCountryCode == 'RW',
                onTap: () => onSelected('RW'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
