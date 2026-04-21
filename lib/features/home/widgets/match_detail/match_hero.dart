part of '../../screens/match_detail_screen.dart';

class _MatchHero extends ConsumerWidget {
  const _MatchHero({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final innerSurface = isDark ? FzColors.darkSurface3 : FzColors.lightSurface;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final liveEvents = ref.watch(liveMatchEventsStreamProvider(match.id));
    final matchEvents = ref.watch(matchEventsProvider(match.id));
    final fallbackMinute = _resolveLiveMinute(
      liveEvents.valueOrNull,
      matchEvents.valueOrNull,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                width: 112,
                child: Column(
                  children: [
                    Text(
                      match.scoreDisplay ?? 'VS',
                      style: FzTypography.score(size: 40),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: match.isLive
                            ? FzColors.primary.withValues(alpha: 0.12)
                            : innerSurface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: match.isLive
                              ? FzColors.primary.withValues(alpha: 0.22)
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
                                color: FzColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _statusLabel(match, fallbackMinute),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: match.isLive ? FzColors.primary : muted,
                              letterSpacing: 0.8,
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

  int? _resolveLiveMinute(
    List<LiveMatchEvent>? liveEvents,
    List<MatchEventModel>? matchEvents,
  ) {
    final liveMinute = liveEvents
        ?.map((event) => event.minute)
        .whereType<int>()
        .fold<int?>(null, (best, minute) {
          if (minute <= 0) return best;
          if (best == null || minute > best) return minute;
          return best;
        });
    if (liveMinute != null) return liveMinute;

    return matchEvents
        ?.map((event) => event.minute)
        .where((minute) => minute > 0)
        .fold<int?>(null, (best, minute) {
          if (best == null || minute > best) return minute;
          return best;
        });
  }

  String _statusLabel(MatchModel match, int? fallbackMinute) {
    if (match.isLive) {
      return match.liveStatusLabel(fallbackMinute: fallbackMinute);
    }
    if (match.isFinished) return 'FULL TIME';
    return match.kickoffAtLocal != null
        ? match.kickoffTimeLocalLabel
        : 'SCHEDULED';
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
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
