import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';

/// A single country entry for the country code picker.
class CountryEntry {
  const CountryEntry({
    required this.code,
    required this.dialCode,
    required this.name,
    required this.flag,
    this.hint = '',
    this.minDigits = 7,
  });

  final String code; // ISO 3166-1 alpha-2 (e.g. 'MT')
  final String dialCode; // e.g. '+356'
  final String name; // e.g. 'Malta'
  final String flag; // emoji flag
  final String hint; // phone hint
  final int minDigits; // minimum digits

  String get dialDigits => dialCode.replaceAll('+', '');
}

const List<String> kPriorityCountryCodes = [
  'MT',
  'GB',
  'RW',
  'NG',
  'KE',
  'UG',
  'DE',
  'FR',
  'IT',
  'ES',
  'PT',
  'NL',
  'US',
  'CA',
  'MX',
];

/// All supported countries — ordered by relevance for FANZONE markets.
const List<CountryEntry> kAllCountries = [
  // ── Primary markets ──
  CountryEntry(
    code: 'MT',
    dialCode: '+356',
    name: 'Malta',
    flag: '🇲🇹',
    hint: '79XX XXXX',
    minDigits: 8,
  ),
  CountryEntry(
    code: 'RW',
    dialCode: '+250',
    name: 'Rwanda',
    flag: '🇷🇼',
    hint: '7XX XXX XXX',
    minDigits: 9,
  ),
  // ── Europe ──
  CountryEntry(
    code: 'GB',
    dialCode: '+44',
    name: 'United Kingdom',
    flag: '🇬🇧',
    hint: '7XXX XXX XXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'DE',
    dialCode: '+49',
    name: 'Germany',
    flag: '🇩🇪',
    hint: '15XX XXX XXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'FR',
    dialCode: '+33',
    name: 'France',
    flag: '🇫🇷',
    hint: '6 XX XX XX XX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'IT',
    dialCode: '+39',
    name: 'Italy',
    flag: '🇮🇹',
    hint: '3XX XXX XXXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'ES',
    dialCode: '+34',
    name: 'Spain',
    flag: '🇪🇸',
    hint: '6XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'PT',
    dialCode: '+351',
    name: 'Portugal',
    flag: '🇵🇹',
    hint: '9XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'NL',
    dialCode: '+31',
    name: 'Netherlands',
    flag: '🇳🇱',
    hint: '6 XX XX XX XX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'BE',
    dialCode: '+32',
    name: 'Belgium',
    flag: '🇧🇪',
    hint: '4XX XX XX XX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'AT',
    dialCode: '+43',
    name: 'Austria',
    flag: '🇦🇹',
    hint: '6XX XXX XXXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'CH',
    dialCode: '+41',
    name: 'Switzerland',
    flag: '🇨🇭',
    hint: '7X XXX XX XX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'SE',
    dialCode: '+46',
    name: 'Sweden',
    flag: '🇸🇪',
    hint: '7X XXX XX XX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'NO',
    dialCode: '+47',
    name: 'Norway',
    flag: '🇳🇴',
    hint: '4XX XX XXX',
    minDigits: 8,
  ),
  CountryEntry(
    code: 'DK',
    dialCode: '+45',
    name: 'Denmark',
    flag: '🇩🇰',
    hint: 'XX XX XX XX',
    minDigits: 8,
  ),
  CountryEntry(
    code: 'FI',
    dialCode: '+358',
    name: 'Finland',
    flag: '🇫🇮',
    hint: '4X XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'PL',
    dialCode: '+48',
    name: 'Poland',
    flag: '🇵🇱',
    hint: '5XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'CZ',
    dialCode: '+420',
    name: 'Czech Republic',
    flag: '🇨🇿',
    hint: '6XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'GR',
    dialCode: '+30',
    name: 'Greece',
    flag: '🇬🇷',
    hint: '6XX XXX XXXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'HR',
    dialCode: '+385',
    name: 'Croatia',
    flag: '🇭🇷',
    hint: '9X XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'RS',
    dialCode: '+381',
    name: 'Serbia',
    flag: '🇷🇸',
    hint: '6X XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'RO',
    dialCode: '+40',
    name: 'Romania',
    flag: '🇷🇴',
    hint: '7XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'HU',
    dialCode: '+36',
    name: 'Hungary',
    flag: '🇭🇺',
    hint: '20 XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'TR',
    dialCode: '+90',
    name: 'Turkey',
    flag: '🇹🇷',
    hint: '5XX XXX XXXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'IE',
    dialCode: '+353',
    name: 'Ireland',
    flag: '🇮🇪',
    hint: '8X XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'IS',
    dialCode: '+354',
    name: 'Iceland',
    flag: '🇮🇸',
    hint: '6XX XXXX',
    minDigits: 7,
  ),
  // ── Africa ──
  CountryEntry(
    code: 'NG',
    dialCode: '+234',
    name: 'Nigeria',
    flag: '🇳🇬',
    hint: '80X XXX XXXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'KE',
    dialCode: '+254',
    name: 'Kenya',
    flag: '🇰🇪',
    hint: '7XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'UG',
    dialCode: '+256',
    name: 'Uganda',
    flag: '🇺🇬',
    hint: '7XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'TZ',
    dialCode: '+255',
    name: 'Tanzania',
    flag: '🇹🇿',
    hint: '7XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'GH',
    dialCode: '+233',
    name: 'Ghana',
    flag: '🇬🇭',
    hint: '2X XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'ZA',
    dialCode: '+27',
    name: 'South Africa',
    flag: '🇿🇦',
    hint: '6X XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'EG',
    dialCode: '+20',
    name: 'Egypt',
    flag: '🇪🇬',
    hint: '10 XXXX XXXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'MA',
    dialCode: '+212',
    name: 'Morocco',
    flag: '🇲🇦',
    hint: '6XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'DZ',
    dialCode: '+213',
    name: 'Algeria',
    flag: '🇩🇿',
    hint: '5XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'TN',
    dialCode: '+216',
    name: 'Tunisia',
    flag: '🇹🇳',
    hint: '2X XXX XXX',
    minDigits: 8,
  ),
  CountryEntry(
    code: 'SN',
    dialCode: '+221',
    name: 'Senegal',
    flag: '🇸🇳',
    hint: '7X XXX XX XX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'CI',
    dialCode: '+225',
    name: "Côte d'Ivoire",
    flag: '🇨🇮',
    hint: '07 XX XX XX XX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'CM',
    dialCode: '+237',
    name: 'Cameroon',
    flag: '🇨🇲',
    hint: '6 XX XX XX XX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'CD',
    dialCode: '+243',
    name: 'DR Congo',
    flag: '🇨🇩',
    hint: '8X XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'ET',
    dialCode: '+251',
    name: 'Ethiopia',
    flag: '🇪🇹',
    hint: '9XX XXX XXX',
    minDigits: 9,
  ),
  // ── Americas ──
  CountryEntry(
    code: 'US',
    dialCode: '+1',
    name: 'United States',
    flag: '🇺🇸',
    hint: '555 123 4567',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'CA',
    dialCode: '+1',
    name: 'Canada',
    flag: '🇨🇦',
    hint: '555 123 4567',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'MX',
    dialCode: '+52',
    name: 'Mexico',
    flag: '🇲🇽',
    hint: '55 1234 5678',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'BR',
    dialCode: '+55',
    name: 'Brazil',
    flag: '🇧🇷',
    hint: '11 9XXXX XXXX',
    minDigits: 11,
  ),
  CountryEntry(
    code: 'AR',
    dialCode: '+54',
    name: 'Argentina',
    flag: '🇦🇷',
    hint: '11 XXXX XXXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'CO',
    dialCode: '+57',
    name: 'Colombia',
    flag: '🇨🇴',
    hint: '3XX XXX XXXX',
    minDigits: 10,
  ),
  // ── Asia / Middle East ──
  CountryEntry(
    code: 'IN',
    dialCode: '+91',
    name: 'India',
    flag: '🇮🇳',
    hint: '9XXX XXX XXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'AE',
    dialCode: '+971',
    name: 'UAE',
    flag: '🇦🇪',
    hint: '5X XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'SA',
    dialCode: '+966',
    name: 'Saudi Arabia',
    flag: '🇸🇦',
    hint: '5X XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'JP',
    dialCode: '+81',
    name: 'Japan',
    flag: '🇯🇵',
    hint: '90 XXXX XXXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'KR',
    dialCode: '+82',
    name: 'South Korea',
    flag: '🇰🇷',
    hint: '10 XXXX XXXX',
    minDigits: 10,
  ),
  CountryEntry(
    code: 'AU',
    dialCode: '+61',
    name: 'Australia',
    flag: '🇦🇺',
    hint: '4XX XXX XXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'NZ',
    dialCode: '+64',
    name: 'New Zealand',
    flag: '🇳🇿',
    hint: '2X XXX XXXX',
    minDigits: 9,
  ),
  CountryEntry(
    code: 'QA',
    dialCode: '+974',
    name: 'Qatar',
    flag: '🇶🇦',
    hint: '3XXX XXXX',
    minDigits: 8,
  ),
];

