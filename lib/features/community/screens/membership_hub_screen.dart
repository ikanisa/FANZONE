import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/team_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/fan_identity_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_confetti.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/community/contribution_confirm_modal.dart';
import '../../../widgets/community/membership_share_modal.dart';
import '../../../widgets/community/membership_tier_sheet.dart';
import '../widgets/contribution_history_list.dart';
import '../widgets/digital_membership_card.dart';
import '../widgets/membership_details_card.dart';
import '../widgets/membership_hub_widgets.dart';
import '../../../widgets/common/fz_glass_loader.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';

class MembershipHubScreen extends ConsumerStatefulWidget {
  const MembershipHubScreen({super.key});

  @override
  ConsumerState<MembershipHubScreen> createState() =>
      _MembershipHubScreenState();
}

class _MembershipHubScreenState extends ConsumerState<MembershipHubScreen> {
  MembershipFilter _filter = MembershipFilter.myClubs;
  String _searchQuery = '';
  String? _membershipTierOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final teamsAsync = ref.watch(teamsProvider);
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final fanProfile = ref.watch(fanProfileProvider).valueOrNull;
    final isVerified = ref.watch(isAuthenticatedProvider);
    final membershipTier =
        _membershipTierOverride ??
        _membershipTierForLevel(fanProfile?.currentLevel ?? 1);
    final clubSplit = _fetSplitForTier(membershipTier);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 68,
        leadingWidth: 56,
        leading: IconButton(
          onPressed: () => context.go('/profile'),
          icon: const Icon(LucideIcons.chevronLeft),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FAN CLUBS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Membership Hub',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
        actions: const [SizedBox(width: 56)],
      ),
      body: teamsAsync.when(
        data: (teams) {
          final supportedTeams = teams
              .where((team) => supportedIds.contains(team.id))
              .toList();
          final activeClub = supportedTeams.isNotEmpty
              ? supportedTeams.first
              : null;
          final filteredTeams = _applyFilter(teams, supportedIds, _searchQuery);
          final contributionsAsync = activeClub == null
              ? null
              : ref.watch(teamContributionHistoryProvider(activeClub.id));

          return FzConfetti(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                MembershipTabBar(
                  filter: _filter,
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: 20),
                if (_filter == MembershipFilter.myClubs) ...[
                  if (!isVerified)
                    _VerifyToJoinCard(
                      onVerify: () => showSignInRequiredSheet(
                        context,
                        title: 'Verify to Join',
                        message:
                            'You need to verify your phone number via WhatsApp to join fan clubs and contribute.',
                        from: '/memberships',
                      ),
                    )
                  else ...[
                    SectionTitleRow(
                      title: 'DIGITAL CARD',
                      actionLabel: fanId == null || activeClub == null
                          ? null
                          : 'Share',
                      onAction: fanId == null || activeClub == null
                          ? null
                          : () => showMembershipShareModal(context, ref: ref),
                    ),
                    const SizedBox(height: 10),
                    RepaintBoundary(
                      child: DigitalMembershipCard(
                        activeClub: activeClub,
                        fanId: fanId,
                        membershipTier: membershipTier,
                        clubSplit: clubSplit,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitleRow(title: 'MEMBERSHIP DETAILS'),
                    const SizedBox(height: 10),
                    if (activeClub == null)
                      StateView.empty(
                        title: 'No active memberships yet',
                        subtitle:
                            'Support a club to unlock a digital card, supporter registry entry, and club-linked identity.',
                        icon: LucideIcons.badgeCheck,
                      )
                    else
                      RepaintBoundary(
                        child: MembershipDetailsCard(
                          activeClub: activeClub,
                          membershipTier: membershipTier,
                          clubSplit: clubSplit,
                          rank: 42,
                          onUpgrade: () =>
                              _handleTierSelection(context, activeClub),
                        ),
                      ),
                    const SizedBox(height: 20),
                    const SectionTitleRow(title: 'CONTRIBUTION HISTORY'),
                    const SizedBox(height: 10),
                    if (activeClub == null || contributionsAsync == null)
                      StateView.empty(
                        title: 'No club selected yet',
                        subtitle:
                            'Join a club first to start tracking verified supporter contributions.',
                        icon: LucideIcons.receipt,
                      )
                    else
                      RepaintBoundary(
                        child: contributionsAsync.when(
                          data: (contributions) => ContributionHistoryList(
                            contributions: contributions,
                            membershipTier: membershipTier,
                          ),
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: FzGlassLoader(message: 'Syncing...'),
                          ),
                          error: (error, stackTrace) => StateView.error(
                            title: 'Could not load contribution history',
                            onRetry: () => ref.invalidate(
                              teamContributionHistoryProvider(activeClub.id),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    const SectionTitleRow(title: 'MY CLUBS'),
                    const SizedBox(height: 10),
                    if (supportedTeams.isEmpty)
                      StateView.empty(
                        title: 'No memberships yet',
                        subtitle:
                            'Open club discovery to build your supporter registry.',
                        icon: LucideIcons.users,
                      )
                    else
                      RepaintBoundary(
                        child: ClubList(
                          teams: supportedTeams,
                          supportedIds: supportedIds,
                          onTapTeam: (team) => context.push('/team/${team.id}'),
                        ),
                      ),
                  ],
                ] else ...[
                  DiscoverSearchCard(
                    hintText: 'Search clubs...',
                    categoryLabel: _filter == MembershipFilter.malta
                        ? 'Malta'
                        : 'European Fan Clubs',
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 16),
                  if (filteredTeams.isEmpty)
                    StateView.empty(
                      title: 'No clubs in this segment',
                      subtitle:
                          'Try another search or open club discovery for the wider supporter registry.',
                      icon: LucideIcons.search,
                    )
                  else
                    RepaintBoundary(
                      child: ClubList(
                        teams: filteredTeams,
                        supportedIds: supportedIds,
                        onTapTeam: (team) => context.push('/team/${team.id}'),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
        loading: () => const FzGlassLoader(message: 'Syncing...'),
        error: (error, stackTrace) => StateView.error(
          title: 'Could not load membership hub',
          onRetry: () => ref.invalidate(teamsProvider),
        ),
      ),
    );
  }

  List<TeamModel> _applyFilter(
    List<TeamModel> teams,
    Set<String> supportedIds,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    bool matchesSearch(TeamModel team) {
      if (normalizedQuery.isEmpty) return true;
      return [team.name, team.leagueName, team.country].whereType<String>().any(
        (value) => value.toLowerCase().contains(normalizedQuery),
      );
    }

    String lowerCountry(TeamModel team) => (team.country ?? '').toLowerCase();

    switch (_filter) {
      case MembershipFilter.myClubs:
        return teams
            .where(
              (team) => supportedIds.contains(team.id) && matchesSearch(team),
            )
            .toList();
      case MembershipFilter.malta:
        return teams
            .where(
              (team) =>
                  lowerCountry(team).contains('malta') && matchesSearch(team),
            )
            .toList();
      case MembershipFilter.european:
        return teams
            .where(
              (team) =>
                  !lowerCountry(team).contains('malta') && matchesSearch(team),
            )
            .take(16)
            .toList();
    }
  }

  String _membershipTierForLevel(int level) {
    if (level >= 6) return 'Legend';
    if (level >= 4) return 'Ultra';
    if (level >= 2) return 'Member';
    return 'Supporter';
  }

  int _fetSplitForTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'legend':
        return 35;
      case 'ultra':
        return 20;
      case 'member':
        return 10;
      default:
        return 0;
    }
  }

  Future<void> _handleTierSelection(
    BuildContext context,
    TeamModel activeClub,
  ) async {
    final tier = await MembershipTierSheet.show(context);
    if (!mounted || !context.mounted || tier == null) return;

    if (tier == 'Supporter') {
      setState(() => _membershipTierOverride = tier);
      FzConfetti.fire(context);
      return;
    }

    final confirmed = await showContributionConfirmModal(context, tier: tier);
    if (!mounted || !context.mounted || confirmed != true) return;

    setState(() => _membershipTierOverride = tier);
    FzConfetti.fire(context);
    ref.invalidate(teamContributionHistoryProvider(activeClub.id));
  }
}

class _VerifyToJoinCard extends StatelessWidget {
  const _VerifyToJoinCard({required this.onVerify});

  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: panel,
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            alignment: Alignment.center,
            child: const Text('🤖', style: TextStyle(fontSize: 36)),
          ),
          const SizedBox(height: 24),
          Text(
            'VERIFY TO JOIN',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You need to verify your phone number via WhatsApp to join fan clubs and contribute.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onVerify,
            style: FilledButton.styleFrom(
              backgroundColor: FzColors.primary,
              foregroundColor: FzColors.darkBg,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: const Text(
              'VERIFY WHATSAPP',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
