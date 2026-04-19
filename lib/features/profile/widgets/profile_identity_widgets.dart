import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../data/team_search_database.dart';
import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
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
      borderRadius: 28,
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
                                ? 'Fan ID: $fanId'
                                : (isAuthenticated
                                      ? 'FANZONE Member'
                                      : 'Guest'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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
                            data: (balance) {
                              final currency =
                                  ref.watch(userCurrencyProvider).valueOrNull ??
                                  'EUR';
                              return Text(
                                formatFET(balance, currency),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
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
                      borderRadius: BorderRadius.circular(20),
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
          favoriteTeamsAsync.when(
            data: (teams) {
              if (teams.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    'Supported teams',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Wrap(
                  alignment: WrapAlignment.center,
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
                            size: 28,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'Supported teams unavailable',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