/// Aliases and common alternate names for smart/semantic search.
const Map<String, List<String>> _kCountryAliases = {
  'GB': ['uk', 'britain', 'england', 'scotland', 'wales', 'british'],
  'US': ['usa', 'america', 'united states of america', 'american'],
  'AE': ['uae', 'emirates', 'dubai', 'abu dhabi'],
  'KR': ['korea', 'south korea', 'korean'],
  'ZA': ['south africa', 'sa'],
  'NZ': ['new zealand', 'kiwi'],
  'DE': ['germany', 'deutschland', 'german'],
  'FR': ['france', 'french'],
  'IT': ['italy', 'italian', 'italia'],
  'ES': ['spain', 'spanish', 'espana', 'españa'],
  'PT': ['portugal', 'portuguese'],
  'NL': ['holland', 'dutch', 'netherlands'],
  'BE': ['belgium', 'belgian', 'belgique'],
  'CH': ['swiss', 'switzerland', 'schweiz', 'suisse'],
  'SE': ['sweden', 'swedish', 'sverige'],
  'NO': ['norway', 'norwegian', 'norge'],
  'DK': ['denmark', 'danish', 'danmark'],
  'FI': ['finland', 'finnish', 'suomi'],
  'PL': ['poland', 'polish', 'polska'],
  'CZ': ['czech', 'czechia', 'bohemia'],
  'GR': ['greece', 'greek', 'hellas'],
  'HR': ['croatia', 'croatian', 'hrvatska'],
  'RS': ['serbia', 'serbian', 'srbija'],
  'RO': ['romania', 'romanian'],
  'HU': ['hungary', 'hungarian', 'magyar'],
  'TR': ['turkey', 'turkish', 'türkiye', 'turkiye'],
  'IE': ['ireland', 'irish', 'eire'],
  'IS': ['iceland', 'icelandic'],
  'NG': ['nigeria', 'naija', 'nigerian'],
  'KE': ['kenya', 'kenyan'],
  'UG': ['uganda', 'ugandan'],
  'TZ': ['tanzania', 'tanzanian'],
  'GH': ['ghana', 'ghanaian'],
  'EG': ['egypt', 'egyptian', 'masr', 'misr'],
  'MA': ['morocco', 'moroccan', 'maroc'],
  'DZ': ['algeria', 'algerian', 'algerie'],
  'TN': ['tunisia', 'tunisian', 'tunis'],
  'SN': ['senegal', 'senegalese'],
  'CI': ['ivory coast', 'ivoire', 'cote', 'cdi'],
  'CM': ['cameroon', 'cameroonian', 'cameroun'],
  'CD': ['congo', 'drc', 'kinshasa', 'dr congo'],
  'ET': ['ethiopia', 'ethiopian'],
  'RW': ['rwanda', 'rwandan', 'kigali'],
  'MT': ['malta', 'maltese', 'valletta'],
  'CA': ['canada', 'canadian'],
  'MX': ['mexico', 'mexican'],
  'BR': ['brazil', 'brazilian', 'brasil'],
  'AR': ['argentina', 'argentinian', 'argentine'],
  'CO': ['colombia', 'colombian'],
  'IN': ['india', 'indian', 'bharat'],
  'SA': ['saudi', 'saudi arabia', 'ksa'],
  'JP': ['japan', 'japanese', 'nippon'],
  'AU': ['australia', 'australian', 'aussie', 'oz'],
  'QA': ['qatar', 'qatari', 'doha'],
};

