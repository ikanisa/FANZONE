import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/team_search_database.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fet_display.dart';
import '../../../widgets/match/match_list_widgets.dart';

class ProfileHeaderCard extends ConsumerWidget {
  const ProfileHeaderCard({
    super.key,
    required this.isAuthenticated,
    required this.fanId,
    required this.favoriteTeamsAsync,
    required this.profileIdentity,
    required this.isDark,
    required this.muted,
    required this.balanceAsync,
    required this.showWallet,
    required this.onSelectIdentity,
    required this.onWalletTap,
    required this.onVerifyPhone,
  });

  final bool isAuthenticated;
  final String? fanId;
  final AsyncValue<List<FavoriteTeamRecordDto>> favoriteTeamsAsync;
  final FavoriteTeamRecordDto? profileIdentity;
  final bool isDark;
  final Color muted;
  final AsyncValue<int> balanceAsync;
  final bool showWallet;
  final VoidCallback onSelectIdentity;
  final VoidCallback onWalletTap;
  final VoidCallback onVerifyPhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FzCard(
      borderRadius: FzRadii.hero,
      color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                container: true,
                button: isAuthenticated,
                label: isAuthenticated
                    ? 'Select profile identity'
                    : 'Profile identity avatar',
                child: GestureDetector(
                  key: const ValueKey('profile-identity-trigger'),
                  onTap: isAuthenticated ? onSelectIdentity : null,
                  child: ExcludeSemantics(
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDark
                                ? FzColors.darkSurface
                                : FzColors.lightSurface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? FzColors.darkBorder
                                  : FzColors.lightBorder,
                            ),
                          ),
                          child: Center(
                            child: profileIdentity != null
                                ? TeamAvatar(
                                    name: profileIdentity!.teamName,
                                    logoUrl: profileIdentity!.teamCrestUrl,
                                    size: 48,
                                  )
                                : const Text(
                                    '⚽',
                                    style: TextStyle(fontSize: 30),
                                  ),
                          ),
                        ),
                        if (isAuthenticated)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: 0,
                              child: Container(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.fingerprint,
                          size: 14,
                          color: FzColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            fanId != null && fanId!.isNotEmpty
                                ? 'Fan ID $fanId'
                                : (isAuthenticated
                                      ? 'FANZONE Member'
                                      : 'Guest'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (showWallet)
                      InkWell(
                        onTap: onWalletTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? FzColors.darkSurface
                                : FzColors.lightSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? FzColors.darkBorder
                                  : FzColors.lightBorder,
                            ),
                          ),
                          child: balanceAsync.when(
                            data: (balance) => FETDisplaySpan(
                              amount: balance,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fetColor: isDark
                                  ? FzColors.darkText
                                  : FzColors.lightText,
                              localColor: muted,
                            ),
                            loading: () => const Text(
                              'Loading wallet...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            error: (_, _) => const Text(
                              'Wallet unavailable',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!isAuthenticated) ...[
            const SizedBox(height: 14),
            Semantics(
              button: true,
              label: 'Verify phone number',
              hint: 'Opens the phone verification screen',
              child: Tooltip(
                message: 'Verify phone number',
                child: GestureDetector(
                  onTap: onVerifyPhone,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: FzColors.accent.withValues(alpha: 0.1),
                      borderRadius: FzRadii.compactRadius,
                    ),
                    child: const Text(
                      'Verify phone to unlock predictions and transfers',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FzColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                ),
              ),
            ),
            child: favoriteTeamsAsync.when(
              data: (teams) {
                if (teams.isEmpty) {
                  return Text(
                    'SUPPORTED TEAMS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 1.2,
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final team in teams)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? FzColors.darkSurface
                              : FzColors.lightSurface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: profileIdentity?.teamId == team.teamId
                                ? FzColors.accent
                                : (isDark
                                      ? FzColors.darkBorder
                                      : FzColors.lightBorder),
                            width: profileIdentity?.teamId == team.teamId
                                ? 1.4
                                : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: TeamAvatar(
                            name: team.teamName,
                            logoUrl: team.teamCrestUrl,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => Text(
                'SUPPORTED TEAMS UNAVAILABLE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
