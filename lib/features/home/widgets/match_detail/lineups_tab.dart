part of '../../screens/match_detail_screen.dart';

class _LineupsTab extends ConsumerWidget {
  const _LineupsTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final playersAsync = ref.watch(matchPlayerStatsProvider(match.id));

    return playersAsync.when(
      data: (players) {
        if (players.isEmpty) {
          return Center(
            child: StateView.empty(
              title: match.isUpcoming
                  ? 'Available ~1h before KO'
                  : 'Unavailable',
              subtitle: '',
              icon: Icons.people_outline_rounded,
            ),
          );
        }

        final homePlayers =
            players.where((p) => p.teamId == match.homeTeamId).toList()
              ..sort((a, b) {
                if (a.isStarter != b.isStarter) return a.isStarter ? -1 : 1;
                return (b.rating ?? 0).compareTo(a.rating ?? 0);
              });
        final awayPlayers =
            players.where((p) => p.teamId == match.awayTeamId).toList()
              ..sort((a, b) {
                if (a.isStarter != b.isStarter) return a.isStarter ? -1 : 1;
                return (b.rating ?? 0).compareTo(a.rating ?? 0);
              });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PlayerSection(
              teamName: match.homeTeam,
              players: homePlayers,
              isDark: isDark,
              muted: muted,
            ),
            const SizedBox(height: 24),
            _PlayerSection(
              teamName: match.awayTeam,
              players: awayPlayers,
              isDark: isDark,
              muted: muted,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => StateView.error(
        title: 'Could not load lineups',
        onRetry: () => ref.invalidate(matchPlayerStatsProvider(match.id)),
      ),
    );
  }
}

class _PlayerSection extends StatelessWidget {
  const _PlayerSection({
    required this.teamName,
    required this.players,
    required this.isDark,
    required this.muted,
  });

  final String teamName;
  final List<MatchPlayerStats> players;
  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final starters = players.where((p) => p.isStarter).toList();
    final subs = players.where((p) => !p.isStarter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TeamAvatar(name: teamName, size: 24),
            const SizedBox(width: 10),
            Text(
              teamName.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FzCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (var i = 0; i < starters.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                  ),
                _PlayerRow(player: starters[i], isDark: isDark, muted: muted),
              ],
            ],
          ),
        ),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'SUBS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          FzCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (var i = 0; i < subs.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                  _PlayerRow(player: subs[i], isDark: isDark, muted: muted),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.isDark,
    required this.muted,
  });

  final MatchPlayerStats player;
  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final ratingColor = player.rating == null
        ? muted
        : player.rating! >= 7.5
        ? FzColors.success
        : player.rating! >= 6.0
        ? FzColors.coral
        : FzColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              player.playerNumber?.toString() ?? '--',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.playerName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (player.position != null)
                  Text(
                    player.positionLabel,
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
              ],
            ),
          ),
          if (player.goals > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sports_soccer_rounded,
                    size: 12,
                    color: FzColors.accent,
                  ),
                  if (player.goals > 1)
                    Text(
                      ' x${player.goals}',
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                ],
              ),
            ),
          if (player.assists > 0)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.assistant_rounded,
                size: 12,
                color: FzColors.amber,
              ),
            ),
          if (player.yellowCards > 0)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.square_rounded, size: 10, color: Colors.amber),
            ),
          if (player.redCards > 0)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.square_rounded, size: 10, color: Colors.red),
            ),
          if (player.rating != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ratingColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                player.rating!.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ratingColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
