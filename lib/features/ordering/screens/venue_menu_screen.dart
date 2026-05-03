import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/hospitality/menu_category_model.dart';
import '../../../models/hospitality/menu_item_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/venue_context_provider.dart';

class VenueMenuScreen extends ConsumerWidget {
  const VenueMenuScreen({super.key, this.venueSlug});

  final String? venueSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueContext = ref.watch(venueContextProvider);
    final cart = ref.watch(cartProvider);

    if (venueSlug != null &&
        (!venueContext.hasVenue || venueContext.venue?.slug != venueSlug)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: venueContext.hasVenue
            ? _BarContent(cart: cart)
            : const _NoVenueState(),
      ),
      floatingActionButton: cart.isNotEmpty ? _CartPill(cart: cart) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _NoVenueState extends StatelessWidget {
  const _NoVenueState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
      children: [
        const FzReferenceHeader(title: 'Sports Elite'),
        const SizedBox(height: 24),
        FzEmptyState(
          title: 'Scan a table QR',
          description:
              'Your venue, table, menu, cart, payment guidance, and FET rewards appear here as soon as you scan or select a FANZONE bar.',
          icon: const Icon(LucideIcons.qrCode),
          actionLabel: 'Browse Venues',
          onAction: () => context.go('/venues'),
        ),
      ],
    );
  }
}

class _BarContent extends ConsumerWidget {
  const _BarContent({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(groupedMenuProvider);

    return RefreshIndicator(
      color: FzColors.primary,
      onRefresh: () async {
        ref.invalidate(groupedMenuProvider);
        ref.invalidate(activeOrdersProvider);
        await ref.read(groupedMenuProvider.future);
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: FzReferenceHeader(title: 'Sports Elite'),
                    ),
                    IconButton(
                      tooltip: 'Leave venue',
                      onPressed: () {
                        ref.read(venueContextProvider.notifier).clear();
                        ref.read(cartProvider.notifier).clear();
                        context.go('/venues');
                      },
                      icon: const Icon(LucideIcons.logOut, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Order to Play',
                  style: FzTypography.display(
                    size: 38,
                    color: FzColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Order at the bar, earn FET after staff confirmation, and unlock the Arena.',
                  style: TextStyle(
                    color: FzColors.darkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _VenueContextCard(cart: cart),
                const SizedBox(height: 12),
                const _PaymentGuidanceCard(),
                const SizedBox(height: 18),
                const _SectionTitle(title: 'Menu'),
              ],
            ),
          ),
          menuAsync.when(
            data: (menu) {
              if (menu.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: StateView.empty(
                    title: 'Menu unavailable',
                    subtitle:
                        'Ask venue staff to confirm today\'s menu and publish available items from the venue console.',
                    icon: LucideIcons.utensils,
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final category = menu.keys.elementAt(index);
                    final items = menu[category]!;
                    return _CategorySection(category: category, items: items);
                  }, childCount: menu.length),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: StateView.error(
                title: 'Could not load menu',
                subtitle: error.toString(),
                onRetry: () => ref.invalidate(groupedMenuProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueContextCard extends ConsumerWidget {
  const _VenueContextCard({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueContext = ref.watch(venueContextProvider);
    final activeOrdersAsync = ref.watch(activeOrdersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: FzColors.primary.withValues(alpha: 0.10),
                  borderRadius: FzRadii.compactRadius,
                ),
                child: const Icon(LucideIcons.mapPin, color: FzColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venueContext.venue?.name ?? 'Current venue',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      venueContext.table?.tableNumber != null
                          ? 'Table ${venueContext.table!.tableNumber}'
                          : venueContext.tableNumber != null
                          ? 'Table ${venueContext.tableNumber}'
                          : 'Ask staff to confirm your table',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ContextMetric(
                label: 'Cart',
                value: cart.isEmpty ? 'Empty' : cart.totalDisplay,
              ),
              const SizedBox(width: 10),
              _ContextMetric(
                label: 'Earn',
                value: cart.isEmpty ? 'Add items' : '${cart.estimatedFet} FET',
              ),
            ],
          ),
          const SizedBox(height: 10),
          activeOrdersAsync.when(
            data: (orders) => _StatusStrip(
              icon: orders.isEmpty ? LucideIcons.receipt : LucideIcons.timer,
              label: 'Order status',
              value: orders.isEmpty
                  ? 'Place an order to track it here.'
                  : 'Tap the live status pill for your latest order.',
            ),
            loading: () => const _StatusStrip(
              icon: LucideIcons.timer,
              label: 'Order status',
              value: 'Checking active orders...',
            ),
            error: (_, _) => const _StatusStrip(
              icon: LucideIcons.alertCircle,
              label: 'Order status',
              value: 'Pull to refresh order status.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextMetric extends StatelessWidget {
  const _ContextMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FzColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: FzColors.lightMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: FzColors.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: FzColors.lightMuted),
          ),
        ),
      ],
    );
  }
}

class _PaymentGuidanceCard extends StatelessWidget {
  const _PaymentGuidanceCard();

  @override
  Widget build(BuildContext context) {
    return const FzCard(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.badgeCheck, color: FzColors.success),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pay the venue directly by cash or supported local handoff. FET is earned after staff confirms the order payment.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.items});

  final MenuCategoryModel category;
  final List<MenuItemModel> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Text(
            category.name.toUpperCase(),
            style: FzTypography.metaLabel(
              color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
            ).copyWith(letterSpacing: 1.2),
          ),
        ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MenuItemCard(item: item),
          ),
        ),
      ],
    );
  }
}

