import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    switch (variant) {
      case AppButtonVariant.primary:
        return FilledButton(onPressed: onPressed, child: child);
      case AppButtonVariant.secondary:
        return OutlinedButton(onPressed: onPressed, child: child);
      case AppButtonVariant.ghost:
        return TextButton(onPressed: onPressed, child: child);
    }
  }
}
