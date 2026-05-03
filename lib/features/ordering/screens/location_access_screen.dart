import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';

class LocationAccessScreen extends StatelessWidget {
  const LocationAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          children: [
            FzBackHeader(
              title: 'Location',
              subtitle: 'Venue discovery',
              onClose: () => context.go('/venues'),
            ),
            const SizedBox(height: 34),
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  radius: 0.85,
                  colors: [
                    FzColors.accent,
                    FzColors.darkSurface,
                    FzColors.darkBg,
                  ],
                  stops: [0, 0.48, 1],
                ),
                borderRadius: FzRadii.heroRadius,
                border: Border.all(color: FzColors.darkBorder),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.navigation,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                  const Positioned(left: 22, top: 34, child: _MapDot(size: 10)),
                  const Positioned(right: 30, top: 62, child: _MapDot(size: 7)),
                  const Positioned(
                    left: 58,
                    bottom: 40,
                    child: _MapDot(size: 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Find Sports Bars Near You',
              textAlign: TextAlign.center,
              style: FzTypography.display(size: 36, color: FzColors.darkText),
            ),
            const SizedBox(height: 12),
            const Text(
              'Use venue discovery to find open FANZONE bars, match rooms, menus, and FET rewards around your current city.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FzColors.darkMuted,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            const FzCard(
              padding: EdgeInsets.all(16),
              borderRadius: FzRadii.card,
              child: Row(
                children: [
                  Icon(LucideIcons.shieldCheck, color: FzColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Location is used only for venue discovery. You can continue by browsing all active venues.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/venues'),
              icon: const Icon(LucideIcons.mapPin),
              label: const Text('Browse Venues'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Not Now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapDot extends StatelessWidget {
  const _MapDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: FzColors.success,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: FzColors.success.withValues(alpha: 0.42),
            blurRadius: 16,
          ),
        ],
      ),
    );
  }
}
