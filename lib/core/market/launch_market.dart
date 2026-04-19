library;

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

String? regionFromCountryName(String? country) {
  if (country == null || country.trim().isEmpty) return null;
  final normalized = country.trim().toLowerCase();

  if (_africanCountries.contains(normalized)) return 'africa';
  if (_europeanCountries.contains(normalized)) return 'europe';
  if (_northAmericanCountries.contains(normalized)) return 'north_america';
  return null;
}

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
        'Follow the tournament itself with prediction windows, global challenges, and host-market relevance.',
    kicker: 'Tournament proper',
    regionKey: 'global',
  ),
  LaunchMomentOption(
    tag: 'ucl-final-2026',
    title: 'UEFA Champions League Final',
    subtitle:
        'Keep Europe’s biggest club night central during the run-in and final-week conversion window.',
    kicker: 'European club peak',
    regionKey: 'europe',
  ),
  LaunchMomentOption(
    tag: 'africa-fan-momentum-2026',
    title: 'Africa Fan Momentum',
    subtitle:
        'Grow supporter communities, club discovery, and challenge participation around African football audiences.',
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

LaunchMomentOption? launchMomentByTag(String tag) {
  for (final option in launchMomentOptions) {
    if (option.tag == tag) return option;
  }
  return null;
}

List<String> defaultFocusTagsForRegion(String region) {
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

const Set<String> _africanCountries = {
  'algeria',
  'benin',
  'botswana',
  'burkina faso',
  'cameroon',
  'côte d’ivoire',
  'cote d\'ivoire',
  'democratic republic of the congo',
  'dr congo',
  'egypt',
  'ethiopia',
  'ghana',
  'guinea-bissau',
  'kenya',
  'madagascar',
  'mali',
  'morocco',
  'mozambique',
  'namibia',
  'niger',
  'nigeria',
  'rwanda',
  'senegal',
  'south africa',
  'tanzania',
  'togo',
  'tunisia',
  'uganda',
  'zambia',
  'zimbabwe',
};

const Set<String> _europeanCountries = {
  'austria',
  'belgium',
  'czech republic',
  'denmark',
  'england',
  'finland',
  'france',
  'germany',
  'greece',
  'hungary',
  'ireland',
  'italy',
  'malta',
  'netherlands',
  'norway',
  'poland',
  'portugal',
  'romania',
  'scotland',
  'spain',
  'sweden',
  'switzerland',
  'turkey',
  'united kingdom',
  'wales',
};

const Set<String> _northAmericanCountries = {
  'canada',
  'mexico',
  'united states',
  'united states of america',
  'usa',
};
