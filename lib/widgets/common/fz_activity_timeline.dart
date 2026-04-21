import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Vertical activity timeline matching the reference `ActivityTimeline.tsx`.
///
/// Displays a list of timestamped activities with dot markers and a
/// connecting vertical line.
class FzActivityTimeline extends StatelessWidget {
  const FzActivityTimeline({super.key, required this.activities});

  final List<FzTimelineActivity> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: activities.asMap().entries.map((entry) {
        final i = entry.key;
        final activity = entry.value;
        final isLast = i == activities.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline column (dot + line)
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: activity.color ?? FzColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          color: FzColors.darkBorder.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Content column
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.timestamp,
                        style: FzTypography.metaLabel(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activity.action,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FzColors.darkText,
                        ),
                      ),
                      if (activity.actor != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          'by ${activity.actor}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: FzColors.darkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Data class for a single timeline activity.
class FzTimelineActivity {
  const FzTimelineActivity({
    required this.timestamp,
    required this.action,
    this.actor,
    this.color,
  });

  final String timestamp;
  final String action;
  final String? actor;
  final Color? color;
}
