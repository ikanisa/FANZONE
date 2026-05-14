import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

class WebMobileShell extends StatelessWidget {
  const WebMobileShell({super.key, required this.child});

  final Widget child;

  static const double maxMobileWidth = 430;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return ColoredBox(
      color: FzColors.darkBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : media.size.width;
          final availableHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : media.size.height;
          final width = math.min(availableWidth, maxMobileWidth);
          final height = availableHeight;

          return Center(
            child: ClipRect(
              child: SizedBox(
                width: width,
                height: height,
                child: MediaQuery(
                  data: media.copyWith(size: Size(width, height)),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
