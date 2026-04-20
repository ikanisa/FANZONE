import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';

enum FzBadgeVariant {
  standard,
  accent,
  accent2,
  accent3,
  success,
  danger,
  teal,
  outline,
  ghost,
}

/// Compact badge / chip aligned with the reference FANZONE Badge component.
class FzBadge extends StatelessWidget {
  const FzBadge({
    super.key,
    required this.label,
    this.variant = FzBadgeVariant.standard,
    this.color,
    this.textColor,
    this.pulse = false,
    this.icon,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final String label;
  final FzBadgeVariant variant;
  final Color? color;
  final Color? textColor;
  final bool pulse;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  factory FzBadge.live() => const FzBadge(
    label: 'LIVE',
    variant: FzBadgeVariant.danger,
    pulse: true,
    fontSize: 9,
  );

  factory FzBadge.count(int count) => FzBadge(
    label: count.toString(),
    variant: FzBadgeVariant.accent,
    fontSize: 9,
  );

  factory FzBadge.status(String status) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'live':
        return const FzBadge(
          label: 'LIVE',
          variant: FzBadgeVariant.danger,
          pulse: true,
        );
      case 'open':
      case 'submitted':
        return FzBadge(
          label: status.toUpperCase(),
          variant: FzBadgeVariant.accent,
          pulse: normalized == 'open',
        );
      case 'settled':
      case 'voided':
        return FzBadge(
          label: status.toUpperCase(),
          variant: FzBadgeVariant.accent3,
        );
      case 'won':
        return const FzBadge(label: 'WON', variant: FzBadgeVariant.success);
      case 'lost':
        return const FzBadge(label: 'LOST', variant: FzBadgeVariant.danger);
      case 'locked':
      case 'void':
        return FzBadge(
          label: status.toUpperCase(),
          variant: FzBadgeVariant.ghost,
        );
      default:
        return FzBadge(
          label: status.toUpperCase(),
          variant: FzBadgeVariant.outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _resolvePalette(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: palette.border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pulse) ...[
              _BadgePulseDot(color: palette.pulseColor),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: fontSize + 1, color: palette.foreground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: palette.foreground,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _FzBadgePalette _resolvePalette(BuildContext context) {
    if (color != null || textColor != null) {
      return _FzBadgePalette(
        background: color ?? FzColors.darkSurface2,
        border: Colors.transparent,
        foreground: textColor ?? FzColors.darkText,
        pulseColor: textColor ?? FzColors.darkText,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final surface3 = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;

    switch (variant) {
      case FzBadgeVariant.accent:
        return _tinted(FzColors.primary);
      case FzBadgeVariant.accent2:
        return _tinted(FzColors.blue);
      case FzBadgeVariant.accent3:
        return _tinted(FzColors.coral);
      case FzBadgeVariant.success:
        return _tinted(FzColors.success);
      case FzBadgeVariant.danger:
        return _tinted(FzColors.danger);
      case FzBadgeVariant.teal:
        return _tinted(FzColors.teal);
      case FzBadgeVariant.outline:
        return _FzBadgePalette(
          background: Colors.transparent,
          border: border,
          foreground: text,
          pulseColor: text,
        );
      case FzBadgeVariant.ghost:
        return _FzBadgePalette(
          background: surface3,
          border: Colors.transparent,
          foreground: muted,
          pulseColor: muted,
        );
      case FzBadgeVariant.standard:
        return _FzBadgePalette(
          background: surface2.withValues(alpha: 0.92),
          border: border,
          foreground: text,
          pulseColor: text,
        );
    }
  }

  _FzBadgePalette _tinted(Color tint) => _FzBadgePalette(
    background: tint.withValues(alpha: 0.10),
    border: tint.withValues(alpha: 0.20),
    foreground: tint,
    pulseColor: tint,
  );
}

class _FzBadgePalette {
  const _FzBadgePalette({
    required this.background,
    required this.border,
    required this.foreground,
    required this.pulseColor,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final Color pulseColor;
}

class _BadgePulseDot extends StatefulWidget {
  const _BadgePulseDot({required this.color});

  final Color color;

  @override
  State<_BadgePulseDot> createState() => _BadgePulseDotState();
}

class _BadgePulseDotState extends State<_BadgePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.88, end: 1.12).animate(_opacity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shouldReduceMotion(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );

    if (_shouldReduceMotion(context)) {
      return dot;
    }

    return FadeTransition(
      opacity: Tween<double>(begin: 0.75, end: 1).animate(_opacity),
      child: ScaleTransition(scale: _scale, child: dot),
    );
  }

  bool _shouldReduceMotion(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;
  }
}
