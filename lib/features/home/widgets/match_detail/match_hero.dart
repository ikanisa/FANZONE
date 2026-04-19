part of '../../screens/match_detail_screen.dart';

class _MatchHero extends StatelessWidget {
  const _MatchHero({required this.match, required this.competitionLabel});

  final MatchModel match;
  final String competitionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          FzBadge(label: competitionLabel.toUpperCase(), fontSize: 9),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _HeroTeam(name: match.homeTeam)),
              SizedBox(
                width: 92,
                child: Column(
                  children: [
                    Text(
                      match.scoreDisplay ?? 'VS',
                      style: FzTypography.scoreLarge(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusLabel(match),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? FzColors.darkMuted
                            : FzColors.lightMuted,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _HeroTeam(name: match.awayTeam)),
            ],
          ),
          if (match.isLive) ...[
            const SizedBox(height: 16),
            Text(
              'Last updated: ${DateFormat.Hm().format(DateTime.now())}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkMuted
                    : FzColors.lightMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(MatchModel match) {
    if (match.isLive) return 'LIVE';
    if (match.isFinished) return 'FULL TIME';
    return match.kickoffTime ?? 'SCHEDULED';
  }
}

class _HeroTeam extends StatelessWidget {
  const _HeroTeam({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamAvatar(name: name, size: 54),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
