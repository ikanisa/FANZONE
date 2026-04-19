part of '../../screens/match_detail_screen.dart';

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    required this.match,
    required this.relatedMatchesAsync,
    required this.competitionName,
  });

  final MatchModel match;
  final AsyncValue<List<MatchModel>> relatedMatchesAsync;
  final String competitionName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final dateLabel = DateFormat('dd MMM yyyy').format(match.date);
    final factValues = <({String label, String value})>[
      (label: 'Competition', value: competitionName),
      (label: 'Round', value: match.round ?? 'Fixture'),
      (label: 'Date', value: dateLabel),
      (label: 'Kickoff', value: match.kickoffTime ?? '--:--'),
      (label: 'Venue', value: match.venue ?? 'TBC'),
      (label: 'Status', value: match.kickoffLabel),
    ];

    final liveEventsAsync = ref.watch(liveMatchEventsStreamProvider(match.id));
    final liveEvents = liveEventsAsync.valueOrNull ?? [];

    // Build event timeline from realtime stream or fallback to basic score data
    final events = <_MatchEvent>[];

    if (liveEvents.isNotEmpty) {
      for (final ev in liveEvents.reversed) {
        events.add(
          _MatchEvent(
            minute: ev.minute != null ? '${ev.minute}\'' : '--',
            description: ev.eventType == 'GOAL'
                ? 'Goal'
                : (ev.eventType == 'YELLOW_CARD'
                      ? 'Yellow Card'
                      : (ev.eventType == 'RED_CARD' ? 'Red Card' : 'Sub')),
            icon: ev.eventType == 'GOAL'
                ? Icons.sports_soccer_rounded
                : (ev.eventType == 'SUBSTITUTION'
                      ? Icons.sync_rounded
                      : Icons.style_rounded),
            isHome: ev.team == match.homeTeam,
            color: ev.eventType == 'RED_CARD'
                ? Colors.red
                : (ev.eventType == 'YELLOW_CARD'
                      ? Colors.amber
                      : (isDark ? Colors.white : Colors.black87)),
          ),
        );
      }
    } else {
      if (match.htHome != null && match.htAway != null) {
        for (var i = 0; i < match.htHome!; i++) {
          events.add(
            _MatchEvent(
              minute: '${15 + (i * 10)}\'',
              description: 'Goal',
              icon: Icons.sports_soccer_rounded,
              isHome: true,
              color: FzColors.accent,
            ),
          );
        }
        for (var i = 0; i < match.htAway!; i++) {
          events.add(
            _MatchEvent(
              minute: '${20 + (i * 10)}\'',
              description: 'Goal',
              icon: Icons.sports_soccer_rounded,
              isHome: false,
              color: FzColors.accent,
            ),
          );
        }
        events.add(
          _MatchEvent(
            minute: 'HT',
            description: '${match.htHome} - ${match.htAway}',
            icon: Icons.access_time_rounded,
            isHome: true,
            color: muted,
          ),
        );
      }
      if (match.ftHome != null && match.ftAway != null) {
        final secondHalfHome = match.ftHome! - (match.htHome ?? 0);
        final secondHalfAway = match.ftAway! - (match.htAway ?? 0);
        for (var i = 0; i < secondHalfHome; i++) {
          events.add(
            _MatchEvent(
              minute: '${55 + (i * 10)}\'',
              description: 'Goal',
              icon: Icons.sports_soccer_rounded,
              isHome: true,
              color: FzColors.accent,
            ),
          );
        }
        for (var i = 0; i < secondHalfAway; i++) {
          events.add(
            _MatchEvent(
              minute: '${60 + (i * 10)}\'',
              description: 'Goal',
              icon: Icons.sports_soccer_rounded,
              isHome: false,
              color: FzColors.accent,
            ),
          );
        }
        events.add(
          _MatchEvent(
            minute: 'FT',
            description: '${match.ftHome} - ${match.ftAway}',
            icon: Icons.flag_rounded,
            isHome: true,
            color: muted,
          ),
        );
      }
    }

    // AI Analysis — show before kickoff
    final aiAnalysisAsync = ref.watch(matchAiAnalysisProvider(match.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── AI Pre-Match Analysis Card ──
        if (match.isUpcoming || match.isLive)
          aiAnalysisAsync.when(
            data: (analysis) {
              if (analysis == null || !analysis.isValid) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _AiAnalysisCard(analysis: analysis, match: match),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),

        // Event timeline (M1)
        if (events.isNotEmpty) ...[
          Text(
            'Events',
            style: FzTypography.sectionLabel(Theme.of(context).brightness),
          ),
          const SizedBox(height: 10),
          FzCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: events.asMap().entries.map((entry) {
                final event = entry.value;
                final isLast = entry.key == events.length - 1;
                return _EventTimelineRow(
                  event: event,
                  homeTeam: match.homeTeam,
                  awayTeam: match.awayTeam,
                  isLast: isLast,
                  isDark: isDark,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
        ],
        MatchFactsGrid(facts: factValues),
        const SizedBox(height: 18),
        Text(
          'Related',
          style: FzTypography.sectionLabel(Theme.of(context).brightness),
        ),
        const SizedBox(height: 10),
        relatedMatchesAsync.when(
          data: (matches) {
            final related = matches
                .where((item) => item.id != match.id)
                .take(5)
                .toList();
            if (related.isEmpty) {
              return FzCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No related fixtures.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
                  ),
                ),
              );
            }
            return Column(
              children: related
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FzCard(
                        padding: EdgeInsets.zero,
                        child: MatchListRow(
                          match: item,
                          onTap: () => context.push('/match/${item.id}'),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const FzCard(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stackTrace) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _MatchEvent {
  final String minute;
  final String description;
  final IconData icon;
  final bool isHome;
  final Color color;

  const _MatchEvent({
    required this.minute,
    required this.description,
    required this.icon,
    required this.isHome,
    required this.color,
  });
}

class _EventTimelineRow extends StatelessWidget {
  const _EventTimelineRow({
    required this.event,
    required this.homeTeam,
    required this.awayTeam,
    required this.isLast,
    required this.isDark,
  });

  final _MatchEvent event;
  final String homeTeam;
  final String awayTeam;
  final bool isLast;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              event.minute,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: event.color,
                fontFamily: 'JetBrains Mono',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: event.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(event.icon, size: 14, color: event.color),
                    const SizedBox(width: 6),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? FzColors.darkText : FzColors.lightText,
                      ),
                    ),
                  ],
                ),
                if (event.description == 'Goal')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      event.isHome ? homeTeam : awayTeam,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
