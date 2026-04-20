import 'package:flutter/material.dart';

import '../../theme/colors.dart';

class FzWordmark extends StatelessWidget {
  const FzWordmark({
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.fanColor = FzColors.success,
    this.zoneColor = FzColors.coral,
  });

  final TextStyle? style;
  final TextAlign textAlign;
  final Color fanColor;
  final Color zoneColor;

  static TextSpan span({
    TextStyle? style,
    Color fanColor = FzColors.success,
    Color zoneColor = FzColors.coral,
  }) {
    final baseStyle = style ?? const TextStyle();
    return TextSpan(
      children: [
        TextSpan(
          text: 'FAN',
          style: baseStyle.copyWith(color: fanColor),
        ),
        TextSpan(
          text: 'ZONE',
          style: baseStyle.copyWith(color: zoneColor),
        ),
      ],
    );
  }

  static List<InlineSpan> spansForText(
    String text, {
    TextStyle? style,
    Color fanColor = FzColors.success,
    Color zoneColor = FzColors.coral,
  }) {
    final matches = RegExp('FANZONE').allMatches(text).toList();
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in matches) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: style),
        );
      }
      spans.add(span(style: style, fanColor: fanColor, zoneColor: zoneColor));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = DefaultTextStyle.of(context).style.merge(style);
    return Semantics(
      label: 'FANZONE',
      child: ExcludeSemantics(
        child: RichText(
          textAlign: textAlign,
          textScaler: MediaQuery.textScalerOf(context),
          text: span(
            style: resolvedStyle,
            fanColor: fanColor,
            zoneColor: zoneColor,
          ),
        ),
      ),
    );
  }
}
