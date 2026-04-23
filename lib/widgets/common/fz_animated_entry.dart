import 'package:flutter/material.dart';

import '../../core/accessibility/motion.dart';

/// Wraps a child widget with a staggered fade + slide-up entrance animation.
///
/// Used for list items (match cards, reward cards, etc.) to create the
/// Framer Motion-style `initial={{ opacity: 0, y: 10 }}` effect from the
/// original design.
class FzAnimatedEntry extends StatefulWidget {
  const FzAnimatedEntry({
    super.key,
    required this.child,
    this.index = 0,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 350),
    this.slideOffset = 0.03,
  });

  final Widget child;

  /// Index in the list — used to calculate stagger delay.
  final int index;

  /// Delay between each list item's animation start.
  final Duration staggerDelay;

  /// Duration of the fade + slide animation.
  final Duration duration;

  /// Vertical offset as fraction of parent height (0.03 = 3%).
  final double slideOffset;

  @override
  State<FzAnimatedEntry> createState() => _FzAnimatedEntryState();
}

class _FzAnimatedEntryState extends State<FzAnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  bool _didScheduleForward = false;
  bool _prefersReducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefersReducedMotion = prefersReducedMotion(context);

    if (_prefersReducedMotion) {
      _controller.value = 1;
      return;
    }

    if (_didScheduleForward) {
      return;
    }

    _didScheduleForward = true;

    // Stagger based on index — cap at 8 items to avoid long waits
    final cappedIndex = widget.index.clamp(0, 8);
    final delay = widget.staggerDelay * cappedIndex;

    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_prefersReducedMotion) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
