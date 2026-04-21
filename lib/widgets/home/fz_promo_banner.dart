import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';
import '../common/fz_badge.dart';

/// Promotional banner matching the reference `HomeFeed.PromoBanner`.
///
/// Uses `AnimatedSize` + `FadeTransition` for animated entry/exit,
/// matching the reference's `AnimatePresence` + `opacity/height` approach.
class FzPromoBanner extends StatefulWidget {
  const FzPromoBanner({super.key});

  @override
  State<FzPromoBanner> createState() => _FzPromoBannerState();
}

class _FzPromoBannerState extends State<FzPromoBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FzRadii.card - 4),
            border: Border.all(color: FzColors.darkBorder),
            gradient: LinearGradient(
              colors: [
                FzColors.blue.withValues(alpha: 0.20),
                FzColors.danger.withValues(alpha: 0.20),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(FzRadii.card - 4),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.02),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [FzColors.blue, FzColors.danger],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: FzColors.danger.withValues(alpha: 0.3),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      decoration: const BoxDecoration(
                        color: FzColors.darkBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.flame,
                        size: 18,
                        color: FzColors.danger,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FzBadge(
                              label: 'DERBY DAY',
                              variant: FzBadgeVariant.danger,
                              pulse: true,
                              fontSize: 8,
                            ),
                            const SizedBox(width: 8),
                            Text('GLOBAL', style: FzTypography.metaLabel()),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manchester Is RED',
                          style: FzTypography.display(size: 14),
                        ),
                        Text(
                          'Unmissable odds & exclusive pools open now!',
                          style: FzTypography.metaLabel(size: 9),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _dismiss,
                        excludeFromSemantics: true,
                        child: Semantics(
                          button: true,
                          label: 'Dismiss promotion',
                          onTap: _dismiss,
                          child: ExcludeSemantics(
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: FzColors.darkSurface2,
                                shape: BoxShape.circle,
                                border: Border.all(color: FzColors.darkBorder),
                              ),
                              child: const Icon(
                                LucideIcons.x,
                                size: 12,
                                color: FzColors.darkMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => context.go('/pools'),
                        child: Container(
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: const BoxDecoration(
                            color: FzColors.danger,
                            borderRadius: FzRadii.fullRadius,
                          ),
                          child: Center(
                            child: Text(
                              'ENTER POOL',
                              style: FzTypography.metaLabel(
                                size: 9,
                                color: FzColors.darkBg,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
