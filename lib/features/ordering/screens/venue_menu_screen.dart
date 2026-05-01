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
      appBar: AppBar(
        toolbarHeight: 72,
        centerTitle: false,
        titleSpacing: 20,
        title: Row(
          children: [
            const Icon(LucideIcons.utensils, size: 22, color: FzColors.primary),
            const SizedBox(width: 10),
            Text(
              'Bar',
              style: FzTypography.display(
                size: 34,
                color: Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkText
                    : FzColors.lightText,
              ),
            ),
          ],
        ),
        actions: [
          if (venueContext.hasVenue)
            IconButton(
              tooltip: 'Leave venue',
              onPressed: () {
                ref.read(venueContextProvider.notifier).clear();
                ref.read(cartProvider.notifier).clear();
              },
              icon: const Icon(LucideIcons.logOut, size: 18),
            ),
        ],
      ),
      body: venueContext.hasVenue
          ? _BarContent(cart: cart)
          : const _NoVenueState(),
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
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 140),
      children: const [
        FzEmptyState(
          title: 'Scan a table QR',
          description:
              'Your venue, table, menu, cart, payment guidance, and FET rewards appear here as soon as you scan a FANZONE table code.',
          icon: Icon(LucideIcons.qrCode),
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

    return FzCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (item.imageUrl != null)
            Container(
              width: 76,
              height: 76,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(item.imageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
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
                      color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.currencyCode == 'EUR'
                          ? '€${item.price.toStringAsFixed(2)}'
                          : '${item.currencyCode} ${item.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: FzColors.accent,
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
                      child: const Text(
                        'Earn FET',
                        style: TextStyle(
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
                  style: TextStyle(fontSize: 11, color: FzColors.darkMuted),
                ),
              ],
            ),
          ),
          _QuantityControls(item: item, quantity: quantity),
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
      return IconButton.filledTonal(
        onPressed: () => ref.read(cartProvider.notifier).addItem(item),
        icon: const Icon(LucideIcons.plus, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: FzColors.accent.withValues(alpha: 0.1),
          foregroundColor: FzColors.accent,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => ref.read(cartProvider.notifier).removeItem(item.id),
          icon: const Icon(
            LucideIcons.minusCircle,
            size: 22,
            color: FzColors.danger,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '$quantity',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: () => ref.read(cartProvider.notifier).addItem(item),
          icon: const Icon(
            LucideIcons.plusCircle,
            size: 22,
            color: FzColors.success,
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            Text(
              'CART • ${cart.totalItemCount}',
              style: const TextStyle(
                color: FzColors.darkBg,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.5,
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