/// Compute a relevance score for a country matching a query.
/// Higher score = better match. Returns 0 for no match.
int _smartMatchScore(CountryEntry country, String query) {
  final nameLower = country.name.toLowerCase();
  final codeLower = country.code.toLowerCase();
  final dialCode = country.dialCode;
  final dialDigits = country.dialDigits;

  // ── Exact matches (highest priority) ──
  if (codeLower == query) return 100;
  if (nameLower == query) return 95;
  if (dialCode == '+$query' || dialCode == query) return 90;
  if (dialDigits == query) return 90;

  int score = 0;

  // ── Name starts with query ──
  if (nameLower.startsWith(query)) {
    score = math.max(score, 80);
  }

  // ── ISO code starts with query ──
  if (codeLower.startsWith(query)) {
    score = math.max(score, 75);
  }

  // ── Dial code contains query ──
  if (dialCode.contains(query) || dialDigits.startsWith(query)) {
    score = math.max(score, 70);
  }

  // ── Alias exact match ──
  final aliases = _kCountryAliases[country.code] ?? [];
  for (final alias in aliases) {
    if (alias == query) {
      score = math.max(score, 90);
      break;
    }
    if (alias.startsWith(query)) {
      score = math.max(score, 78);
    }
    if (alias.contains(query)) {
      score = math.max(score, 60);
    }
  }

  // ── Name contains query (word boundary) ──
  if (score == 0) {
    final words = nameLower.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.startsWith(query)) {
        score = math.max(score, 65);
        break;
      }
    }
  }

  // ── Name contains query anywhere ──
  if (score == 0 && nameLower.contains(query)) {
    score = math.max(score, 50);
  }

  // ── Fuzzy: query chars appear in order in name ──
  if (score == 0 && query.length >= 3) {
    var qi = 0;
    for (var ni = 0; ni < nameLower.length && qi < query.length; ni++) {
      if (nameLower[ni] == query[qi]) qi++;
    }
    if (qi == query.length) {
      score = math.max(score, 30);
    }
  }

  return score;
}

