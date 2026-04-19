import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/team_search_database.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../providers/profile_identity_provider.dart';

Future<void> showProfileIdentityPicker(
  BuildContext context,
  WidgetRef ref, {
  required List<FavoriteTeamRecordDto> teams,
  required String? selectedTeamId,
}) async {
  HapticFeedback.selectionClick();
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
      final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
      final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: FzRadii.heroRadius,
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: InkWell(
                  onTap: () => Navigator.of(sheetContext).pop(),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? FzColors.darkSurface
                          : FzColors.lightSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: border),
                    ),
                    child: Icon(LucideIcons.x, size: 16, color: muted),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select Identity',
                style: FzTypography.display(
                  size: 22,
                  color: isDark ? FzColors.darkText : FzColors.lightText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a supported team logo as your primary profile picture.',
                style: TextStyle(fontSize: 12, color: muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              if (teams.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FzColors.darkSurface
                        : FzColors.lightSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    'You need to support a team first.\nAdd a team during onboarding to change your logo.',
                    style: TextStyle(fontSize: 12, color: muted, height: 1.45),
                  ),
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final team in teams)
                      GestureDetector(
                        onTap: () async {
                          await ref
                              .read(profileIdentityProvider.notifier)
                              .setSelectedTeam(team);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: selectedTeamId == team.teamId
                                ? FzColors.accent.withValues(alpha: 0.1)
                                : (isDark
                                      ? FzColors.darkSurface
                                      : FzColors.lightSurface),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selectedTeamId == team.teamId
                                  ? FzColors.accent
                                  : border,
                            ),
                            boxShadow: selectedTeamId == team.teamId
                                ? [
                                    BoxShadow(
                                      color: FzColors.accent.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: TeamAvatar(
                              name: team.teamName,
                              logoUrl: team.teamCrestUrl,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}
