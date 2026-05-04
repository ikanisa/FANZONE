import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';

/// Floating rounded modal bottom sheet helper.
class AppModalSheet extends StatelessWidget {
  const AppModalSheet({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 24),
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;

  static Future<T?> show<T>(BuildContext context, {required Widget child, String? title}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppModalSheet(title: title, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: FzColors.darkSurface,
        borderRadius: FzRadii.bottomSheetRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: FzColors.darkMuted.withValues(alpha: 0.4),
              borderRadius: FzRadii.fullRadius,
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: 18),
            Text(title!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ],
          const SizedBox(height: 18),
          Flexible(
            child: SingleChildScrollView(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
