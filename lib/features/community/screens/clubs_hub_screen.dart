import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/market/launch_market.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/fan_identity_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/team/team_widgets.dart';

class ClubsHubScreen extends ConsumerWidget {
  const ClubsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final teamsAsync = ref.watch(teamsProvider);
    final featuredAsync = ref.watch(featuredTeamsProvider);
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final fanProfile = ref.watch(fanProfileProvider).valueOrNull;
    final primaryRegion = ref.watch(primaryMarketRegionProvider);
    final focusTags = ref.watch(marketFocusTagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CLUBS & FAN ZONES',
          style: FzTypography.display(
            size: 28,
            color: isDark ? FzColors.darkText : FzColors.lightText,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          FzCard(
            padding: const EdgeInsets.all(20),
            borderColor: FzColors.accent.withValues(alpha: 0.22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support clubs, join anonymous fan registries, and build a stronger identity around teams in ${launchRegionLabel(primaryRegion).toLowerCase()} and across the global football map.',
                  style: TextStyle(fontSize: 13, color: muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MarketBadge(label: launchRegionLabel(primaryRegion)),
                    for (final tag
                        in (focusTags.isEmpty
                                ? defaultFocusTagsForRegion(primaryRegion)
                                : focusTags.toList())
                            .take(2))
                      _MarketBadge(
                        label: launchMomentByTag(tag)?.title ?? tag,
                        accent: true,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _HubMetric(
                        label: 'Supported Clubs',
                        value: '${supportedIds.length}',
                        icon: LucideIcons.users,
                      ),
                    ),
                    Expanded(
                      child: _HubMetric(
                        label: 'Fan ID',
                        value: fanId != null ? '#$fanId' : '—',
                        icon: LucideIcons.hash,
                      ),
                    ),
                    Expanded(
                      child: _HubMetric(
                        label: 'Level',
                        value: fanProfile != null
                            ? 'Lv.${fanProfile.currentLevel}'
                            : 'Lv.1',
                        icon: LucideIcons.award,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _ClubActionCard(
                icon: LucideIcons.badgeCheck,
                title: 'Membership',
                subtitle: 'Cards, tiers, and supporter registry',
                onTap: () => context.push('/clubs/membership'),
              ),
              _ClubActionCard(
                icon: LucideIcons.hash,
                title: 'Fan ID',
                subtitle: 'Identity, privacy, badges, and XP',
                onTap: () => context.push('/clubs/fan-id'),
              ),
              _ClubActionCard(
                icon: LucideIcons.messagesSquare,
                title: 'Social',
                subtitle: 'Challenge feed and club fan zones',
                onTap: () => context.push('/clubs/social'),
              ),
              _ClubActionCard(
                icon: LucideIcons.search,
                title: 'Discover Clubs',
                subtitle: 'Browse teams and support new clubs',
                onTap: () => context.push('/clubs/teams'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'My Clubs',
            actionLabel: 'Manage',
            onAction: () => context.push('/clubs/teams'),
          ),
          const SizedBox(height: 10),
          teamsAsync.when(
            data: (teams) {
              final supported = teams
                  .where((team) => supportedIds.contains(team.id))
                  .toList();
              if (supported.isEmpty) {
                return StateView.empty(
                  title: 'No supported clubs yet',
                  subtitle:
                      'Choose a club to join its fan registry and community.',
                  icon: LucideIcons.users,
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < supported.take(4).length; i++) ...[
                    SupportedTeamCard(
                      team: supported[i],
                      index: i,
                      onTap: () =>
                          context.push('/clubs/team/${supported[i].id}'),
                    ),
                    if (i < supported.take(4).length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => StateView.error(
              title: 'Could not load your clubs',
              onRetry: () => ref.invalidate(teamsProvider),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Featured Clubs',
            actionLabel: 'All Clubs',
            onAction: () => context.push('/clubs/teams'),
          ),
          const SizedBox(height: 10),
          featuredAsync.when(
            data: (teams) {
              if (teams.isEmpty) {
                return FzCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Featured clubs will appear here once they are available.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < teams.take(3).length; i++) ...[
                    TeamCard(
                      team: teams[i],
                      index: i,
                      onTap: () => context.push('/clubs/team/${teams[i].id}'),
                    ),
                    if (i < teams.take(3).length - 1) const SizedBox(height: 8),
                  ],
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => FzCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Featured clubs are unavailable right now.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketBadge extends StatelessWidget {
  const _MarketBadge({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent
            ? FzColors.accent.withValues(alpha: 0.12)
            : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent
              ? FzColors.accent
              : (isDark ? FzColors.darkText : FzColors.lightText),
        ),
      ),
    );
  }
}

class _HubMetric extends StatelessWidget {
  const _HubMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Column(
      children: [
        Icon(icon, size: 18, color: FzColors.accent),
        const SizedBox(height: 8),
        Text(value, style: FzTypography.score(size: 16)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _ClubActionCard extends StatelessWidget {
  const _ClubActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderColor: FzColors.accent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FzColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: FzColors.accent, size: 18),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: FzTypography.sectionLabel(Theme.of(context).brightness),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
