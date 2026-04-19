import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../core/market/launch_market.dart';
import '../../../models/user_market_preferences_model.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/region_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/fz_glass_loader.dart';

class MarketPreferencesScreen extends ConsumerStatefulWidget {
  const MarketPreferencesScreen({super.key});

  @override
  ConsumerState<MarketPreferencesScreen> createState() =>
      _MarketPreferencesScreenState();
}

class _MarketPreferencesScreenState
    extends ConsumerState<MarketPreferencesScreen> {
  String? _primaryRegion;
  Set<String> _secondaryRegions = const <String>{};
  Set<String> _focusTags = const <String>{};
  bool _initialized = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MARKET PREFERENCES',
          style: FzTypography.display(size: 24, color: textColor),
        ),
      ),
      body: ref
          .watch(userMarketPreferencesProvider)
          .when(
            data: (preferences) => _buildContent(context, preferences, isDark),
            loading: () => const FzGlassLoader(message: 'Syncing...'),
            error: (_, _) => StateView.error(
              title: 'Could not load market preferences',
              onRetry: () => ref.invalidate(userMarketPreferencesProvider),
            ),
          ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    UserMarketPreferences preferences,
    bool isDark,
  ) {
    if (!_initialized) {
      _primaryRegion = normalizeRegionKey(preferences.primaryRegion);
      _secondaryRegions = preferences.effectiveRegions.toSet()
        ..remove('global')
        ..remove(_primaryRegion);
      _focusTags = preferences.focusEventTags.toSet();
      _initialized = true;
    }

    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final primaryRegion = _primaryRegion ?? preferences.primaryRegion;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        FzCard(
          padding: const EdgeInsets.all(18),
          borderColor: FzColors.accent.withValues(alpha: 0.22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Global launch without fragmentation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the football markets and major moments you want FANZONE to prioritise first. This only changes ranking, home modules, and discovery emphasis.',
                style: TextStyle(fontSize: 12, color: muted, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'PRIMARY MARKET',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final region in const [
              'global',
              'africa',
              'europe',
              'north_america',
            ])
              _PreferenceChip(
                label: launchRegionLabel(region),
                subtitle: launchRegionKicker(region),
                selected: primaryRegion == region,
                onTap: () => setState(() => _primaryRegion = region),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          launchRegionDescription(primaryRegion),
          style: TextStyle(fontSize: 12, color: muted, height: 1.45),
        ),
        const SizedBox(height: 24),
        Text(
          'ALSO FOLLOW',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final region in const ['africa', 'europe', 'north_america'])
              if (region != primaryRegion)
                FilterChip(
                  label: Text(launchRegionLabel(region)),
                  selected: _secondaryRegions.contains(region),
                  onSelected: (_) => setState(() {
                    if (_secondaryRegions.contains(region)) {
                      _secondaryRegions = {..._secondaryRegions}
                        ..remove(region);
                    } else {
                      _secondaryRegions = {..._secondaryRegions, region};
                    }
                  }),
                ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'TOURNAMENT FOCUS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        for (final option in launchMomentOptionsForRuntime()) ...[
          FzCard(
            onTap: () => setState(() {
              if (_focusTags.contains(option.tag)) {
                _focusTags = {..._focusTags}..remove(option.tag);
              } else {
                _focusTags = {..._focusTags, option.tag};
              }
            }),
            padding: const EdgeInsets.all(16),
            borderColor: _focusTags.contains(option.tag)
                ? FzColors.accent.withValues(alpha: 0.45)
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.kicker.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: FzColors.accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        option.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  _focusTags.contains(option.tag)
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: _focusTags.contains(option.tag)
                      ? FzColors.accent
                      : muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : () => _save(context),
            child: Text(_saving ? 'Saving...' : 'Save Preferences'),
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    final primaryRegion = _primaryRegion ?? 'global';
    final focusTags = _focusTags.isEmpty
        ? defaultFocusTagsForRegion(primaryRegion)
        : _focusTags.toList();
    final nextPreferences = UserMarketPreferences(
      primaryRegion: primaryRegion,
      selectedRegions: {'global', primaryRegion, ..._secondaryRegions}.toList(),
      focusEventTags: focusTags,
      followWorldCup: focusTags.any(
        (tag) => tag.contains('world-cup') || tag == 'worldcup2026',
      ),
      followChampionsLeague: focusTags.contains('ucl-final-2026'),
      updatedAt: DateTime.now(),
    );

    setState(() => _saving = true);
    await ref.read(marketPreferencesGatewayProvider).saveUserMarketPreferences(
      nextPreferences,
    );
    ref.invalidate(userMarketPreferencesProvider);
    ref.invalidate(userRegionProvider);
    ref.invalidate(homeLaunchEventsProvider);
    ref.invalidate(spotlightChallengesProvider);
    if (!context.mounted) return;

    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Market preferences updated')));
    context.pop();
  }
}

class _PreferenceChip extends StatelessWidget {
  const _PreferenceChip({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? FzColors.accent.withValues(alpha: 0.12)
              : (isDark ? FzColors.darkSurface : FzColors.lightSurface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? FzColors.accent
                : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? FzColors.accent
                    : (isDark ? FzColors.darkText : FzColors.lightText),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: muted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
