import 'package:flutter/material.dart';
import '../../models/standing_row_model.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../common/fz_card.dart';
import 'match_list_widgets.dart';

class StandingsTable extends StatelessWidget {
  const StandingsTable({
    super.key,
    required this.rows,
    this.highlightTeamIds = const {},
    this.onTapTeam,
  });

  final List<StandingRowModel> rows;
  final Set<String> highlightTeamIds;
  final ValueChanged<String>? onTapTeam;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final borderColor = isDark ? FzColors.darkBorder : FzColors.lightBorder;

    return FzCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '#',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Team',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    'P',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    'GD',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    'Pts',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) Divider(height: 0.5, color: borderColor),
            _StandingRow(
              row: rows[index],
              highlight:
                  rows[index].teamId != null &&
                  highlightTeamIds.contains(rows[index].teamId),
              onTap: rows[index].teamId != null && onTapTeam != null
                  ? () => onTapTeam!(rows[index].teamId!)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.row, required this.highlight, this.onTap});

  final StandingRowModel row;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: highlight ? FzColors.accent.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${row.position}',
                style: FzTypography.scoreCompact(color: muted),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  TeamAvatar(name: row.teamName, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.teamName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: highlight
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '${row.played}',
                textAlign: TextAlign.center,
                style: FzTypography.scoreCompact(color: textColor),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${row.goalDifference > 0 ? '+' : ''}${row.goalDifference}',
                textAlign: TextAlign.center,
                style: FzTypography.scoreCompact(
                  color: row.goalDifference >= 0
                      ? textColor
                      : FzColors.maltaRed,
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${row.points}',
                textAlign: TextAlign.center,
                style: FzTypography.scoreCompact(color: FzColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
