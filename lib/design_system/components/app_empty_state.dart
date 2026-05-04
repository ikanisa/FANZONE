import 'package:flutter/material.dart';

import '../../widgets/common/fz_empty_state.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final Widget? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return FzEmptyState(
      title: title,
      description: description,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
