import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class FzGlassLoader extends StatelessWidget {
  const FzGlassLoader({
    super.key,
    this.message,
    this.size = 24.0,
    this.useBackdrop = true,
  });

  final String? message;
  final double size;
  final bool useBackdrop;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = FzColors.primary;

    final Widget loaderContent = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(
            color: accentColor,
            strokeWidth: 2.5,
          ),
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _PulseText(
            text: message!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ],
    );

    if (!useBackdrop) return loaderContent;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: loaderContent,
          ),
        ),
      ),
    );
  }
}

class _PulseText extends StatefulWidget {
  const _PulseText({required this.text, this.style});
  final String text;
  final TextStyle? style;

  @override
  State<_PulseText> createState() => _PulseTextState();
}

class _PulseTextState extends State<_PulseText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Text(widget.text.toUpperCase(), style: widget.style),
    );
  }
}
