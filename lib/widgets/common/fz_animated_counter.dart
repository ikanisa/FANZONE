import 'package:flutter/material.dart';

/// Animated counter that smoothly transitions between numeric values.
///
/// Matches the reference `AnimatedCounter.tsx` component:
/// - spring-like animation (mass: 0.8, stiffness: 75, damping: 15)
/// - displays rounded, locale-formatted integers
///
/// Usage:
/// ```dart
/// FzAnimatedCounter(value: 1500)
/// FzAnimatedCounter(value: balance, style: FzTypography.scoreLarge())
/// ```
class FzAnimatedCounter extends StatefulWidget {
  const FzAnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.prefix = '',
    this.suffix = '',
    this.formatter,
  });

  /// The target numeric value to animate towards.
  final double value;

  /// Text style for the displayed number.
  final TextStyle? style;

  /// Duration of the counting animation.
  final Duration duration;

  /// Animation curve — defaults to easeOutCubic (spring-like feel).
  final Curve curve;

  /// Optional prefix (e.g. "FET " or "+ ").
  final String prefix;

  /// Optional suffix (e.g. " FET").
  final String suffix;

  /// Optional custom formatter. Defaults to locale-formatted integer.
  final String Function(double value)? formatter;

  @override
  State<FzAnimatedCounter> createState() => _FzAnimatedCounterState();
}

class _FzAnimatedCounterState extends State<FzAnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: widget.value,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void didUpdateWidget(FzAnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _animation.value;
      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double value) {
    if (widget.formatter != null) {
      return widget.formatter!(value);
    }
    final rounded = value.round();
    // Locale-formatted integer (e.g. 1,500)
    return rounded.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;

    if (reduceMotion) {
      return Text(
        '${widget.prefix}${_format(widget.value)}${widget.suffix}',
        style: widget.style,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_format(_animation.value)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
