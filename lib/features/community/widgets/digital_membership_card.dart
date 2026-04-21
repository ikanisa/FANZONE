import 'package:flutter/material.dart';

import '../../../models/team_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_wordmark.dart';
import '../../../widgets/match/match_list_widgets.dart';

/// Digital membership card aligned to the original FANZONE membership card.
class DigitalMembershipCard extends StatelessWidget {
  const DigitalMembershipCard({
    super.key,
    required this.activeClub,
    required this.fanId,
    required this.membershipTier,
    required this.clubSplit,
  });

  final TeamModel? activeClub;
  final String? fanId;
  final String membershipTier;
  final int clubSplit;

  @override
  Widget build(BuildContext context) {
    final formattedFanId = fanId == null || fanId!.length < 6
        ? '— — —'
        : fanId!;
    final accent = switch (membershipTier.toLowerCase()) {
      'legend' => const Color(0xFFE0393E),
      'ultra' => const Color(0xFFFFD32A),
      'member' => FzColors.primary,
      _ => const Color(0xFF6070A0),
    };

    return FzCard(
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 1.6,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withValues(alpha: 0.25), const Color(0xFF0D0A27)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -52,
                right: -52,
                child: _GlowOrb(color: accent.withValues(alpha: 0.28)),
              ),
              Positioned(
                bottom: -52,
                left: -52,
                child: _GlowOrb(color: accent.withValues(alpha: 0.18)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activeClub != null)
                        TeamAvatar(
                          name: activeClub!.name,
                          logoUrl: activeClub!.logoUrl ?? activeClub!.crestUrl,
                          size: 48,
                        )
                      else
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '🏟️',
                            style: TextStyle(fontSize: 22),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeClub?.name ?? 'FANZONE Supporter',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FzTypography.display(
                                size: 22,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Official Fan Club',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white60,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          membershipTier.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fan ID',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedFanId,
                        style: FzTypography.score(
                          size: 28,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Member Since',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.white54,
                                  letterSpacing: 0.9,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'OCT 2023',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '$clubSplit% CLUB',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text.rich(
                            TextSpan(
                              children: FzWordmark.spansForText(
                                'FANZONE',
                                style: FzTypography.display(
                                  size: 22,
                                  color: Colors.white.withValues(alpha: 0.18),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
