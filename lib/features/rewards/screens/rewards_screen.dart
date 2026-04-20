import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/media/cdn_url_resolver.dart';
import '../../../core/media/fz_image_cache_manager.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../models/marketplace_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../services/marketplace_service.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/fz_glass_loader.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(marketplaceOffersProvider);
    final redemptionsAsync = ref.watch(marketplaceRedemptionsProvider);
    final balanceAsync = ref.watch(walletServiceProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'REWARDS',
          style: FzTypography.display(size: 28, color: textColor),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(marketplaceOffersProvider);
          ref.invalidate(marketplaceRedemptionsProvider);
          ref.invalidate(walletServiceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FzCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: FzColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.gift, color: FzColors.amber),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Redeem your FET with local partners',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use fan engagement tokens on rewards, experiences, and exclusive offers.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  balanceAsync.when(
                    data: (balance) =>
                        _BalancePill(balance: balance, currencyCode: currency),
                    loading: () => const _BalancePill(balanceLabel: '...'),
                    error: (_, _) => const _BalancePill(balanceLabel: '—'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'AVAILABLE NOW',
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 10),
            offersAsync.when(
              data: (offers) {
                if (offers.isEmpty) {
                  return StateView.empty(
                    title: 'No rewards live',
                    subtitle: 'New partner offers will show up here.',
                    icon: LucideIcons.gift,
                  );
                }

                return Column(
                  children: offers
                      .map(
                        (offer) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OfferCard(
                            offer: offer,
                            currencyCode: currency,
                            canRedeem: isAuthenticated,
                            onRedeem: () => _redeem(context, ref, offer),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: FzGlassLoader(message: 'Syncing...'),
              ),
              error: (_, _) => StateView.error(
                title: 'Could not load rewards',
                subtitle: 'Try again in a moment.',
                onRetry: () => ref.invalidate(marketplaceOffersProvider),
              ),
            ),
            if (isAuthenticated) ...[
              const SizedBox(height: 20),
              Text(
                'MY REDEMPTIONS',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 10),
              redemptionsAsync.when(
                data: (redemptions) {
                  if (redemptions.isEmpty) {
                    return FzCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Your reward history will appear here once you redeem an offer.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    );
                  }
                  return Column(
                    children: redemptions
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RedemptionCard(
                              item: item,
                              currencyCode: currency,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: FzGlassLoader(message: 'Syncing...'),
                ),
                error: (_, _) => StateView.error(
                  title: 'Could not load redemption history',
                  subtitle: 'Pull to refresh and try again.',
                  onRetry: () => ref.invalidate(marketplaceRedemptionsProvider),
                ),
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> _redeem(
    BuildContext context,
    WidgetRef ref,
    MarketplaceOffer offer,
  ) async {
    final currency = ref.read(userCurrencyProvider).valueOrNull ?? 'EUR';
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Redeem ${offer.title}?'),
        content: Text(
          'This will spend ${formatFET(offer.costFet, currency)} on ${offer.partnerName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final result = await ref
          .read(marketplaceServiceProvider)
          .redeemOffer(offer.id);

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reward ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${offer.title} from ${offer.partnerName} is ready.'),
              if ((result.deliveryValue ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Code',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  result.deliveryValue!,
                  style: FzTypography.scoreMedium(color: FzColors.primary),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Balance after redemption: ${formatFET(result.balanceAfter, currency)}',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({this.balance, this.balanceLabel, this.currencyCode});

  final int? balance;
  final String? balanceLabel;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final label =
        balanceLabel ?? formatFET(balance ?? 0, currencyCode ?? 'EUR');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FzColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: FzColors.amber,
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.currencyCode,
    required this.canRedeem,
    required this.onRedeem,
  });

  final MarketplaceOffer offer;
  final String currencyCode;
  final bool canRedeem;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FzColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    offer.partnerLogoUrl != null &&
                        offer.partnerLogoUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: CdnUrlResolver.resolveImageUrl(
                            offer.partnerLogoUrl!,
                            width: 88,
                          ),
                          cacheManager: FzImageCacheManager.instance,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const Icon(
                            LucideIcons.store,
                            color: FzColors.primary,
                          ),
                        ),
                      )
                    : const Icon(LucideIcons.store, color: FzColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      offer.partnerName,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              _BalancePill(
                balanceLabel: formatFET(offer.costFet, currencyCode),
              ),
            ],
          ),
          if ((offer.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              offer.description!,
              style: TextStyle(fontSize: 12, color: muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: offer.deliveryType.toUpperCase()),
              if ((offer.originalValue ?? '').isNotEmpty)
                _MetaChip(label: offer.originalValue!),
              if (offer.stock != null) _MetaChip(label: '${offer.stock} left'),
              if (offer.validUntil != null)
                _MetaChip(
                  label:
                      'Valid until ${offer.validUntil!.day}/${offer.validUntil!.month}',
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canRedeem ? onRedeem : null,
              icon: const Icon(LucideIcons.gift, size: 16),
              label: Text(canRedeem ? 'Redeem reward' : 'Sign in to redeem'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({required this.item, required this.currencyCode});

  final MarketplaceRedemption item;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final statusColor = switch (item.status) {
      'fulfilled' => FzColors.success,
      'used' => FzColors.primary,
      'expired' => FzColors.error,
      _ => FzColors.amber,
    };

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.partnerName,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${formatFET(item.costFet, currencyCode)} • ${item.deliveryType.toUpperCase()} • ${item.redeemedAt.day}/${item.redeemedAt.month}/${item.redeemedAt.year}',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          if ((item.deliveryValue ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              item.deliveryValue!,
              style: FzTypography.scoreCompact(color: FzColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? FzColors.darkText : FzColors.lightText,
        ),
      ),
    );
  }
}
