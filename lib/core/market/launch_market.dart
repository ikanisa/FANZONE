/// LaunchMarket — region and marketing moment utilities.
///
/// Pure utility functions that do NOT depend on any hardcoded static data.
/// Country-to-region resolution is now delegated to [BootstrapConfig]
/// (backed by the `country_region_map` Supabase table).
/// Launch moment options are loaded from the `launch_moments` table.
library;

import '../config/runtime_bootstrap.dart';

enum LaunchRegion { africa, europe, northAmerica, global }

String normalizeRegionKey(String? raw) {
  final value = raw
      ?.trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');

  switch (value) {
    case 'africa':
      return 'africa';
    case 'europe':
      return 'europe';
    case 'americas':
    case 'north_america':
    case 'northamerica':
      return 'north_america';
    case 'global':
    case null:
    case '':
      return 'global';
    default:
      return 'global';
  }
}

LaunchRegion launchRegionFromKey(String? raw) {
  switch (normalizeRegionKey(raw)) {
    case 'africa':
      return LaunchRegion.africa;
    case 'europe':
      return LaunchRegion.europe;
    case 'north_america':
      return LaunchRegion.northAmerica;
    default:
      return LaunchRegion.global;
  }
}

String launchRegionLabel(String? raw) {
  switch (normalizeRegionKey(raw)) {
    case 'africa':
      return 'Africa';
    case 'europe':
      return 'Europe';
    case 'north_america':
      return 'North America';
    default:
      return 'Global';
  }
}

String launchRegionKicker(String? raw) {
  switch (normalizeRegionKey(raw)) {
    case 'africa':
      return 'African momentum';
    case 'europe':
      return 'European run-in';
    case 'north_america':
      return 'North America host cycle';
    default:
      return 'Global football cycle';
  }
}

String launchRegionDescription(String? raw) {
  switch (normalizeRegionKey(raw)) {
    case 'africa':
      return 'Prioritise African club communities, supporter growth, and continent-first discovery.';
    case 'europe':
      return 'Keep UEFA club football and final-stage competition discovery near the top of the app.';
    case 'north_america':
      return 'Focus on USA, Canada, and Mexico host-market momentum as the World Cup approaches.';
    default:
      return 'Blend Africa, Europe, and North America into one football product without locking any content.';
  }
}

List<String> queryRegionVariants(String? raw) {
  final normalized = normalizeRegionKey(raw);
  switch (normalized) {
    case 'north_america':
      return const ['north_america', 'americas'];
    case 'global':
      return const ['global'];
    default:
      return [normalized];
  }
}

bool regionKeyMatches(String? candidate, String? target) {
  final left = normalizeRegionKey(candidate);
  final right = normalizeRegionKey(target);
  if (right == 'global') return true;
  if (left == 'global') return true;
  if (left == right) return true;
  return queryRegionVariants(
    left,
  ).toSet().intersection(queryRegionVariants(right).toSet()).isNotEmpty;
}

/// DEPRECATED — use BootstrapConfig.regionForCountryCode() with country codes.
///
/// This function resolves region from a country *name* (e.g. "Test Country"),
/// kept for backward compatibility with `CompetitionModel.country` which
/// stores the country name (not a 2-letter code).
///
/// New code should use the country_code-based BootstrapConfig lookup.
String? regionFromCountryName(String? country) {
  if (country == null || country.trim().isEmpty) return null;
  final runtimeConfig = runtimeBootstrapStore.config;
  for (final info in runtimeConfig.regions.values) {
    if (info.countryName.toLowerCase() == country.trim().toLowerCase()) {
      return info.region;
    }
  }
  return null;
}

/// LaunchMomentOption — kept for backward compatibility.
///
/// New code should use [LaunchMomentInfo] from bootstrap_config.dart
/// (backed by the `launch_moments` Supabase table).
class LaunchMomentOption {
  const LaunchMomentOption({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.kicker,
    required this.regionKey,
  });

  final String tag;
  final String title;
  final String subtitle;
  final String kicker;
  final String regionKey;
}

/// DEPRECATED — Use BootstrapConfig.launchMoments instead.
///
/// This list is kept as an emergency offline fallback only.
/// The canonical source of truth is now the `launch_moments` Supabase table.
const launchMomentOptions = <LaunchMomentOption>[
  LaunchMomentOption(
    tag: 'road-to-world-cup-2026',
    title: 'Road to World Cup 2026',
    subtitle:
        'Track the build-up across host markets, qualification stories, and global supporter momentum.',
    kicker: 'World Cup lead-up',
    regionKey: 'global',
  ),
  LaunchMomentOption(
    tag: 'worldcup2026',
    title: 'World Cup 2026',
    subtitle:
        'Follow the tournament itself with featured fixtures, prediction windows, and host-market relevance.',
    kicker: 'Tournament proper',
    regionKey: 'global',
  ),
  LaunchMomentOption(
    tag: 'ucl-final-2026',
    title: 'UEFA Champions League Final',
    subtitle:
        'Keep Europe\u2019s biggest club night central during the run-in and final-week conversion window.',
    kicker: 'European club peak',
    regionKey: 'europe',
  ),
  LaunchMomentOption(
    tag: 'africa-fan-momentum-2026',
    title: 'Africa Fan Momentum',
    subtitle:
        'Grow supporter communities, club discovery, and prediction participation around African football audiences.',
    kicker: 'Africa growth',
    regionKey: 'africa',
  ),
  LaunchMomentOption(
    tag: 'north-america-host-cities-2026',
    title: 'North America Host Cities',
    subtitle:
        'Surface USA, Canada, and Mexico interest as host-city football attention accelerates.',
    kicker: 'Host-market growth',
    regionKey: 'north_america',
  ),
];

List<LaunchMomentOption> launchMomentOptionsForRuntime() {
  final runtimeMoments = runtimeBootstrapStore.config.launchMoments;
  if (runtimeMoments.isEmpty) return launchMomentOptions;
  return runtimeMoments
      .map(
        (moment) => LaunchMomentOption(
          tag: moment.tag,
          title: moment.title,
          subtitle: moment.subtitle,
          kicker: moment.kicker,
          regionKey: moment.regionKey,
        ),
      )
      .toList(growable: false);
}

LaunchMomentOption? launchMomentByTag(String tag) {
  for (final option in launchMomentOptionsForRuntime()) {
    if (option.tag == tag) return option;
  }
  return null;
}

List<String> defaultFocusTagsForRegion(String region) {
  final options = launchMomentOptionsForRuntime();
  if (runtimeBootstrapStore.config.launchMoments.isNotEmpty) {
    final normalizedRegion = normalizeRegionKey(region);
    final scoped = options
        .where(
          (option) =>
              option.regionKey == 'global' ||
              option.regionKey == normalizedRegion,
        )
        .map((option) => option.tag)
        .toList(growable: false);
    if (scoped.isNotEmpty) return scoped;
  }

  switch (normalizeRegionKey(region)) {
    case 'africa':
      return const ['road-to-world-cup-2026', 'africa-fan-momentum-2026'];
    case 'europe':
      return const ['road-to-world-cup-2026', 'ucl-final-2026'];
    case 'north_america':
      return const [
        'road-to-world-cup-2026',
        'north-america-host-cities-2026',
        'worldcup2026',
      ];
    default:
      return const ['road-to-world-cup-2026', 'worldcup2026', 'ucl-final-2026'];
  }
}
