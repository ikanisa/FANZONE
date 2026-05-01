import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/sports/match_model.dart';
import '../../../providers/home_feed_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../ordering/providers/cart_provider.dart';
import '../../ordering/providers/venue_context_provider.dart';
import '../../pools/data/pools_repository.dart';

class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  static const _feedWindowDays = 7;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueContext = ref.watch(venueContextProvider);
    final feedFilter = MatchesFilter(
      dateFrom: _today.toIso8601String(),
      dateTo: _today
          .add(const Duration(days: _feedWindowDays))
          .toIso8601String(),
      countryCode: venueContext.venue?.countryCode.name.toUpperCase(),
      venueId: venueContext.venueId,
      ascending: true,
    );
    final matchesAsync = ref.watch(homeFeedMatchesProvider(feedFilter));
    final poolsAsync = ref.watch(poolsProvider);
    final walletAsync = ref.watch(walletBalanceProvider);
    final cart = ref.watch(cartProvider);
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: FzColors.primary,
          onRefresh: () async {
            ref.invalidate(homeFeedMatchesProvider(feedFilter));
            ref.invalidate(poolsProvider);
            ref.invalidate(walletBalanceProvider);
            await Future.wait([
              ref.read(homeFeedMatchesProvider(feedFilter).future),
              ref.read(poolsProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Today',
                      style: FzTypography.display(
                        size: 40,
                        color: textColor,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  walletAsync.when(
                    data: (wallet) => _WalletChip(
                      amount: wallet.availableFet,
                      onTap: () => context.go('/wallet'),
                    ),
                    loading: () => const _WalletChip(amount: 0),
                    error: (_, _) => _WalletChip(
                      amount: 0,
                      onTap: () => context.go('/wallet'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TodayHero(
                venueName: venueContext.venue?.name,
                tableNumber:
                    venueContext.table?.tableNumber.toString() ??
                    venueContext.tableNumber,
                cartCount: cart.totalItemCount,
                onOrder: () => context.go('/bar'),
                onJoinPool: () => context.go('/pools'),
                onCreatePool: () => context.push('/pools/create'),
              ),
              const SizedBox(height: 16),
              _QuickActions(
                onOrder: () => context.go('/bar'),
                onJoinPool: () => context.go('/pools'),
                onCreatePool: () => context.push('/pools/create'),
              ),
              const SizedBox(height: 22),
              const _SectionTitle(
                icon: LucideIcons.flame,
                title: 'Featured matches',
              ),
              const SizedBox(height: 10),
              matchesAsync.when(
                data: (selection) {
                  final matches = [
                    ...selection.liveMatches,
                    ...selection.upcomingMatches,
                  ].take(4).toList(growable: false);

                  if (matches.isEmpty) {
                    return FzEmptyState(
                      title: 'No featured matches',
                      description:
                          'Featured match pools appear here when matches are curated for today.',
                      icon: const Icon(LucideIcons.calendar),
                      actionLabel: 'Open Pools',
                      onAction: () => context.go('/pools'),
                    );
                  }

                  return Column(
                    children: [
                      for (final match in matches)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MatchCard(
                            match: match,
                            onOpenMatch: () =>
                                context.push('/match/${match.id}'),
                            onOpenPools: () => context.go('/pools'),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => StateView.error(
                  title: 'Could not load matches',
                  subtitle: error.toString(),
                  onRetry: () =>
                      ref.invalidate(homeFeedMatchesProvider(feedFilter)),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle(
                icon: LucideIcons.trophy,
                title: 'Active pools',
              ),
              const SizedBox(height: 10),
              poolsAsync.when(
                data: (pools) {
                  final openPools = pools
                      .where((pool) => pool.status == 'open')
                      .take(3)
                      .toList(growable: false);
                  if (openPools.isEmpty) {
                    return FzEmptyState(
                      title: 'No open pools',
                      description:
                          'Create a pool or check back when featured matches open for staking.',
                      icon: const Icon(LucideIcons.trophy),
                      actionLabel: 'Create Pool',
                      onAction: () => context.push('/pools/create'),
                    );
                  }
                  return Column(
                    children: [
                      for (final pool in openPools)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PoolPreviewCard(
                            pool: pool,
                            onTap: () => context.push('/pool/${pool.id}'),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => FzEmptyState(
                  title: 'Pools unavailable',
                  description: 'Pull to refresh before joining a match pool.',
                  icon: const Icon(LucideIcons.alertCircle),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(poolsProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({
    required this.venueName,
    required this.tableNumber,
    required this.cartCount,
    required this.onOrder,
    required this.onJoinPool,
    required this.onCreatePool,
  });

  final String? venueName;
  final String? tableNumber;
  final int cartCount;
  final VoidCallback onOrder;
  final VoidCallback onJoinPool;
  final VoidCallback onCreatePool;

  @override
  Widget build(BuildContext context) {
    final hasVenue = venueName != null && venueName!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.darkSurface, FzColors.teal, FzColors.accent2],
          stops: [0, 0.55, 1],
        ),
        borderRadius: FzRadii.heroRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: FzColors.accent2.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasVenue ? LucideIcons.mapPin : LucideIcons.qrCode,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasVenue ? 'CURRENT BAR' : 'SCAN A TABLE QR',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (cartCount > 0)
                FzBadge(
                  label: '$cartCount in cart',
                  variant: FzBadgeVariant.success,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasVenue ? venueName! : 'Sports bar mode',
            style: FzTypography.display(
              size: 34,
              color: Colors.white,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasVenue && tableNumber != null
                ? 'Table $tableNumber ready for menu, pools, and FET rewards.'
                : 'Order at the bar, join match pools, and track FET from one place.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroButton(
                  label: 'Order',
                  icon: LucideIcons.utensils,
                  background: Colors.white,
                  foreground: FzColors.darkBg,
                  onTap: onOrder,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroButton(
                  label: 'Join Pool',
                  icon: LucideIcons.trophy,
                  background: FzColors.darkBg.withValues(alpha: 0.72),
                  foreground: Colors.white,
                  onTap: onJoinPool,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOrder,
    required this.onJoinPool,
    required this.onCreatePool,
  });

  final VoidCallback onOrder;
  final VoidCallback onJoinPool;
  final VoidCallback onCreatePool;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            label: 'Order',
            icon: LucideIcons.shoppingCart,
            color: FzColors.accent,
            onTap: onOrder,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            label: 'Join',
            icon: LucideIcons.trophy,
            color: FzColors.accent2,
            onTap: onJoinPool,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            label: 'Create',
            icon: LucideIcons.plus,
            color: FzColors.accent3,
            onTap: onCreatePool,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      borderRadius: FzRadii.compact,
      color: FzColors.darkSurface2,
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _WalletChip extends StatelessWidget {
  const _WalletChip({required this.amount, this.onTap});

  final int amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: FzRadii.fullRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FzColors.darkSurface2,
          borderRadius: FzRadii.fullRadius,
          border: Border.all(color: FzColors.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.wallet, size: 15, color: FzColors.accent),
            const SizedBox(width: 6),
            Text(
              '$amount FET',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.onOpenMatch,
    required this.onOpenPools,
  });

  final MatchModel match;
  final VoidCallback onOpenMatch;
  final VoidCallback onOpenPools;

  @override
  Widget build(BuildContext context) {
    final scoreText = match.isLive ? (match.scoreDisplay ?? 'LIVE') : 'VS';

    return FzCard(
      onTap: onOpenMatch,
      padding: const EdgeInsets.all(14),
      borderRadius: FzRadii.compact,
      borderColor: match.isLive
          ? FzColors.danger.withValues(alpha: 0.35)
          : FzColors.darkBorder,
      child: Column(
        children: [
          Row(
            children: [
              FzBadge(
                label: match.isLive
                    ? match.liveStatusLabel()
                    : match.kickoffTimeLocalLabel,
                variant: match.isLive
                    ? FzBadgeVariant.danger
                    : FzBadgeVariant.ghost,
              ),
              const Spacer(),
              Text(
                match.competitionName ?? match.competitionId.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TeamColumn(
                  name: match.homeTeam,
                  logoUrl: match.homeLogoUrl,
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  scoreText,
                  textAlign: TextAlign.center,
                  style: FzTypography.scoreLarge(
                    color: match.isLive ? FzColors.danger : FzColors.darkText,
                  ),
                ),
              ),
              Expanded(
                child: _TeamColumn(
                  name: match.awayTeam,
                  logoUrl: match.awayLogoUrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenPools,
              icon: const Icon(LucideIcons.trophy, size: 16),
              label: const Text('Join Pool'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.name, required this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeamAvatar(name: name, logoUrl: logoUrl, size: 42),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _PoolPreviewCard extends StatelessWidget {
  const _PoolPreviewCard({required this.pool, required this.onTap});

  final PoolSummary pool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: FzRadii.compact,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FzColors.accent2.withValues(alpha: 0.12),
              borderRadius: FzRadii.buttonRadius,
            ),
            child: const Icon(LucideIcons.trophy, color: FzColors.accent2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pool.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${pool.scope} - ${pool.totalMembers} members - ${pool.totalStakedFet} FET',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: FzColors.darkMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 18),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: FzRadii.compactRadius,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: background,
          borderRadius: FzRadii.compactRadius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: FzColors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
