import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';

/// Pool card matching reference — status chip, FET pot, creator ID, join CTA.
class AppPoolCard extends StatelessWidget {
  const AppPoolCard({
    super.key,
    required this.title,
    required this.status,
    this.totalStakedFet = 0,
    this.totalMembers = 0,
    this.defaultStakeFet = 0,
    this.creatorFanId,
    this.venueName,
    this.onTap,
    this.onJoin,
  });

  final String title;
  final String status; // open, live, locked, settled, cancelled
  final int totalStakedFet;
  final int totalMembers;
  final int defaultStakeFet;
  final String? creatorFanId;
  final String? venueName;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  Color get _statusColor => switch (status) {
    'open' => FzColors.green,
    'live' => FzColors.danger,
    'locked' => FzColors.gold,
    'settled' => FzColors.cyan,
    _ => FzColors.darkMuted,
  };

  Color get _borderColor => switch (status) {
    'open' => FzColors.activeBorderCyan,
    'live' => FzColors.activeBorderRed,
    _ => FzColors.darkBorder,
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
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status + creator row
              Row(
                children: [
                  _StatusDot(color: _statusColor, label: status.toUpperCase()),
                  const Spacer(),
                  if (creatorFanId != null)
                    Text(
                      '#$creatorFanId',
                      style: FzTypography.chipLabel(
                        size: 11,
                        color: FzColors.darkMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Title
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (venueName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.store,
                      size: 13,
                      color: FzColors.darkMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        venueName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: FzColors.darkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              // Metrics row
              Row(
                children: [
                  _MetricPill(
                    icon: LucideIcons.zap,
                    value: '$totalStakedFet',
                    label: 'FET',
                    color: FzColors.orange,
                  ),
                  const SizedBox(width: 10),
                  _MetricPill(
                    icon: LucideIcons.users,
                    value: '$totalMembers',
                    color: FzColors.cyan,
                  ),
                  const SizedBox(width: 10),
                  _MetricPill(
                    icon: LucideIcons.ticket,
                    value: '$defaultStakeFet',
                    label: 'stake',
                    color: FzColors.darkMuted,
                  ),
                ],
              ),
              // Join CTA
              if (status == 'open' && onJoin != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Material(
                    color: FzColors.accent,
                    borderRadius: FzRadii.fullRadius,
                    child: InkWell(
                      onTap: onJoin,
                      borderRadius: FzRadii.fullRadius,
                      child: const Center(
                        child: Text(
                          'Join',
                          style: TextStyle(
                            color: FzColors.onAction,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: FzRadii.fullRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: FzTypography.chipLabel(size: 12, color: color)),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.value,
    required this.color,
    this.label,
  });

  final IconData icon;
  final String value;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label == null ? value : '$value $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
