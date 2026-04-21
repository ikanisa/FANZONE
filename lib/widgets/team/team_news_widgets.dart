import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/team_news_model.dart';
import '../../theme/colors.dart';
import '../common/fz_animated_entry.dart';
import '../common/fz_card.dart';
import 'team_widget_utils.dart';

class TeamNewsCard extends StatelessWidget {
  const TeamNewsCard({
    super.key,
    required this.news,
    this.onTap,
    this.index = 0,
  });

  final TeamNewsModel news;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzAnimatedEntry(
      index: index,
      child: FzCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TeamNewsCategoryChip(category: news.category),
                const Spacer(),
                if (news.isAiCurated)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        size: 12,
                        color: FzColors.secondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'AI Curated',
                        style: TextStyle(
                          fontSize: 10,
                          color: FzColors.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              news.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (news.summary != null) ...[
              const SizedBox(height: 6),
              Text(
                news.summary!,
                style: TextStyle(fontSize: 14, color: muted, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (news.sourceName != null)
                  Text(
                    news.sourceName!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: FzColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const Spacer(),
                if (news.publishedAt != null)
                  Text(
                    formatTeamRelativeTime(news.publishedAt!),
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TeamNewsCategoryChip extends StatelessWidget {
  const TeamNewsCategoryChip({
    super.key,
    required this.category,
    this.onTap,
    this.selected = false,
  });

  final String category;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? FzColors.primary.withValues(alpha: 0.15)
              : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? FzColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          TeamNewsCategory.label(category),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected
                ? FzColors.primary
                : (isDark ? FzColors.darkMuted : FzColors.lightMuted),
          ),
        ),
      ),
    );
  }
}
