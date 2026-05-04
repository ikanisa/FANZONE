import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';

/// Game card — icon, name, reward FET, teams, join CTA.
class AppGameCard extends StatelessWidget {
  const AppGameCard({
    super.key,
    required this.name,
    this.gameType = 'football',
    this.rewardFet = 0,
    this.teamsCount = 0,
    this.startLabel,
    this.onTap,
  });

  final String name;
  final String gameType;
  final int rewardFet;
  final int teamsCount;
  final String? startLabel;
  final VoidCallback? onTap;

  IconData get _icon => switch (gameType) {
    'football' => LucideIcons.circleDot,
    'music' => LucideIcons.music,
    'trivia' => LucideIcons.helpCircle,
    'bingo' => LucideIcons.grid,
    _ => LucideIcons.gamepad2,
  };

  Color get _accentColor => switch (gameType) {
    'football' => FzColors.green,
    'music' => FzColors.cyan,
    'trivia' => FzColors.gold,
    'bingo' => FzColors.orange,
    _ => FzColors.cyan,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: FzRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: FzRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: FzColors.darkSurface,
            borderRadius: FzRadii.cardRadius,
            border: Border.all(color: FzColors.darkBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  borderRadius: FzRadii.buttonRadius,
                ),
                child: Icon(_icon, size: 24, color: _accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (rewardFet > 0) ...[
                          const Icon(
                            LucideIcons.zap,
                            size: 14,
                            color: FzColors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$rewardFet FET',
                            style: FzTypography.chipLabel(
                              size: 12,
                              color: FzColors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (teamsCount > 0) ...[
                          const Icon(
                            LucideIcons.users,
                            size: 14,
                            color: FzColors.darkMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$teamsCount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: FzColors.darkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (startLabel != null)
                Text(
                  startLabel!,
                  style: FzTypography.chipLabel(
                    size: 12,
                    color: FzColors.darkMuted,
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: FzColors.darkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
