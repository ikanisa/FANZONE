import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/team_search_database.dart';
import '../providers/onboarding_provider.dart';
import '../providers/onboarding_service.dart';
import '../../../models/user_market_preferences_model.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/region_provider.dart';
import '../../../services/market_preferences_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../core/market/launch_market.dart';
import '../../../widgets/common/team_crest.dart';

/// 7-step onboarding flow.
///
/// Step 0: Welcome — brand intro + feature highlights
/// Step 1: How it works — explain prediction, clubs, and wallet loops
/// Step 2: FET Tokens — intro to FET token system
/// Step 3: Market Focus — choose the primary launch region
/// Step 4: Event Focus — choose the major football cycles to prioritise
/// Step 5: Home Club — semantic search (SKIPPABLE)
/// Step 6: Global Clubs — region-aware global grid + search (SKIPPABLE)
///
/// Shown only once — persisted via SharedPreferences.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  static const _totalSteps = 7;

  void _next() {
    HapticFeedback.lightImpact();
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    HapticFeedback.lightImpact();
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final localTeam = ref.read(selectedLocalTeamProvider);
    final popularTeamIds = ref.read(selectedPopularTeamsProvider);
    final launchRegion = ref.read(selectedLaunchRegionProvider);
    final selectedTags = ref.read(selectedLaunchFocusTagsProvider);
    final focusTags = selectedTags.isEmpty
        ? defaultFocusTagsForRegion(launchRegion)
        : selectedTags.toList();

    await OnboardingService.saveOnboardingTeams(
      localTeam: localTeam,
      popularTeamIds: popularTeamIds,
    );
    await MarketPreferencesService.saveUserPreferences(
      UserMarketPreferences(
        primaryRegion: launchRegion,
        selectedRegions: {'global', launchRegion}.toList(),
        focusEventTags: focusTags,
        followWorldCup: focusTags.any(
          (tag) => tag.contains('world-cup') || tag == 'worldcup2026',
        ),
        followChampionsLeague: focusTags.contains('ucl-final-2026'),
        updatedAt: DateTime.now(),
      ),
    );
    ref.invalidate(userMarketPreferencesProvider);
    ref.invalidate(userRegionProvider);
    ref.invalidate(homeLaunchEventsProvider);
    ref.invalidate(spotlightChallengesProvider);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: Stack(
        children: [
          // Background glow orbs
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    FzColors.accent.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    FzColors.violet.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _buildStep(textColor, muted, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(Color textColor, Color muted, bool isDark) {
    switch (_currentStep) {
      case 0:
        return _WelcomeStep(
          key: const ValueKey(0),
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          onNext: _next,
        );
      case 1:
        return _FeaturesStep(
          key: const ValueKey(1),
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          onNext: _next,
        );
      case 2:
        return _PredictStep(
          key: const ValueKey(2),
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          onNext: _next,
        );
      case 3:
        return _MarketRegionStep(
          key: const ValueKey(3),
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          onNext: _next,
        );
      case 4:
        return _EventFocusStep(
          key: const ValueKey(4),
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          onNext: _next,
        );
      case 5:
        return _FavoriteTeamStep(
          key: const ValueKey(5),
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          onNext: _next,
          onSkip: _skip,
        );
      case 6:
        return _PopularTeamsStep(
          key: const ValueKey(6),
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          onComplete: _completeOnboarding,
          onSkip: _completeOnboarding,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Step 0: Welcome
// ─────────────────────────────────────────────────────────────

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
          // Logo mark
          Image.asset('assets/images/logo.png', width: 72, height: 72),
          const SizedBox(height: 16),
          // Brand
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'FAN',
                  style: FzTypography.display(
                    size: 64,
                    color: FzColors.maltaRed,
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

          // Feature bullets
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

// ─────────────────────────────────────────────────────────────
// Step 1: Features
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// Step 2: FET Tokens
// ─────────────────────────────────────────────────────────────

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

          // Token info card
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

// ─────────────────────────────────────────────────────────────
// Step 3: Market region
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// Step 4: Event focus
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// Step 5: Favorite Team (Home club — semantic search)
// ─────────────────────────────────────────────────────────────

class _FavoriteTeamStep extends ConsumerStatefulWidget {
  const _FavoriteTeamStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onNext,
    required this.onSkip,
  });
  final Color textColor;
  final Color muted;
  final bool isDark;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  ConsumerState<_FavoriteTeamStep> createState() => _FavoriteTeamStepState();
}

class _FavoriteTeamStepState extends ConsumerState<_FavoriteTeamStep> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(localTeamSearchResultsProvider);
    final selectedTeam = ref.watch(selectedLocalTeamProvider);
    final query = ref.watch(localTeamSearchQueryProvider);
    final hasSelection = selectedTeam != null;
    final showResults = query.isNotEmpty && !hasSelection;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Brand header
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'FAN',
                  style: FzTypography.display(
                    size: 36,
                    color: FzColors.maltaRed,
                    letterSpacing: 3,
                  ),
                ),
                TextSpan(
                  text: 'ZONE',
                  style: FzTypography.display(
                    size: 36,
                    color: widget.textColor,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Home Club',
            style: FzTypography.display(
              size: 28,
              color: widget.textColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick the club closest to your football identity in your market. You can skip this and adjust later.',
            style: TextStyle(fontSize: 14, color: widget.muted, height: 1.5),
          ),

          const SizedBox(height: 24),

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: widget.isDark
                  ? FzColors.darkSurface2
                  : FzColors.lightSurface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? FzColors.accent.withValues(alpha: 0.5)
                    : widget.isDark
                    ? FzColors.darkBorder
                    : FzColors.lightBorder,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: (value) {
                ref.read(localTeamSearchQueryProvider.notifier).state = value;
                if (hasSelection) {
                  ref.read(selectedLocalTeamProvider.notifier).state = null;
                }
              },
              style: TextStyle(
                fontSize: 15,
                color: widget.textColor,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search clubs from Africa, Europe, and North America',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: widget.muted.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 20,
                  color: widget.muted,
                ),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          size: 18,
                          color: widget.muted,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          ref
                                  .read(localTeamSearchQueryProvider.notifier)
                                  .state =
                              '';
                          ref.read(selectedLocalTeamProvider.notifier).state =
                              null;
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          if (!showResults && !hasSelection) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Start typing to find your team',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.muted.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Search results
          if (showResults)
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'No teams found for "$query"',
                        style: TextStyle(fontSize: 13, color: widget.muted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final team = results[index];
                        return _TeamSearchResult(
                          team: team,
                          isDark: widget.isDark,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(selectedLocalTeamProvider.notifier).state =
                                team;
                            _searchController.text = team.name;
                            _focusNode.unfocus();
                          },
                        );
                      },
                    ),
            ),

          // Selected team card
          if (hasSelection) ...[
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'YOUR SELECTION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.muted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SelectedTeamCard(
                    team: selectedTeam,
                    isDark: widget.isDark,
                    textColor: widget.textColor,
                    muted: widget.muted,
                    onRemove: () {
                      ref.read(selectedLocalTeamProvider.notifier).state = null;
                      _searchController.clear();
                      ref.read(localTeamSearchQueryProvider.notifier).state =
                          '';
                    },
                  ),
                ],
              ),
            ),
          ],

          if (!showResults && !hasSelection) const Spacer(),

          // Buttons
          const SizedBox(height: 16),
          if (hasSelection)
            _PrimaryButton(label: 'CONTINUE', onTap: widget.onNext)
          else
            _SecondaryButton(label: 'SKIP THIS STEP', onTap: widget.onSkip),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Step 6: Global clubs (Grid + Search)
