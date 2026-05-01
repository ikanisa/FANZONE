import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/common/fz_wordmark.dart';
import '../../../widgets/common/fz_card.dart';

class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.hasSession,
    required this.isVerified,
    required this.fanId,
    required this.isDark,
    required this.muted,
    required this.onVerifyPhone,
  });

  final bool hasSession;
  final bool isVerified;
  final String? fanId;
  final bool isDark;
  final Color muted;
  final VoidCallback onVerifyPhone;

  @override
  Widget build(BuildContext context) {
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
                label: 'Profile identity avatar',
                child: ExcludeSemantics(
                  key: const ValueKey('profile-identity-trigger'),
                  child: Container(
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
                    child: const Center(
                      child: Icon(
                        LucideIcons.fingerprint,
                        size: 34,
                        color: FzColors.primary,
                      ),
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
                          color: FzColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: fanId != null && fanId!.isNotEmpty
                              ? Text(
                                  'Fan ID $fanId',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                )
                              : hasSession
                              ? Text.rich(
                                  TextSpan(
                                    children: FzWordmark.spansForText(
                                      'FANZONE Fan',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Guest',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
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
                      child: Text(
                        isVerified ? 'Verified profile' : 'Basic profile',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isVerified ? FzColors.success : muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isVerified) ...[
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
                      color: FzColors.primary.withValues(alpha: 0.1),
                      borderRadius: FzRadii.compactRadius,
                    ),
                    child: const Text(
                      'Verify phone to unlock pools and transfers',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FzColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