class _MenuItemCard extends ConsumerWidget {
  const _MenuItemCard({required this.item});

  final MenuItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quantity = ref.watch(cartProvider.notifier).getQuantity(item.id);
    final estimatedFet = _estimatedFetForItem(item);

    return FzCard(
      padding: EdgeInsets.zero,
      borderRadius: FzRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              FzImageSurface(
                imageUrl: item.imageUrl,
                icon: LucideIcons.utensils,
                height: 132,
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: const BoxDecoration(
                    color: FzColors.success,
                    borderRadius: FzRadii.fullRadius,
                  ),
                  child: Text(
                    estimatedFet > 0 ? '+$estimatedFet FET' : 'Earn FET',
                    style: const TextStyle(
                      color: FzColors.darkBg,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (item.description != null)
                        Text(
                          item.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? FzColors.darkMuted
                                : FzColors.lightMuted,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.priceDisplay,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: FzColors.action,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: FzColors.success.withValues(alpha: 0.10),
                              borderRadius: FzRadii.fullRadius,
                              border: Border.all(
                                color: FzColors.success.withValues(alpha: 0.20),
                              ),
                            ),
                            child: Text(
                              estimatedFet > 0
                                  ? 'Earn ~$estimatedFet FET'
                                  : 'Earn FET',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: FzColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Credited after staff confirms payment.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: FzColors.darkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _QuantityControls(item: item, quantity: quantity),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityControls extends ConsumerWidget {
  const _QuantityControls({required this.item, required this.quantity});

  final MenuItemModel item;
  final int quantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (quantity == 0) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 76, maxWidth: 92),
        child: FilledButton.icon(
          onPressed: () => ref.read(cartProvider.notifier).addItem(item),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: const Text('Add'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
            minimumSize: const Size(76, 44),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Remove one',
            onPressed: () =>
                ref.read(cartProvider.notifier).removeItem(item.id),
            icon: const Icon(
              LucideIcons.minus,
              size: 18,
              color: FzColors.danger,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '$quantity',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
          IconButton(
            tooltip: 'Add one',
            onPressed: () => ref.read(cartProvider.notifier).addItem(item),
            icon: const Icon(
              LucideIcons.plus,
              size: 18,
              color: FzColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartPill extends StatelessWidget {
  const _CartPill({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/checkout'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: FzColors.darkText,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.shoppingCart,
              color: FzColors.darkBg,
              size: 18,
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Review order',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: FzColors.darkBg,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${cart.totalItemCount} items • +${cart.estimatedFet} FET',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: FzColors.darkBg.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              cart.totalDisplay,
              style: const TextStyle(
                color: FzColors.accent,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _estimatedFetForItem(MenuItemModel item) {
  if (item.currencyCode == 'EUR') return (item.price * 100).floor();
  if (item.currencyCode == 'RWF') return ((item.price / 1500) * 100).floor();
  return 0;
}
