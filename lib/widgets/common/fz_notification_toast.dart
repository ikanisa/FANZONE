import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';

/// In-app notification toast overlay matching the reference NotificationToast.tsx.
///
/// Displays a slide-in toast from the top with icon, title, and message,
/// then auto-dismisses after [autoDismissDuration].
///
/// Usage:
/// ```dart
/// FzNotificationToast.show(
///   context,
///   title: 'Prediction scored',
///   message: 'Your picks have been graded.',
///   type: FzToastType.predictionReward,
/// );
/// ```
enum FzToastType { predictionUpdate, predictionReward, system }

class FzNotificationToast extends StatefulWidget {
  const FzNotificationToast({
    super.key,
    required this.title,
    required this.message,
    this.type = FzToastType.system,
    this.autoDismissDuration = const Duration(seconds: 4),
    this.onDismissed,
    this.onTap,
  });

  final String title;
  final String message;
  final FzToastType type;
  final Duration autoDismissDuration;
  final VoidCallback? onDismissed;
  final VoidCallback? onTap;

  /// Show a toast overlay from the top of the screen.
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    FzToastType type = FzToastType.system,
    Duration autoDismissDuration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => FzNotificationToast(
        title: title,
        message: message,
        type: type,
        autoDismissDuration: autoDismissDuration,
        onDismissed: () => entry.remove(),
        onTap: () {
          entry.remove();
          onTap?.call();
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<FzNotificationToast> createState() => _FzNotificationToastState();
}

class _FzNotificationToastState extends State<FzNotificationToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _autoDismissTimer = Timer(widget.autoDismissDuration, _dismiss);
  }

  void _dismiss() {
    _autoDismissTimer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismissed?.call();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  IconData _icon() {
    switch (widget.type) {
      case FzToastType.predictionUpdate:
        return LucideIcons.swords;
      case FzToastType.predictionReward:
        return LucideIcons.trophy;
      case FzToastType.system:
        return LucideIcons.bell;
    }
  }

  Color _iconColor() {
    switch (widget.type) {
      case FzToastType.predictionUpdate:
        return FzColors.primary;
      case FzToastType.predictionReward:
        return FzColors.coral;
      case FzToastType.system:
        return FzColors.darkMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).viewPadding.top;

    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTap: widget.onTap ?? _dismiss,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < -100) {
                  _dismiss();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? FzColors.darkSurface2
                      : FzColors.lightSurface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: FzColors.primary.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? FzColors.darkSurface3
                            : FzColors.lightSurface2,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icon(), size: 20, color: _iconColor()),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? FzColors.darkText
                                  : FzColors.lightText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? FzColors.darkMuted
                                  : FzColors.lightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
