import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/team/team_widgets.dart';
import '../../../widgets/common/fz_glass_loader.dart';

/// Individual team news article detail view.
class TeamNewsDetailScreen extends ConsumerWidget {
  const TeamNewsDetailScreen({
    super.key,
    required this.teamId,
    required this.newsId,
  });

  final String teamId;
  final String newsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(teamNewsDetailProvider(newsId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return newsAsync.when(
      data: (article) {
        if (article == null) {
          return Scaffold(
            appBar: AppBar(),
            body: StateView.empty(
              title: 'Article not found',
              subtitle: 'This article may have been removed.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            actions: [
              if (article.sourceUrl != null)
                IconButton(
                  onPressed: () =>
                      SharePlus.instance.share(ShareParams(text: article.sourceUrl!)),
                  icon: const Icon(Icons.share_rounded, size: 20),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // Category + AI badge
              Row(
                children: [
                  TeamNewsCategoryChip(category: article.category),
                  if (article.isAiCurated) ...[
                    const SizedBox(width: 10),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sparkles, size: 13, color: FzColors.violet),
                        SizedBox(width: 4),
                        Text(
                          'AI Curated',
                          style: TextStyle(
                            fontSize: 11,
                            color: FzColors.violet,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              // Metadata row
              Row(
                children: [
                  if (article.sourceName != null) ...[
                    const Icon(LucideIcons.globe, size: 13, color: FzColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      article.sourceName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FzColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (article.publishedAt != null)
                    Text(
                      _formatDate(article.publishedAt!),
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                ],
              ),

              const SizedBox(height: 24),
              Divider(color: isDark ? FzColors.darkBorder : FzColors.lightBorder),
              const SizedBox(height: 24),

              // Summary
              if (article.summary != null && article.summary!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FzColors.primary.withValues(alpha: isDark ? 0.06 : 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: FzColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    article.summary!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? FzColors.darkText : FzColors.lightText,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Full content
              if (article.content != null && article.content!.isNotEmpty)
                Text(
                  article.content!,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? FzColors.darkText : FzColors.lightText,
                    height: 1.7,
                  ),
                ),

              // Source attribution
              if (article.sourceUrl != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.externalLink, size: 14, color: muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Source: ${article.sourceName ?? article.sourceUrl}',
                          style: TextStyle(fontSize: 12, color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: FzGlassLoader(message: 'Syncing...'),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: StateView.error(
          title: 'Article unavailable',
          onRetry: () => ref.invalidate(teamNewsDetailProvider(newsId)),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
