import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/location/location_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../providers/venue_discovery_provider.dart';

class LocationAccessScreen extends ConsumerStatefulWidget {
  const LocationAccessScreen({super.key});

  @override
  ConsumerState<LocationAccessScreen> createState() =>
      _LocationAccessScreenState();
}

class _LocationAccessScreenState extends ConsumerState<LocationAccessScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(locationAccessProvider.notifier).refreshPermissionStatus(),
    );
  }

  Future<void> _useLocation() async {
    final success = await ref
        .read(locationAccessProvider.notifier)
        .requestCurrentLocation();
    if (success && mounted) {
      ref.invalidate(activeVenuesProvider);
      context.go('/venues');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationAccessProvider);
    final hasLocation = state.hasFreshLocation;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          children: [
            FzBackHeader(
              title: 'Location',
              subtitle: 'Bars',
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
              'Nearby Bars',
              textAlign: TextAlign.center,
              style: FzTypography.display(size: 36, color: FzColors.darkText),
            ),
            const SizedBox(height: 12),
            const Text(
              'Find open bars.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FzColors.darkMuted,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            FzCard(
              padding: const EdgeInsets.all(16),
              borderRadius: FzRadii.card,
              child: Row(
                children: [
                  Icon(
                    hasLocation
                        ? LucideIcons.navigation
                        : LucideIcons.shieldCheck,
                    color: hasLocation ? FzColors.accent : FzColors.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasLocation ? 'Near Me active.' : 'Used for bars.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              _LocationStatusCard(message: state.errorMessage!),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: state.isLoading ? null : _useLocation,
              icon: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.navigation),
              label: Text(state.isLoading ? 'Finding...' : 'Use Location'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: state.isLoading ? null : () => context.go('/venues'),
              icon: const Icon(LucideIcons.mapPin),
              label: const Text('Browse Venues'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (hasLocation) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        await ref
                            .read(locationAccessProvider.notifier)
                            .clearLocation();
                        ref.invalidate(activeVenuesProvider);
                      },
                icon: const Icon(LucideIcons.x),
                label: const Text('Turn Off'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(14),
      borderRadius: FzRadii.card,
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: FzColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: FzColors.darkText,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
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
