import 'package:flutter/material.dart';

import '../../widgets/common/fz_badge.dart';

typedef AppBadgeVariant = FzBadgeVariant;

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = FzBadgeVariant.standard,
    this.icon,
    this.pulse = false,
  });

  final String label;
  final FzBadgeVariant variant;
  final IconData? icon;
  final bool pulse;

  factory AppBadge.live() => const AppBadge(
    label: 'LIVE',
    variant: FzBadgeVariant.danger,
    pulse: true,
  );

  factory AppBadge.status(String status) {
    return AppBadge(label: status.toUpperCase(), variant: _variantFor(status));
  }

  @override
  Widget build(BuildContext context) {
    return FzBadge(
      label: label,
      variant: variant,
      icon: icon,
      pulse: pulse,
      fontSize: 13,
    );
  }
}

FzBadgeVariant _variantFor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'paid':
    case 'served':
    case 'eligible':
    case 'won':
    case 'settled':
      return FzBadgeVariant.success;
    case 'pending':
    case 'placed':
    case 'preparing':
    case 'settlement_pending':
      return FzBadgeVariant.warning;
    case 'cancelled':
    case 'failed':
    case 'ineligible':
    case 'lost':
      return FzBadgeVariant.danger;
    case 'live':
    case 'open':
      return FzBadgeVariant.accent;
    default:
      return FzBadgeVariant.outline;
  }
}
