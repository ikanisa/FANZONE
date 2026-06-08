import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../models/hospitality/menu_item_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../providers/cart_provider.dart';

Future<void> showMenuItemDetailSheet({
  required BuildContext context,
  required WidgetRef ref,
  required MenuItemModel item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _MenuItemDetailSheet(ref: ref, item: item),
  );
}

bool menuItemNeedsConfirmation(MenuItemModel item) {
  return item.allergens.isNotEmpty || menuItemIsAgeRestricted(item);
}

bool menuItemIsAgeRestricted(MenuItemModel item) {
  return _truthy(item.metadata['age_restricted']) ||
      _truthy(item.metadata['requires_age_confirmation']) ||
      _truthy(item.metadata['is_alcoholic']) ||
      _truthy(item.dietaryFlags['age_restricted']) ||
      _truthy(item.dietaryFlags['alcohol']);
}

String menuAddOnName(Map<String, dynamic> addOn) {
  final raw = addOn['name'] ?? addOn['label'] ?? addOn['title'];
  final value = raw?.toString().trim();
  return value == null || value.isEmpty ? 'Add-on' : value;
}

bool _truthy(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return {'true', '1', 'yes', 'on', 'alcohol'}.contains(value.toLowerCase());
  }
  return false;
}

class _MenuItemDetailSheet extends StatefulWidget {
  const _MenuItemDetailSheet({required this.ref, required this.item});

  final WidgetRef ref;
  final MenuItemModel item;

  @override
  State<_MenuItemDetailSheet> createState() => _MenuItemDetailSheetState();
}

class _MenuItemDetailSheetState extends State<_MenuItemDetailSheet> {
  final Set<int> _selectedAddOns = <int>{};
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;
  bool _confirmed = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final selectedAddOns = _selectedAddOns
        .map((index) => item.addOns[index])
        .toList(growable: false);
    final unitTotal = item.price + menuAddOnsTotal(selectedAddOns);
    final needsConfirmation = menuItemNeedsConfirmation(item);
    final canAdd = item.isAvailable && (!needsConfirmation || _confirmed);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: FzRadii.fullRadius,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FzImageSurface(
                    imageUrl: item.imageUrl,
                    icon: LucideIcons.utensils,
                    height: 190,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatMenuAmount(unitTotal, item.currencyCode),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: FzColors.action,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  if (!item.isAvailable) ...[
                    const SizedBox(height: 12),
                    const _NoticeRow(
                      icon: LucideIcons.circleSlash,
                      text: 'This item is currently unavailable.',
                      color: FzColors.warning,
                    ),
                  ],
                  if (item.description?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 10),
                    Text(
                      item.description!.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (item.isVegetarian)
                        const _InfoChip(label: 'Vegetarian'),
                      if (item.isVegan) const _InfoChip(label: 'Vegan'),
                      if (item.isGlutenFree)
                        const _InfoChip(label: 'Gluten-free'),
                      if (menuItemIsAgeRestricted(item))
                        const _InfoChip(label: 'Age check'),
                    ],
                  ),
                  if (item.allergens.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SectionHeader(
                      icon: LucideIcons.triangleAlert,
                      label: 'Allergens',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.allergens.join(', '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: FzColors.warning,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (item.addOns.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionHeader(
                      icon: LucideIcons.plus,
                      label: 'Add-ons',
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(item.addOns.length, (index) {
                      final addOn = item.addOns[index];
                      final price = menuAddOnPrice(addOn);
                      return CheckboxListTile(
                        key: ValueKey('menu_add_on_$index'),
                        value: _selectedAddOns.contains(index),
                        onChanged: item.isAvailable
                            ? (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedAddOns.add(index);
                                  } else {
                                    _selectedAddOns.remove(index);
                                  }
                                });
                              }
                            : null,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          menuAddOnName(addOn),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: price > 0
                            ? Text(
                                '+${_formatMenuAmount(price, item.currencyCode)}',
                              )
                            : null,
                      );
                    }),
                  ],
                  const SizedBox(height: 20),
                  const _SectionHeader(
                    icon: LucideIcons.notebookPen,
                    label: 'Prep note',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('menu_item_prep_note'),
                    controller: _notesController,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Example: sauce on the side',
                    ),
                  ),
                  if (needsConfirmation) ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      key: const ValueKey('menu_item_confirmation'),
                      value: _confirmed,
                      onChanged: item.isAvailable
                          ? (value) =>
                                setState(() => _confirmed = value ?? false)
                          : null,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        menuItemIsAgeRestricted(item)
                            ? 'I confirm this order is appropriate for me and I reviewed the venue restrictions.'
                            : 'I reviewed the allergen information before adding this item.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
                border: Border(top: BorderSide(color: border)),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    _QuantityStepper(
                      quantity: _quantity,
                      onRemove: _quantity == 1
                          ? null
                          : () => setState(() => _quantity -= 1),
                      onAdd: item.isAvailable
                          ? () => setState(() => _quantity += 1)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('menu_item_detail_add'),
                        onPressed: canAdd
                            ? () {
                                widget.ref
                                    .read(cartProvider.notifier)
                                    .addConfiguredItem(
                                      item,
                                      quantity: _quantity,
                                      addOns: selectedAddOns,
                                      specialInstructions:
                                          _notesController.text,
                                    );
                                Navigator.of(context).pop();
                              }
                            : null,
                        icon: const Icon(LucideIcons.shoppingCart, size: 18),
                        label: Text(
                          item.isAvailable
                              ? 'Add ${_formatMenuAmount(unitTotal * _quantity, item.currencyCode)}'
                              : 'Unavailable',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: FzColors.primary),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      avatar: const Icon(LucideIcons.circleCheck, size: 14),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onRemove,
    required this.onAdd,
  });

  final int quantity;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: FzRadii.fullRadius,
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Remove one',
            onPressed: onRemove,
            icon: const Icon(LucideIcons.minus, size: 18),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            tooltip: 'Add one',
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus, size: 18),
          ),
        ],
      ),
    );
  }
}

String _formatMenuAmount(double amount, String currencyCode) {
  if (currencyCode == 'EUR') return '€${amount.toStringAsFixed(2)}';
  if (currencyCode == 'RWF') return 'RWF ${amount.toStringAsFixed(0)}';
  return '$currencyCode ${amount.toStringAsFixed(2)}';
}
