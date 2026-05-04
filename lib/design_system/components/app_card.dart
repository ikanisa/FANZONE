import 'package:flutter/material.dart';

import '../../widgets/common/fz_card.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.margin,
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: padding,
      margin: margin,
      color: color,
      borderColor: borderColor,
      borderRadius: AppRadii.card,
      onTap: onTap,
      child: child,
    );
  }
}
