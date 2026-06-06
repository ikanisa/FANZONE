import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../providers/auth_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../../games/data/games_repository.dart';
import '../data/pools_repository.dart';

export '../data/pools_repository.dart'
    show PoolCamp, PoolSummary, poolsProvider;

class PoolsScreen extends ConsumerStatefulWidget {
  const PoolsScreen({super.key});

  @override
  ConsumerState<PoolsScreen> createState() => _PoolsScreenState();
}

class _PoolsScreenState extends ConsumerState<PoolsScreen> {
  var _filter = _ArenaFilter.live;

  Future<void> _joinPool(PoolSummary pool, [PoolCamp? camp]) async {
    final isVerified = ref.read(isFullyAuthenticatedProvider);
    if (!isVerified) {
      await showSignInRequiredSheet(
        context,
        title: 'Verify WhatsApp',
        message: 'Unlock pools.',
        from: '/pools',
      );
      return;
    }

    final campQuery = camp == null
        ? ''
        : '?camp=${Uri.encodeComponent(camp.id)}';
    if (mounted) {
      await context.push('/pool/${pool.id}/join$campQuery');
    }
  }

  @override
  Widget build(BuildContext context) {
    final poolsAsync = ref.watch(poolsProvider);
    final pools = poolsAsync.valueOrNull ?? const <PoolSummary>[];
    final gamesAsync = ref.watch(gamesProvider);
    final games = gamesAsync.valueOrNull ?? const <GameSessionSummary>[];
    final joinedGameIdsAsync = ref.watch(myJoinedGameIdsProvider);
    final joinedGameIds = joinedGameIdsAsync.valueOrNull ?? const <String>{};
    final liveGameCount = games
        .where((game) => const {'lobby', 'live'}.contains(game.status))
        .length;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'create-pool',
        tooltip: 'Create pool',
        onPressed: () => context.push('/pools/create'),
        backgroundColor: FzColors.accent,
        foregroundColor: Colors.white,
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(poolsProvider);
            ref.invalidate(gamesProvider);
            ref.invalidate(myJoinedGameIdsProvider);
            await Future.wait([
              ref.read(poolsProvider.future),
              ref.read(gamesProvider.future),
              ref.read(myJoinedGameIdsProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 150),
            children: [
              _PlayHubHeader(
                openCount: pools
                    .where(
                      (pool) => const {'open', 'live'}.contains(pool.status),
                    )
                    .length,
                soonCount: pools
                    .where(
                      (pool) =>
                          const {'locked', 'settling'}.contains(pool.status),
                    )
                    .length,
                entryCount: pools.where((pool) => pool.hasMyEntry).length,
                liveGameCount: liveGameCount,
                onGames: () => context.go('/pools/games'),
                onCreate: () => context.push('/pools/create'),
              ),
              const SizedBox(height: 18),
              _GamePreviewSection(
                gamesAsync: gamesAsync,
                joinedIds: joinedGameIds,
                onViewAll: () => context.go('/pools/games'),
                onOpen: (game) => context.push('/game/${game.id}'),
              ),
              const SizedBox(height: 18),
              _PlaySectionHeader(
                title: 'Pools',
                actionLabel: 'Create',
                onAction: () => context.push('/pools/create'),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'Live',
                      filter: _ArenaFilter.live,
                      selected: _filter == _ArenaFilter.live,
                      onTap: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Soon',
                      filter: _ArenaFilter.soon,
                      selected: _filter == _ArenaFilter.soon,
                      onTap: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Top Rewards',
                      filter: _ArenaFilter.bigPool,
                      selected: _filter == _ArenaFilter.bigPool,
                      onTap: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Entries',
                      filter: _ArenaFilter.entries,
                      selected: _filter == _ArenaFilter.entries,
                      onTap: _setFilter,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              poolsAsync.when(
                data: (pools) {
                  final visible = _applyFilter(pools);
                  if (visible.isEmpty) {
                    return FzEmptyState(
                      title: _emptyTitle,
                      description: _emptyDescription,
                      icon: const Icon(LucideIcons.trophy),
                      actionLabel: _filter == _ArenaFilter.entries
                          ? 'Pools'
                          : 'Create',
                      onAction: _filter == _ArenaFilter.entries
                          ? () => _setFilter(_ArenaFilter.live)
                          : () => context.push('/pools/create'),
                    );
                  }
                  return Column(
                    children: [
                      for (final pool in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ArenaPoolCard(
                            pool: pool,
                            onOpen: () => context.push('/pool/${pool.id}'),
                            onJoin: (camp) => _joinPool(pool, camp),
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
                  title: 'Arena unavailable',
                  subtitle: 'Pools are unavailable right now. Try again.',
                  onRetry: () => ref.invalidate(poolsProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setFilter(_ArenaFilter filter) => setState(() => _filter = filter);

  List<PoolSummary> _applyFilter(List<PoolSummary> pools) {
    switch (_filter) {
      case _ArenaFilter.live:
        return pools
            .where((pool) => const {'open', 'live'}.contains(pool.status))
            .toList(growable: false);
      case _ArenaFilter.soon:
        return pools
            .where((pool) => const {'locked', 'settling'}.contains(pool.status))
            .toList(growable: false);
      case _ArenaFilter.bigPool:
        final sorted = [...pools]
          ..sort((a, b) => b.totalStakedFet.compareTo(a.totalStakedFet));
        return sorted.take(20).toList(growable: false);
      case _ArenaFilter.entries:
        return pools.where((pool) => pool.hasMyEntry).toList(growable: false);
    }
  }

  String get _emptyTitle {
    switch (_filter) {
      case _ArenaFilter.entries:
        return 'No entries';
      case _ArenaFilter.soon:
        return 'No rooms';
      default:
        return 'No pools';
    }
  }

  String get _emptyDescription {
    switch (_filter) {
      case _ArenaFilter.entries:
        return 'Join one.';
      case _ArenaFilter.soon:
        return 'Check soon.';
      default:
        return 'Create one.';
    }
  }
}

enum _ArenaFilter { live, soon, bigPool, entries }

class _PlayHubHeader extends StatelessWidget {
  const _PlayHubHeader({
    required this.openCount,
    required this.soonCount,
    required this.entryCount,
    required this.liveGameCount,
    required this.onGames,
    required this.onCreate,
  });

  final int openCount;
  final int soonCount;
  final int entryCount;
  final int liveGameCount;
  final VoidCallback onGames;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: FzColors.darkSurface,
        borderRadius: FzRadii.heroRadius,
        border: Border.all(color: FzColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: FzColors.orange.withValues(alpha: 0.14),
                  borderRadius: FzRadii.buttonRadius,
                ),
                child: const Icon(
                  LucideIcons.swords,
                  color: FzColors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLAY',
                      style: FzTypography.sportsTitle(
                        size: 38,
                        color: FzColors.darkText,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Pools, live games, and match-day rooms.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: FzColors.darkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PlayMetricTile(
                  label: 'Open',
                  value: openCount,
                  color: FzColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlayMetricTile(
                  label: 'Games',
                  value: liveGameCount,
                  color: FzColors.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlayMetricTile(
                  label: 'Entries',
                  value: entryCount,
                  color: FzColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGames,
                  icon: const Icon(LucideIcons.gamepad2, size: 16),
                  label: const Text('Games'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaySectionHeader extends StatelessWidget {
  const _PlaySectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: FzColors.darkText,
            ),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _GamePreviewSection extends StatelessWidget {
  const _GamePreviewSection({
    required this.gamesAsync,
    required this.joinedIds,
    required this.onViewAll,
    required this.onOpen,
  });

  final AsyncValue<List<GameSessionSummary>> gamesAsync;
  final Set<String> joinedIds;
  final VoidCallback onViewAll;
  final ValueChanged<GameSessionSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    return gamesAsync.when(
      data: (games) {
        final visible = _visibleGames(games);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlaySectionHeader(
              title: 'Live games',
              actionLabel: 'View all',
              onAction: onViewAll,
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              FzEmptyState(
                title: 'No live games',
                description: 'Scheduled bar games will appear here.',
                icon: const Icon(LucideIcons.gamepad2),
                actionLabel: 'Games',
                onAction: onViewAll,
              )
            else
              for (final game in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GamePreviewCard(
                    game: game,
                    isJoined: joinedIds.contains(game.id),
                    onTap: () => onOpen(game),
                  ),
                ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlaySectionHeader(
            title: 'Live games',
            actionLabel: 'View all',
            onAction: onViewAll,
          ),
          const SizedBox(height: 12),
          const _PlayLoadingPanel(label: 'Loading games'),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlaySectionHeader(
            title: 'Live games',
            actionLabel: 'View all',
            onAction: onViewAll,
          ),
          const SizedBox(height: 12),
          FzEmptyState(
            title: 'Games unavailable',
            description: 'Open the games page to retry.',
            icon: const Icon(LucideIcons.gamepad2),
            actionLabel: 'Games',
            onAction: onViewAll,
          ),
        ],
      ),
    );
  }

  static List<GameSessionSummary> _visibleGames(
    List<GameSessionSummary> games,
  ) {
    final ordered = [...games]
      ..sort((a, b) {
        final statusCompare = _statusRank(
          a.status,
        ).compareTo(_statusRank(b.status));
        if (statusCompare != 0) return statusCompare;
        return a.scheduledStartAt.compareTo(b.scheduledStartAt);
      });
    return ordered
        .where(
          (game) => const {'lobby', 'live', 'scheduled'}.contains(game.status),
        )
        .take(3)
        .toList(growable: false);
  }

  static int _statusRank(String status) => switch (status) {
    'live' => 0,
    'lobby' => 1,
    'scheduled' => 2,
    _ => 3,
  };
}

class _GamePreviewCard extends StatelessWidget {
  const _GamePreviewCard({
    required this.game,
    required this.isJoined,
    required this.onTap,
  });

  final GameSessionSummary game;
  final bool isJoined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (game.status) {
      'live' => FzColors.green,
      'lobby' => FzColors.cyan,
      'scheduled' => FzColors.gold,
      _ => FzColors.darkMuted,
    };

    return FzCard(
      key: ValueKey('play_game_preview_${game.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.card,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: FzRadii.compactRadius,
            ),
            child: Icon(_gameIcon(game), color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.templateName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  game.venueName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FzColors.darkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                game.status.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${game.rewardFet} FET',
                style: const TextStyle(
                  color: FzColors.darkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (isJoined) ...[
                const SizedBox(height: 4),
                const Text(
                  'JOINED',
                  style: TextStyle(
                    color: FzColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData _gameIcon(GameSessionSummary game) {
    if (game.templateId == 'music_bingo') return LucideIcons.grid3x3;
    if (game.templateId == 'song_guess') return LucideIcons.music;
    return LucideIcons.helpCircle;
  }
}

class _PlayLoadingPanel extends StatelessWidget {
  const _PlayLoadingPanel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FzColors.darkSurface,
        borderRadius: FzRadii.cardRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayMetricTile extends StatelessWidget {
  const _PlayMetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: FzRadii.cardRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: FzTypography.score(size: 20, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
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
  final _ArenaFilter filter;
  final bool selected;
  final ValueChanged<_ArenaFilter> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FzPill(
        label: label,
        selected: selected,
        onTap: () => onTap(filter),
      ),
    );
  }
}

class _ArenaPoolCard extends StatelessWidget {
  const _ArenaPoolCard({
    required this.pool,
    required this.onOpen,
    required this.onJoin,
  });

  final PoolSummary pool;
  final VoidCallback onOpen;
  final ValueChanged<PoolCamp?> onJoin;

  @override
  Widget build(BuildContext context) {
    final primaryCamp = pool.camps.isEmpty ? null : pool.camps.first;
    final secondaryCamp = pool.camps.length < 2 ? null : pool.camps[1];

    return FzCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(18),
      borderRadius: FzRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FzPill(
                label: pool.status.toUpperCase(),
                icon: pool.isOpen ? LucideIcons.zap : LucideIcons.clock,
                color: pool.isOpen ? FzColors.green : FzColors.gold,
                selected: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _CampOrb(label: primaryCamp?.label ?? 'HOME'),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      pool.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: FzTypography.display(
                        size: 23,
                        color: FzColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pool.venueName == null ? 'Bar needed' : pool.venueName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FzColors.darkMuted,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _CampOrb(label: secondaryCamp?.label ?? 'AWAY'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FzMetricTile(
                  label: 'Entry points',
                  value: '${pool.defaultStakeFet} FET',
                  color: FzColors.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FzMetricTile(
                  label: 'Reward pool',
                  value: '${pool.totalStakedFet} FET',
                  color: FzColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FzMetricTile(
                  label: 'Entries',
                  value: '${pool.totalMembers}',
                  color: FzColors.gold,
                ),
              ),
            ],
          ),
          if (pool.camps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final camp in pool.camps.take(3))
                  FzPill(
                    label: camp.label,
                    icon: LucideIcons.users,
                    onTap: pool.isOpen ? () => onJoin(camp) : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: ValueKey('pool_join_${pool.id}'),
              onPressed: pool.isOpen ? () => onJoin(primaryCamp) : null,
              icon: const Icon(LucideIcons.trophy, size: 16),
              label: const Text('Join'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampOrb extends StatelessWidget {
  const _CampOrb({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final initials = label
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        shape: BoxShape.circle,
        border: Border.all(color: FzColors.darkBorder),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? 'FC' : initials,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }
}
