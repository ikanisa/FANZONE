import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/phone_country_catalog.dart';
import '../../../theme/colors.dart';

typedef CountryEntry = PhoneCountryEntry;

List<CountryEntry> _allCountries() => phoneCountryCatalog();

CountryEntry findCountryByCode(String? code) => findPhoneCountryByCode(code);

CountryEntry resolveCountryFromPhoneInput(
  String value, {
  CountryEntry? fallback,
}) {
  return resolvePhoneCountryFromPhoneInput(value, fallback: fallback);
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
  late List<CountryEntry> _filtered = _allCountries();

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
    final allCountries = _allCountries();
    setState(() {
      if (query.isEmpty) {
        _filtered = allCountries;
      } else {
        final scored = <MapEntry<CountryEntry, int>>[];
        for (final country in allCountries) {
          final score = phoneCountrySearchScore(country, query);
          if (score > 0) {
            scored.add(MapEntry(country, score));
          }
        }
        scored.sort((left, right) {
          final scoreCompare = right.value.compareTo(left.value);
          if (scoreCompare != 0) return scoreCompare;
          return left.key.countryName.compareTo(right.key.countryName);
        });
        _filtered = scored.map((entry) => entry.key).toList(growable: false);
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
    final totalCountries = _allCountries().length;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchController.text.isEmpty
                    ? '$totalCountries countries'
                    : '${_filtered.length} results',
                style: TextStyle(
                  fontSize: 10,
                  color: muted,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
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
                    itemBuilder: (ctx, index) {
                      final entry = _filtered[index];
                      final isSelected =
                          widget.selected?.countryCode == entry.countryCode;
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
              Text(entry.flagEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.countryName,
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
                      entry.countryCode,
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              Text(
                entry.preset.dialCode,
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
