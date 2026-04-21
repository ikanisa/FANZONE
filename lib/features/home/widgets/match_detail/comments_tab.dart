part of '../../screens/match_detail_screen.dart';

class _CommentsTab extends StatelessWidget {
  const _CommentsTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final text = isDark ? FzColors.darkText : FzColors.lightText;

    final comments = <({String fanId, String ago, String body})>[
      (
        fanId: '#992012',
        ago: '2m ago',
        body:
            '${match.awayTeam} look sharp already. This one is going all the way.',
      ),
      (
        fanId: '#110901',
        ago: '5m ago',
        body:
            '${match.homeTeam} should control midfield here. Calling the opener before halftime.',
      ),
    ];

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          itemCount: comments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final comment = comments[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.fanId,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: text,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        comment.ago,
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    comment.body,
                    style: TextStyle(fontSize: 14, color: text, height: 1.5),
                  ),
                ],
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: surface.withValues(alpha: 0.92),
              border: Border(top: BorderSide(color: border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Add a comment...',
                        style: TextStyle(fontSize: 14, color: muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: FzColors.primary,
                      foregroundColor: FzColors.darkBg,
                      minimumSize: const Size(82, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Post',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
