part of '../../screens/match_detail_screen.dart';

class _H2HTab extends ConsumerWidget {
  const _H2HTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final matchesAsync = ref.watch(
      competitionMatchesProvider(match.competitionId),
    );

    return matchesAsync.when(
      data: (allMatches) {
        final meetings = allMatches.where((m) {
          if (!m.isFinished) return false;
          if (m.id == match.id) return false;
          final teams = {m.homeTeam, m.awayTeam};
          return teams.contains(match.homeTeam) &&
              teams.contains(match.awayTeam);
        }).toList()..sort((a, b) => b.date.compareTo(a.date));
        final recent = meetings.take(5).toList();

        List<String> formGuide(String teamName) {
          return allMatches
              .where(
                (m) =>
                    m.isFinished &&
                    (m.homeTeam == teamName || m.awayTeam == teamName),
              )
              .take(5)
              .map((m) {
                final isHome = m.homeTeam == teamName;
                final scored = isHome ? (m.ftHome ?? 0) : (m.ftAway ?? 0);
                final conceded = isHome ? (m.ftAway ?? 0) : (m.ftHome ?? 0);
                if (scored > conceded) return 'W';
                if (scored < conceded) return 'L';
                return 'D';
              })
              .toList();
        }

        final homeForm = formGuide(match.homeTeam);
        final awayForm = formGuide(match.awayTeam);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Recent Form',
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 12),
            FzCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _FormRow(
                    teamName: match.homeTeam,
                    form: homeForm,
                    isDark: isDark,
                    muted: muted,
                  ),
                  const SizedBox(height: 12),
                  _FormRow(
                    teamName: match.awayTeam,
                    form: awayForm,
                    isDark: isDark,
                    muted: muted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Last Meetings',
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              FzCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No previous meetings found.',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              )
            else
              ...recent.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FzCard(
                    padding: EdgeInsets.zero,
                    child: MatchListRow(
                      match: m,
                      onTap: () => context.push('/match/${m.id}'),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const FzGlassLoader(message: 'Syncing...'),
      error: (err, st) => StateView.error(
        title: 'H2H unavailable',
        onRetry: () =>
            ref.invalidate(competitionMatchesProvider(match.competitionId)),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.teamName,
    required this.form,
    required this.isDark,
    required this.muted,
  });

  final String teamName;
  final List<String> form;
  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamAvatar(name: teamName, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            teamName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: form.map((result) {
            return Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: _formColor(result),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  result,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _formColor(String result) {
    switch (result) {
      case 'W':
        return FzColors.success;
      case 'L':
        return FzColors.danger;
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _PredictTab extends StatelessWidget {
  const _PredictTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    if (match.isFinished) {
      return StateView.empty(
        title: 'Markets Closed',
        subtitle: 'This match has ended.',
        icon: Icons.lock_clock,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CrowdPredictionBar(matchId: match.id),
        ),
        const SizedBox(height: 12),
        MatchResultMarket(match: match),
        CorrectScoreMarket(match: match),
        const SizedBox(height: 16),
        FzCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prediction rules',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 10),
              Text(
                'Markets lock at kick-off. Settlements are based on the official full-time score once the match is final.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FzColors.darkMuted
                      : FzColors.lightMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
