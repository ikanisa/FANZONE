import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';
import '../data/games_repository.dart';

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  var _filter = _GameFilter.active;

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gamesProvider);
    final joinedAsync = ref.watch(myJoinedGameIdsProvider);
    final joinedIds = joinedAsync.valueOrNull ?? const <String>{};

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(gamesProvider);
            ref.invalidate(myJoinedGameIdsProvider);
            await ref.read(gamesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 150),
            children: [
              const FzReferenceHeader(title: 'FZ'),
              const SizedBox(height: 24),
              Text(
                'GAMES',
                style: FzTypography.sportsTitle(size: 42, color: FzColors.darkText),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bar games. FET.',
                style: TextStyle(
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(LucideIcons.gamepad2, size: 16),
                      label: const Text('Games'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/pools'),
                      icon: const Icon(LucideIcons.trophy, size: 16),
                      label: const Text('Pools'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'Active',
                      filter: _GameFilter.active,
                      selected: _filter == _GameFilter.active,
                      onTap: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Soon',
                      filter: _GameFilter.upcoming,
                      selected: _filter == _GameFilter.upcoming,
                      onTap: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Joined',
                      filter: _GameFilter.joined,
                      selected: _filter == _GameFilter.joined,
                      onTap: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Bars',
                      filter: _GameFilter.byBar,
                      selected: _filter == _GameFilter.byBar,
                      onTap: _setFilter,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              gamesAsync.when(
                data: (games) {
                  final visible = _applyFilter(games, joinedIds);
                  if (visible.isEmpty) {
                    return FzEmptyState(
                      title: 'No games',
                      description: _emptyDescription,
                      icon: const Icon(LucideIcons.gamepad2),
                      actionLabel: _filter == _GameFilter.joined
                          ? 'Games'
                          : 'Refresh',
                      onAction: _filter == _GameFilter.joined
                          ? () => _setFilter(_GameFilter.active)
                          : () => ref.invalidate(gamesProvider),
                    );
                  }
                  return Column(
                    children: [
                      for (final game in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _GameCard(
                            game: game,
                            joined: joinedIds.contains(game.id),
                            onOpen: () => context.push('/game/${game.id}'),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => StateView.error(
                  title: 'Games unavailable',
                  subtitle: error.toString(),
                  onRetry: () => ref.invalidate(gamesProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setFilter(_GameFilter filter) => setState(() => _filter = filter);

  List<GameSessionSummary> _applyFilter(
    List<GameSessionSummary> games,
    Set<String> joinedIds,
  ) {
    switch (_filter) {
      case _GameFilter.active:
        return games
            .where((game) => const {'lobby', 'live'}.contains(game.status))
            .toList(growable: false);
      case _GameFilter.upcoming:
        return games
            .where((game) => game.status == 'scheduled')
            .toList(growable: false);
      case _GameFilter.joined:
        return games
            .where((game) => joinedIds.contains(game.id))
            .toList(growable: false);
      case _GameFilter.byBar:
        final sorted = [...games]
          ..sort((a, b) => a.venueName.compareTo(b.venueName));
        return sorted;
    }
  }

  String get _emptyDescription {
    switch (_filter) {
      case _GameFilter.active:
        return 'Check live.';
      case _GameFilter.upcoming:
        return 'Check soon.';
      case _GameFilter.joined:
        return 'Join team.';
      case _GameFilter.byBar:
        return 'Pick bar.';
    }
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.joined,
    required this.onOpen,
  });

  final GameSessionSummary game;
  final bool joined;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FzColors.accent.withValues(alpha: 0.12),
                  borderRadius: FzRadii.compactRadius,
                ),
                child: Icon(_iconFor(game), color: FzColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.templateName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      game.venueName,
                      style: const TextStyle(
                        color: FzColors.darkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: game.status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(
                icon: LucideIcons.coins,
                label: '${game.rewardFet} FET',
              ),
              _MetaPill(
                icon: LucideIcons.clock,
                label: _timeLabel(game.scheduledStartAt),
              ),
              if (game.usesQuestions)
                _MetaPill(
                  icon: LucideIcons.listChecks,
                  label: '${game.selectedQuestionCount}/20',
                ),
              if (joined)
                const _MetaPill(icon: LucideIcons.badgeCheck, label: 'Joined'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final _GameFilter filter;
  final bool selected;
  final ValueChanged<_GameFilter> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(filter),
        selectedColor: FzColors.accent.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: selected ? FzColors.accent : FzColors.darkMuted,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'live' => FzColors.green,
      'lobby' => FzColors.cyan,
      'settled' => FzColors.accent2,
      'ended' => FzColors.warning,
      _ => FzColors.darkMuted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: FzRadii.fullRadius,
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FzColors.darkMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum _GameFilter { active, upcoming, joined, byBar }

IconData _iconFor(GameSessionSummary game) {
  if (game.templateId == 'music_bingo') return LucideIcons.layoutGrid;
  if (game.templateId == 'song_guess') return LucideIcons.music;
  return LucideIcons.helpCircle;
}

String _timeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} $hour:$minute';
}
