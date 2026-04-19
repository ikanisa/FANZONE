import 'package:flutter/material.dart';

import '../../../theme/typography.dart';

/// Standardized section header with optional action button.
class HubSectionHeader extends StatelessWidget {
  const HubSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: FzTypography.sectionLabel(
            isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
