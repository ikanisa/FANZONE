import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../data/team_search_database.dart';
import '../../../providers/favorite_teams_provider.dart';
import '../../../theme/colors.dart';
import '../../onboarding/widgets/fan_profile_selector.dart';

class FanProfileEditorSheet extends ConsumerWidget {
  const FanProfileEditorSheet({super.key, required this.initialTeams});

  final List<FavoriteTeamRecordDto> initialTeams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: FanProfileSelector(
          gateway: ref.read(onboardingGatewayProvider),
          initialTeams: initialTeams,
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          title: 'FAN PROFILE',
          description:
              'Edit the teams used for featured matches, pool filters, and fan context.',
          saveLabel: 'SAVE',
          onSave: (selection) async {
            await ref
                .read(onboardingGatewayProvider)
                .saveFanProfileTeams(
                  localTeam: selection.localTeam,
                  topEuropeanTeamIds: selection.topEuropeanTeamIds,
                  nationalTeamIds: selection.nationalTeamIds,
                );
            ref.invalidate(favoriteTeamRecordsProvider);
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
        ),
      ),
    );
  }
}
