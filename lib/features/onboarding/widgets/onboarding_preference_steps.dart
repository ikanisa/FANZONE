part of '../screens/onboarding_screen.dart';

class _MarketRegionStep extends ConsumerWidget {
  const _MarketRegionStep({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRegion = ref.watch(selectedLaunchRegionProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'MARKET FOCUS',
            style: FzTypography.display(size: 36, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the football market FANZONE should prioritise first. This shapes discovery and momentum cards, but never hides the rest of the game.',
            style: TextStyle(fontSize: 14, color: muted, height: 1.45),
          ),
          const SizedBox(height: 28),
          for (final region in const [
            'global',
            'africa',
            'europe',
            'north_america',
          ]) ...[
            _OnboardingChoiceCard(
              title: launchRegionLabel(region),
              subtitle: launchRegionDescription(region),
              kicker: launchRegionKicker(region),
              selected: selectedRegion == region,
              onTap: () =>
                  ref.read(selectedLaunchRegionProvider.notifier).state =
                      region,
            ),
            const SizedBox(height: 10),
          ],
          const Spacer(),
          _PrimaryButton(label: 'CONTINUE', onTap: onNext),
        ],
      ),
    );
  }
}

class _EventFocusStep extends ConsumerWidget {
  const _EventFocusStep({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTags = ref.watch(selectedLaunchFocusTagsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            '2026 FOOTBALL MOMENTUM',
            style: FzTypography.display(size: 34, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick the tournament cycles and commercial moments you care about most. These will lead your home feed and challenges first.',
            style: TextStyle(fontSize: 14, color: muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                for (final option in launchMomentOptions) ...[
                  _OnboardingChoiceCard(
                    title: option.title,
                    subtitle: option.subtitle,
                    kicker: option.kicker,
                    selected: selectedTags.contains(option.tag),
                    onTap: () => ref
                        .read(selectedLaunchFocusTagsProvider.notifier)
                        .toggle(option.tag),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          _PrimaryButton(label: 'CONTINUE', onTap: onNext),
        ],
      ),
    );
  }
}

class _OnboardingChoiceCard extends StatelessWidget {
  const _OnboardingChoiceCard({
    required this.title,
    required this.subtitle,
    required this.kicker,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String kicker;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? FzColors.accent.withValues(alpha: 0.12)
              : (isDark ? FzColors.darkSurface : FzColors.lightSurface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? FzColors.accent
                : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kicker.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: FzColors.accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: muted, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? FzColors.accent : muted,
            ),
          ],
        ),
      ),
    );
  }
}
