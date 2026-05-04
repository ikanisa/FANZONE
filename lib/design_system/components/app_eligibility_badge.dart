import 'package:flutter/material.dart';

import '../../widgets/common/fz_badge.dart';

enum AppEligibilityState {
  eligible,
  orderRequired,
  ineligible,
  settlementPending,
  settled,
}

class AppEligibilityBadge extends StatelessWidget {
  const AppEligibilityBadge({super.key, required this.state});

  final AppEligibilityState state;

  @override
  Widget build(BuildContext context) {
    return FzBadge(
      label: switch (state) {
        AppEligibilityState.eligible => 'Eligible',
        AppEligibilityState.orderRequired => 'Needed',
        AppEligibilityState.ineligible => 'Ineligible',
        AppEligibilityState.settlementPending => 'Pending',
        AppEligibilityState.settled => 'Settled',
      },
      variant: switch (state) {
        AppEligibilityState.eligible => FzBadgeVariant.success,
        AppEligibilityState.orderRequired => FzBadgeVariant.warning,
        AppEligibilityState.ineligible => FzBadgeVariant.danger,
        AppEligibilityState.settlementPending => FzBadgeVariant.accent3,
        AppEligibilityState.settled => FzBadgeVariant.success,
      },
      fontSize: 13,
    );
  }
}