// ─────────────────────────────────────────────────────────────

class _PopularTeamsStep extends ConsumerStatefulWidget {
  const _PopularTeamsStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onComplete,
    required this.onSkip,
  });
  final Color textColor;
  final Color muted;
  final bool isDark;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  ConsumerState<_PopularTeamsStep> createState() => _PopularTeamsStepState();
}

class _PopularTeamsStepState extends ConsumerState<_PopularTeamsStep> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = ref.watch(selectedLaunchRegionProvider);
    final popular = popularTeamsForRegion(region);
    final selectedIds = ref.watch(selectedPopularTeamsProvider);
    final searchQuery = ref.watch(popularTeamSearchQueryProvider);
    final searchResults = ref.watch(popularTeamSearchResultsProvider);
    final hasSelections = selectedIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const SizedBox(height: 8),
          Text(
            'GLOBAL CLUBS',
            style: FzTypography.display(
              size: 32,
              color: widget.textColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose the global clubs you want near the top after launch',
            style: TextStyle(fontSize: 14, color: widget.muted),
          ),

          const SizedBox(height: 20),

          // Team grid
          Expanded(
            child: ListView(
              children: [
                // Grid of popular teams (5 per row)
                _buildTeamGrid(popular, selectedIds),

                const SizedBox(height: 24),

                // "Didn't find your favorite team?"
                Center(
                  child: Column(
                    children: [
                      Text(
                        "Didn't find your favorite team?",
                        style: TextStyle(fontSize: 13, color: widget.muted),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Search more',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FzColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? FzColors.darkSurface2
                        : FzColors.lightSurface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      ref.read(popularTeamSearchQueryProvider.notifier).state =
                          value;
                    },
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search more teams',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: widget.muted.withValues(alpha: 0.7),
                      ),
                      prefixIcon: Icon(
                        LucideIcons.search,
                        size: 20,
                        color: widget.muted,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                LucideIcons.x,
                                size: 18,
                                color: widget.muted,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                        .read(
                                          popularTeamSearchQueryProvider
                                              .notifier,
                                        )
                                        .state =
                                    '';
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                if (searchQuery.isNotEmpty)
                  ...searchResults.map(
                    (team) => _TeamSearchResult(
                      team: team,
                      isDark: widget.isDark,
                      selected: selectedIds.contains(team.id),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(selectedPopularTeamsProvider.notifier)
                            .toggle(team.id);
                      },
                    ),
                  ),

                if (searchQuery.isNotEmpty && searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No teams found for "$searchQuery"',
                        style: TextStyle(fontSize: 13, color: widget.muted),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // Buttons
          if (hasSelections)
            _PrimaryButton(label: 'COMPLETE SETUP', onTap: widget.onComplete)
          else
            _SecondaryButton(label: 'SKIP FOR NOW', onTap: widget.onSkip),
        ],
      ),
    );
  }

  Widget _buildTeamGrid(List<OnboardingTeam> teams, Set<String> selectedIds) {
    final rows = <Widget>[];
    for (int i = 0; i < teams.length; i += 5) {
      final rowTeams = teams.sublist(
        i,
        i + 5 > teams.length ? teams.length : i + 5,
      );
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rowTeams.map((team) {
              final isSelected = selectedIds.contains(team.id);
              return _TeamGridItem(
                team: team,
                isSelected: isSelected,
                isDark: widget.isDark,
                textColor: widget.textColor,
                muted: widget.muted,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(selectedPopularTeamsProvider.notifier)
                      .toggle(team.id);
                },
              );
            }).toList(),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

// ─────────────────────────────────────────────────────────────
// Team Grid Item (for Popular Teams grid)
// ─────────────────────────────────────────────────────────────

class _TeamGridItem extends StatelessWidget {
  const _TeamGridItem({
    required this.team,
    required this.isSelected,
    required this.isDark,
    required this.textColor,
    required this.muted,
    required this.onTap,
  });

  final OnboardingTeam team;
  final bool isSelected;
  final bool isDark;
  final Color textColor;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? FzColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: FzColors.accent, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Crest circle
            TeamCrest(
              label: team.shortName,
              crestUrl: team.resolvedCrestUrl,
              fallbackEmoji: team.logoEmoji,
              size: 40,
              backgroundColor: isDark
                  ? FzColors.darkSurface2
                  : FzColors.lightSurface2,
              borderColor: isSelected
                  ? FzColors.accent
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
              borderWidth: 1.5,
              textColor: isSelected ? FzColors.accent : muted,
            ),
            const SizedBox(height: 4),
            Text(
              team.shortName,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isSelected ? FzColors.accent : muted,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Team Search Result Row
// ─────────────────────────────────────────────────────────────

class _TeamSearchResult extends StatelessWidget {
  const _TeamSearchResult({
    required this.team,
    required this.isDark,
    this.selected = false,
    required this.onTap,
  });

  final OnboardingTeam team;
  final bool isDark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected
              ? FzColors.accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(
                  color: FzColors.accent.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          children: [
            // Crest circle with flag
            TeamCrest(
              label: team.shortName,
              crestUrl: team.resolvedCrestUrl,
              fallbackEmoji: team.logoEmoji,
              size: 38,
              backgroundColor: isDark
                  ? FzColors.darkSurface2
                  : FzColors.lightSurface2,
              borderColor: selected
                  ? FzColors.accent
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
              textColor: selected ? FzColors.accent : muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? FzColors.accent
                          : (isDark ? FzColors.darkText : FzColors.lightText),
                    ),
                  ),
                  Text(
                    '${team.country} · ${team.league}',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: FzColors.accent,
                ),
                child: const Icon(
                  LucideIcons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Selected Team Card (for "Your Selection" display)
// ─────────────────────────────────────────────────────────────

class _SelectedTeamCard extends StatelessWidget {
  const _SelectedTeamCard({
    required this.team,
    required this.isDark,
    required this.textColor,
    required this.muted,
    required this.onRemove,
  });

  final OnboardingTeam team;
  final bool isDark;
  final Color textColor;
  final Color muted;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FzColors.accent.withValues(alpha: 0.15),
            FzColors.violet.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FzColors.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Team crest
          TeamCrest(
            label: team.shortName,
            crestUrl: team.resolvedCrestUrl,
            fallbackEmoji: team.logoEmoji,
            size: 64,
            backgroundColor: isDark
                ? FzColors.darkSurface
                : FzColors.lightSurface,
            borderColor: FzColors.accent.withValues(alpha: 0.4),
            borderWidth: 2,
            textColor: FzColors.accent,
          ),
          const SizedBox(height: 12),
          Text(
            team.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${team.country} · ${team.league}',
            style: TextStyle(fontSize: 12, color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: FzColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.x, size: 14, color: FzColors.error),
                  SizedBox(width: 4),
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FzColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared Sub-Widgets
// ─────────────────────────────────────────────────────────────

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
