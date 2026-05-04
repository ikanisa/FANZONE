import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';

/// Venue card — bar icon, name, live chip, counters.
class AppVenueCard extends StatelessWidget {
  const AppVenueCard({
    super.key,
    required this.name,
    this.city,
    this.coverUrl,
    this.isLive = false,
    this.poolCount = 0,
    this.onTap,
  });

  final String name;
  final String? city;
  final String? coverUrl;
  final bool isLive;
  final int poolCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: FzRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: FzRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FzColors.darkSurface,
            borderRadius: FzRadii.cardRadius,
            border: Border.all(
              color: isLive ? FzColors.green : FzColors.darkBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: FzColors.darkSurface2,
                  borderRadius: FzRadii.buttonRadius,
                  border: Border.all(color: FzColors.darkBorder),
                ),
                child: const Icon(LucideIcons.store, size: 22, color: FzColors.darkMuted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isLive)
                          Container(
                            width: 7, height: 7,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                              color: FzColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    if (city != null) ...[
                      const SizedBox(height: 4),
                      Text(city!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FzColors.darkMuted)),
                    ],
                    if (poolCount > 0) ...[
                      const SizedBox(height: 6),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.trophy, size: 14, color: FzColors.cyan),
                        const SizedBox(width: 4),
                        Text('$poolCount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: FzColors.cyan)),
                      ]),
                    ],
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18, color: FzColors.darkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
