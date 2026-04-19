part of '../screens/onboarding_screen.dart';

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onNext,
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const FzBrandLogo(width: 72, height: 72, preferCdn: true),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'FAN',
                  style: FzTypography.display(
                    size: 64,
                    color: textColor,
                    letterSpacing: 4,
                  ),
                ),
                TextSpan(
                  text: 'ZONE',
                  style: FzTypography.display(
                    size: 64,
                    color: textColor,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'PREDICT. EARN. REPEAT.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: FzColors.accent,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 40),
          _FeatureBullet(
            icon: LucideIcons.zap,
            title: 'Free Matchday Slips',
            description:
                'Lock predictions first, then move into pools when you want FET at stake across Africa, Europe, and North America.',
            isDark: isDark,
            textColor: textColor,
            muted: muted,
          ),
          const SizedBox(height: 16),
          _FeatureBullet(
            icon: LucideIcons.users,
            title: 'Clubs & Fan Zones',
            description:
                'Join supporter communities, build your registry, and follow clubs from local and global football markets.',
            isDark: isDark,
            textColor: textColor,
            muted: muted,
          ),
          const SizedBox(height: 16),
          _FeatureBullet(
            icon: LucideIcons.wallet,
            title: 'FET Wallet + Fan ID',
            description:
                'Transfer by Fan ID, support clubs, and redeem rewards from one wallet.',
            isDark: isDark,
            textColor: textColor,
            muted: muted,
          ),
          const Spacer(),
          _PrimaryButton(label: 'GET STARTED', onTap: onNext),
        ],
      ),
    );
  }
}

class _FeaturesStep extends StatelessWidget {
  const _FeaturesStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onNext,
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'HOW IT WORKS',
            style: FzTypography.display(size: 36, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Three simple steps to start predicting, joining clubs, and moving FET.',
            style: TextStyle(fontSize: 14, color: muted),
          ),
          const SizedBox(height: 32),
          _NumberedStep(
            number: '1',
            title: 'Pick Your Matches',
            description:
                'Use the Matchday Hub to find prediction-ready fixtures, launch moments, and regional storylines. Scores remain supporting information.',
            isDark: isDark,
            textColor: textColor,
            muted: muted,
          ),
          const SizedBox(height: 20),
          _NumberedStep(
            number: '2',
            title: 'Join Clubs + Pools',
            description:
                'Build your supporter registry, then enter pools or challenges around the World Cup cycle, Champions League final, and your fan communities.',
            isDark: isDark,
            textColor: textColor,
            muted: muted,
          ),
          const SizedBox(height: 20),
          _NumberedStep(
            number: '3',
            title: 'Grow Your Wallet',
            description:
                'Use Fan ID for transfers, support clubs with FET, and unlock rewards as your activity grows.',
            isDark: isDark,
            textColor: textColor,
            muted: muted,
          ),
          const Spacer(),
          _PrimaryButton(label: 'CONTINUE', onTap: onNext),
        ],
      ),
    );
  }
}

class _PredictStep extends StatelessWidget {
  const _PredictStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onNext,
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'FET TOKENS',
            style: FzTypography.display(size: 36, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Your prediction, club, and reward currency.',
            style: TextStyle(fontSize: 14, color: muted),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FzColors.accent, FzColors.violet],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.wallet,
                      size: 20,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FET',
                      style: FzTypography.score(
                        size: 32,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fan Engagement Tokens',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'FET moves through FANZONE in three directions: pools and challenges, club support, and Fan ID transfers. Rewards and redemptions stay on top of the same wallet as the product expands across markets.',
            style: TextStyle(fontSize: 14, color: muted, height: 1.6),
          ),
          const Spacer(),
          _PrimaryButton(label: 'ALMOST THERE', onTap: onNext),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isDark;
  final Color textColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
            border: Border.all(
              color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
            ),
          ),
          child: Icon(icon, size: 20, color: FzColors.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(description, style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({
    required this.number,
    required this.title,
    required this.description,
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  final String number;
  final String title;
  final String description;
  final bool isDark;
  final Color textColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: FzColors.accent.withValues(alpha: 0.1),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: FzColors.accent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: FzColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronRight, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: muted,
          side: BorderSide(color: muted.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