/// Find a country by ISO code, defaulting to Malta.
CountryEntry findCountryByCode(String code) {
  return kAllCountries.firstWhere(
    (c) => c.code == code,
    orElse: () => kAllCountries.first, // Malta
  );
}

CountryEntry resolveCountryFromPhoneInput(
  String value, {
  CountryEntry? fallback,
}) {
  final base = fallback ?? kAllCountries.first;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty || !value.trimLeft().startsWith('+')) {
    return base;
  }

  final candidates = [...kAllCountries]
    ..sort((a, b) => b.dialDigits.length.compareTo(a.dialDigits.length));
  for (final country in candidates) {
    if (digits.startsWith(country.dialDigits)) {
      return country;
    }
  }
  return base;
}

int maxPhoneDigitsForHint(String hint, {int minDigits = 7}) {
  final groups = hint
      .split(RegExp(r'[^0-9Xx]+'))
      .where((group) => group.isNotEmpty)
      .map((group) => group.length)
      .toList(growable: false);
  if (groups.isEmpty) return math.max(minDigits, 12);
  final total = groups.fold<int>(0, (sum, group) => sum + group);
  return math.max(total, minDigits);
}

String formatPhoneDigits(String digits, String hint) {
  if (digits.isEmpty) return '';

  final groups = hint
      .split(RegExp(r'[^0-9Xx]+'))
      .where((group) => group.isNotEmpty)
      .map((group) => group.length)
      .toList(growable: false);
  if (groups.isEmpty) return digits;

  final parts = <String>[];
  var cursor = 0;
  for (final size in groups) {
    if (cursor >= digits.length) break;
    final end = math.min(cursor + size, digits.length);
    parts.add(digits.substring(cursor, end));
    cursor = end;
  }
  if (cursor < digits.length) {
    parts.add(digits.substring(cursor));
  }
  return parts.join(' ');
}

/// Shows a modern bottom sheet country code picker with search.
Future<CountryEntry?> showCountryCodePicker(
  BuildContext context, {
  CountryEntry? selected,
}) {
  return showModalBottomSheet<CountryEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CountryPickerSheet(selected: selected),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({this.selected});

  final CountryEntry? selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<CountryEntry> _filtered = kAllCountries;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = kAllCountries;
      } else {
        // Score every country and keep only matches
        final scored = <MapEntry<CountryEntry, int>>[];
        for (final c in kAllCountries) {
          final score = _smartMatchScore(c, query);
          if (score > 0) {
            scored.add(MapEntry(c, score));
          }
        }
        // Sort by score descending, then alphabetically for ties
        scored.sort((a, b) {
          final cmp = b.value.compareTo(a.value);
          if (cmp != 0) return cmp;
          return a.key.name.compareTo(b.key.name);
        });
        _filtered = scored.map((e) => e.key).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkSurface : FzColors.lightBg;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final maxHeight = MediaQuery.of(context).size.height * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Select Country',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: border.withValues(alpha: 0.5),
                    ),
                    child: Icon(LucideIcons.x, size: 16, color: muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(fontSize: 15, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search country or dial code...',
                hintStyle: TextStyle(fontSize: 14, color: muted),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(LucideIcons.search, size: 18, color: muted),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                filled: true,
                fillColor: isDark
                    ? FzColors.darkSurface2
                    : FzColors.lightSurface2,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: FzColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ── Results count ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchController.text.isEmpty
                    ? '${kAllCountries.length} countries'
                    : '${_filtered.length} results',
                style: TextStyle(
                  fontSize: 11,
                  color: muted,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // ── Country list ──
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.searchX, size: 40, color: muted),
                          const SizedBox(height: 12),
                          Text(
                            'No countries match your search',
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final entry = _filtered[i];
                      final isSelected = widget.selected?.code == entry.code;
                      return _CountryTile(
                        entry: entry,
                        isSelected: isSelected,
                        isDark: isDark,
                        textColor: textColor,
                        muted: muted,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context, entry);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.entry,
    required this.isSelected,
    required this.isDark,
    required this.textColor,
    required this.muted,
    required this.onTap,
  });

  final CountryEntry entry;
  final bool isSelected;
  final bool isDark;
  final Color textColor;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? FzColors.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              // Flag
              Text(entry.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              // Name + code
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      entry.code,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              // Dial code
              Text(
                entry.dialCode,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? FzColors.primary : muted,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.checkCircle2,
                  size: 18,
                  color: FzColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
