part of '../../screens/match_detail_screen.dart';

class _MatchHero extends StatelessWidget {
  const _MatchHero({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final innerSurface = isDark ? FzColors.darkSurface3 : FzColors.lightSurface;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _HeroTeam(
                  name: match.homeTeam,
                  logoUrl: match.homeLogoUrl,
                  surface: innerSurface,
                  border: border,
                ),
              ),
              SizedBox(
                width: 108,
                child: Column(
                  children: [
                    Text(
                      match.scoreDisplay ?? 'VS',
                      style: FzTypography.score(size: 36),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: match.isLive
                            ? FzColors.accent.withValues(alpha: 0.12)
                            : innerSurface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: match.isLive
                              ? FzColors.accent.withValues(alpha: 0.22)
                              : border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (match.isLive) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: FzColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _statusLabel(match),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: match.isLive
                                  ? FzColors.accent
                                  : (isDark
                                        ? FzColors.darkMuted
                                        : FzColors.lightMuted),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _HeroTeam(
                  name: match.awayTeam,
                  logoUrl: match.awayLogoUrl,
                  surface: innerSurface,
                  border: border,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(MatchModel match) {
    if (match.isLive) return "${match.kickoffTime ?? 'LIVE'} LIVE";
    if (match.isFinished) return 'FULL TIME';
    return match.kickoffTime ?? 'SCHEDULED';
  }
}

class _HeroTeam extends StatelessWidget {
  const _HeroTeam({
    required this.name,
    required this.logoUrl,
    required this.surface,
    required this.border,
  });

  final String name;
  final String? logoUrl;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final label = _abbr(name);

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: surface,
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: Center(
            child: TeamAvatar(name: name, logoUrl: logoUrl, size: 44),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  String _abbr(String teamName) {
    final parts = teamName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final value = parts.first;
      return value.substring(0, math.min(3, value.length)).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
