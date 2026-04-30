import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../providers/venue_context_provider.dart';
import '../providers/cart_provider.dart';
import '../../../models/hospitality/menu_item_model.dart';
import '../../../models/hospitality/menu_category_model.dart';

class VenueMenuScreen extends ConsumerWidget {
  const VenueMenuScreen({super.key, required this.venueSlug});

  final String venueSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueContext = ref.watch(venueContextProvider);

    // If context not set yet (deep link entry), we show loading
    if (!venueContext.hasVenue || venueContext.venue?.slug != venueSlug) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final menuAsync = ref.watch(groupedMenuProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _SliverHeader(venueName: venueContext.venue!.name),
          menuAsync.when(
            data: (menu) {
              if (menu.isEmpty) {
                return SliverFillRemaining(
                  child: StateView.empty(
                    title: 'No menu available',
                    subtitle: 'This venue hasn\'t added any items yet.',
                    icon: LucideIcons.utensils,
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = menu.keys.elementAt(index);
                      final items = menu[category]!;
                      return _CategorySection(category: category, items: items);
                    },
                    childCount: menu.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: StateView.error(
                title: 'Failed to load menu',
                subtitle: e.toString(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: cart.isNotEmpty ? _CartPill(cart: cart) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _SliverHeader extends ConsumerWidget {
  const _SliverHeader({required this.venueName});

  final String venueName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            onPressed: () {
              ref.read(venueContextProvider.notifier).clear();
              context.go('/');
            },
            icon: const Icon(LucideIcons.logOut, size: 14),
            label: const Text('EXIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: FzColors.danger),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Text(
          venueName,
          style: FzTypography.display(
            size: 24,
            color: isDark ? FzColors.darkText : FzColors.lightText,
          ),
        ),
      ),
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
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _MenuItemCard(item: item),
        )),
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
              width: 80,
              height: 80,
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                const SizedBox(height: 8),
                Text(
                  item.currencyCode == 'EUR' ? '€${item.price.toStringAsFixed(2)}' : '${item.currencyCode} ${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: FzColors.accent),
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
          icon: const Icon(LucideIcons.minusCircle, size: 22, color: FzColors.danger),
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
          icon: const Icon(LucideIcons.plusCircle, size: 22, color: FzColors.success),
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
            const Icon(LucideIcons.shoppingCart, color: FzColors.darkBg, size: 18),
            const SizedBox(width: 12),
            Text(
              'VIEW CART • ${cart.totalItemCount} ITEMS',
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
