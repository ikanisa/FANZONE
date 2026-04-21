import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/competition_model.dart';
import '../../../models/match_model.dart';
import '../../../models/team_model.dart';
import '../../../models/team_supporter_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/fz_confetti.dart';
import '../../../widgets/community/contribution_confirm_modal.dart';
import '../../../widgets/community/membership_tier_sheet.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../widgets/team_profile_header.dart';
import '../widgets/team_profile_tabs.dart';
import '../../../widgets/common/fz_glass_loader.dart';

class TeamProfileScreen extends ConsumerStatefulWidget {
  const TeamProfileScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends ConsumerState<TeamProfileScreen> {
  TeamProfileTab _activeTab = TeamProfileTab.overview;
  String? _selectedTier;

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider(widget.teamId));
    final matchesAsync = ref.watch(teamMatchesProvider(widget.teamId));
    final competitionsAsync = ref.watch(competitionsProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final statsAsync = ref.watch(teamCommunityStatsProvider(widget.teamId));
    final fansAsync = ref.watch(teamAnonymousFansProvider(widget.teamId));
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return teamAsync.when(
      data: (team) {
        if (team == null) {
          return _buildStateScaffold(
            context,
            child: StateView.empty(
              title: 'Team not found',
              subtitle:
                  'This club profile is unavailable right now. Please try another team.',
              icon: LucideIcons.shield,
              action: () => context.go('/memberships'),
              actionLabel: 'Back to memberships',
            ),
          );
        }

        final competitions =
            competitionsAsync.valueOrNull ?? const <CompetitionModel>[];
        final matches = matchesAsync.valueOrNull ?? const <MatchModel>[];
        final stats = statsAsync.valueOrNull;
        final fans = fansAsync.valueOrNull ?? const <AnonymousFanRecord>[];
        final clubRank = _computeClubRank(teamsAsync.valueOrNull, team.id);
        final isSupported = supportedIds.contains(team.id);
        final primaryCompetition = _resolvePrimaryCompetition(
          team,
          competitions,
        );

        return Scaffold(
          backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
          body: FzConfetti(
            child: SafeArea(
              child: Column(
                children: [
                  TeamProfileHeader(onBack: () => context.go('/memberships')),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        TeamHeroBanner(
                          team: team,
                          competition: primaryCompetition,
                        ),
                        TeamInfoSection(
                          team: team,
                          stats: stats,
                          clubRank: clubRank,
                          isSupported: isSupported,
                          isAuthenticated: isAuthenticated,
                          onMembershipTap: () => _handleMembershipTap(
                            context,
                            team,
                            isAuthenticated,
                            isSupported,
                          ),
                        ),
                        TeamProfileTabs(
                          activeTab: _activeTab,
                          onChanged: (tab) => setState(() => _activeTab = tab),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                          child: TeamProfileTabBody(
                            activeTab: _activeTab,
                            team: team,
                            matches: matches,
                            stats: stats,
                            fans: fans,
                            selectedTier: _selectedTier,
                            onDialNow: () => _handleDialNow(context, team),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: FzGlassLoader(message: 'Syncing...')),
      error: (error, _) => _buildStateScaffold(
        context,
        child: StateView.error(
          title: 'Could not load team profile',
          onRetry: () => ref.invalidate(teamProvider(widget.teamId)),
        ),
      ),
    );
  }

  Widget _buildStateScaffold(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            TeamProfileHeader(onBack: () => context.go('/memberships')),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  CompetitionModel? _resolvePrimaryCompetition(
    TeamModel team,
    List<CompetitionModel> competitions,
  ) {
    for (final id in team.competitionIds) {
      for (final competition in competitions) {
        if (competition.id == id) return competition;
      }
    }
    return null;
  }

  int _computeClubRank(List<TeamModel>? teams, String teamId) {
    if (teams == null || teams.isEmpty) return 1;
    final sorted = [...teams]..sort((a, b) => b.fanCount.compareTo(a.fanCount));
    final index = sorted.indexWhere((team) => team.id == teamId);
    return index >= 0 ? index + 1 : 1;
  }

  Future<void> _handleMembershipTap(
    BuildContext context,
    TeamModel team,
    bool isAuthenticated,
    bool isSupported,
  ) async {
    if (!isAuthenticated) {
      await showSignInRequiredSheet(
        context,
        title: 'Verify to Join',
        message:
            'Verify your number via WhatsApp to join fan clubs and contribute.',
        from: '/team/${team.id}',
      );
      return;
    }

    final tier = await MembershipTierSheet.show(context);
    if (!mounted || tier == null) return;

    setState(() => _selectedTier = tier);

    if (tier == 'Supporter') {
      if (!isSupported) {
        await ref
            .read(supportedTeamsServiceProvider.notifier)
            .supportTeam(team.id);
      }
      if (context.mounted) {
        FzConfetti.fire(context);
      }
      return;
    }

    setState(() => _activeTab = TeamProfileTab.contribute);
  }

  Future<void> _handleDialNow(BuildContext context, TeamModel team) async {
    final tier = _selectedTier ?? 'Supporter';
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || !context.mounted) return;

    final confirmed = await showContributionConfirmModal(context, tier: tier);
    if (!mounted || !context.mounted || confirmed != true) return;

    final supportedIds =
        ref.read(supportedTeamsServiceProvider).valueOrNull ?? const <String>{};
    if (!supportedIds.contains(team.id)) {
      await ref
          .read(supportedTeamsServiceProvider.notifier)
          .supportTeam(team.id);
    }
    if (!mounted || !context.mounted) return;
    FzConfetti.fire(context);
  }
}
