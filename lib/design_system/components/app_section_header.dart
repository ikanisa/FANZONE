import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Section header — uppercase, large, bold.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
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
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: FzTypography.sportsTitle(size: 24, color: FzColors.darkText),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: FzColors.cyan,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
