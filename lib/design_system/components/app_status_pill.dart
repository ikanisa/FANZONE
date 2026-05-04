import 'package:flutter/material.dart';

import 'app_badge.dart';

class AppStatusPill extends StatelessWidget {
  const AppStatusPill({super.key, required this.status, this.label});

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return AppBadge.status(label ?? status);
  }
}
