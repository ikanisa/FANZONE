import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/media/cdn_url_resolver.dart';
import '../../core/media/fz_image_cache_manager.dart';
import '../../models/match_model.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../common/fz_badge.dart';
import '../common/fz_card.dart';

class TeamAvatar extends StatelessWidget {
  const TeamAvatar({
    super.key,
    required this.name,
    this.size = 28,
    this.logoUrl,
  });

  final String name;
  final double size;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: isDark ? FzColors.darkText : FzColors.lightText,
          ),
        ),
      ),
    );

    if (logoUrl != null && logoUrl!.isNotEmpty) {
      final resolvedUrl = CdnUrlResolver.resolveImageUrl(
        logoUrl!,
        width: size.round() * 2,
      );

      // SVG crests need SvgPicture, not CachedNetworkImage.
      if (logoUrl!.toLowerCase().endsWith('.svg')) {
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: ClipOval(
            child: Padding(
              padding: EdgeInsets.all(size * 0.1),
              child: SvgPicture.network(
                resolvedUrl,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => fallback,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
          ),
        );
      }

      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolvedUrl,
            cacheManager: FzImageCacheManager.instance,
            fit: BoxFit.contain,
            placeholder: (context, url) => fallback,
            errorWidget: (context, url, Object error) => fallback,
          ),
        ),
      );
    }

    return fallback;
  }

  String _initials(String teamName) {
    final parts = teamName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final value = parts.first;
      return value.length >= 2
          ? value.substring(0, 2).toUpperCase()
          : value.toUpperCase();
    }
    final first = parts.first.substring(0, 1).toUpperCase();
    final last = parts.last.substring(0, 1).toUpperCase();
    return '$first$last';
  }
}

class CompetitionSectionHeader extends StatelessWidget {
  const CompetitionSectionHeader({
    super.key,
    required this.title,
    this.isFavourite = false,
    this.countryCode,
    this.onTap,
    this.onToggleFavourite,
  });

  final String title;
  final bool isFavourite;
  final String? countryCode;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavourite;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    if (countryCode != null && countryCode!.length == 2) ...[
                      CountryFlag(code: countryCode!),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: muted,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onToggleFavourite != null)
            Semantics(
              button: true,
              label: isFavourite
                  ? 'Remove $title from favourites'
                  : 'Add $title to favourites',
              child: ExcludeSemantics(
                child: IconButton(
                  onPressed: onToggleFavourite,
                  tooltip: isFavourite
                      ? 'Remove $title from favourites'
                      : 'Add $title to favourites',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isFavourite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 18,
                    color: isFavourite ? FzColors.coral : muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MatchListCard extends StatelessWidget {
  const MatchListCard({
    super.key,
    required this.matches,
    required this.onTapMatch,
  });

  final List<MatchModel> matches;
  final ValueChanged<MatchModel> onTapMatch;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FzCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var index = 0; index < matches.length; index++) ...[
              if (index > 0)
                Divider(height: 0.5, indent: 56, color: borderColor),
              MatchListRow(
                match: matches[index],
                onTap: () => onTapMatch(matches[index]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MatchListRow extends StatefulWidget {
  const MatchListRow({super.key, required this.match, this.onTap});

  final MatchModel match;
  final VoidCallback? onTap;

  @override
  State<MatchListRow> createState() => _MatchListRowState();
}

class _MatchListRowState extends State<MatchListRow> {
  Timer? _liveClockTimer;

  @override
  void initState() {
    super.initState();
    _syncLiveClock();
  }

  @override
  void didUpdateWidget(covariant MatchListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.isLive != widget.match.isLive ||
        oldWidget.match.kickoffTime != widget.match.kickoffTime ||
        oldWidget.match.date != widget.match.date) {
      _syncLiveClock();
    }
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    super.dispose();
  }

  void _syncLiveClock() {
    _liveClockTimer?.cancel();

    if (!widget.match.isLive) {
      return;
    }

    _liveClockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final isFinished = match.isFinished;
    final isLive = match.isLive;
    final isUpcoming = match.isUpcoming;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: isLive
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FzBadge.live(),
                        const SizedBox(height: 2),
                        Text(
                          _liveMinute(match),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: FzColors.primary,
                          ),
                        ),
                      ],
                    )
                  : isFinished && match.scoreDisplay != null
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: _ColoredScore(
                        key: ValueKey('${match.id}_${match.scoreDisplay}'),
                        match: match,
                      ),
                    )
                  : Text(
                      match.kickoffLabel,
                      style: FzTypography.scoreCompact(color: muted),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TeamLine(
                    name: match.homeTeam,
                    logoUrl: match.homeLogoUrl,
                    isStrong: _isHomeLeading(match),
                  ),
                  const SizedBox(height: 6),
                  _TeamLine(
                    name: match.awayTeam,
                    logoUrl: match.awayLogoUrl,
                    isStrong: _isAwayLeading(match),
                  ),
                ],
              ),
            ),
            if (isUpcoming || match.round != null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  isUpcoming
                      ? match.date.toIso8601String().split('T').first
                      : match.round ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: muted,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Approximate live minute from kickoff time.
  String _liveMinute(MatchModel m) {
    if (m.kickoffTime == null) return 'LIVE';
    try {
      final parts = m.kickoffTime!.split(':');
      if (parts.length < 2) return 'LIVE';
      final kickoffHour = int.parse(parts[0]);
      final kickoffMin = int.parse(parts[1]);
      final now = DateTime.now();
      final kickoff = DateTime(
        m.date.year,
        m.date.month,
        m.date.day,
        kickoffHour,
        kickoffMin,
      );
      final diff = now.difference(kickoff).inMinutes;
      if (diff < 0) return 'LIVE';
      if (diff <= 45) return "$diff'";
      if (diff <= 60) return "45+${diff - 45}'"; // first half stoppage / HT
      if (diff <= 105) return "${diff - 15}'"; // second half (15 min break)
      return "90+${diff - 105}'"; // second half stoppage
    } catch (_) {
      return 'LIVE';
    }
  }

  bool _isHomeLeading(MatchModel current) {
    if (current.ftHome == null || current.ftAway == null) return false;
    return current.ftHome! > current.ftAway!;
  }

  bool _isAwayLeading(MatchModel current) {
    if (current.ftHome == null || current.ftAway == null) return false;
    return current.ftAway! > current.ftHome!;
  }
}

class _ColoredScore extends StatelessWidget {
  const _ColoredScore({super.key, required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final home = match.ftHome ?? 0;
    final away = match.ftAway ?? 0;
    const winColor = FzColors.success;
    const loseColor = FzColors.danger;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final neutralColor = isDark ? FzColors.darkText : FzColors.lightText;

    final homeColor = home > away
        ? winColor
        : (home < away ? loseColor : neutralColor);
    final awayColor = away > home
        ? winColor
        : (away < home ? loseColor : neutralColor);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$home', style: FzTypography.scoreCompact(color: homeColor)),
        Text(' - ', style: FzTypography.scoreCompact(color: neutralColor)),
        Text('$away', style: FzTypography.scoreCompact(color: awayColor)),
      ],
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.name, this.logoUrl, required this.isStrong});

  final String name;
  final String? logoUrl;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    return Row(
      children: [
        TeamAvatar(name: name, logoUrl: logoUrl, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isStrong ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class MatchFactsGrid extends StatelessWidget {
  const MatchFactsGrid({super.key, required this.facts});

  final List<({String label, String value})> facts;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: facts.length,
      itemBuilder: (context, index) {
        final fact = facts[index];
        return FzCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                fact.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fact.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class InlineActionChip extends StatelessWidget {
  const InlineActionChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipSurface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final chipBorder = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chipSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: muted),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    if (code.length != 2) return const SizedBox.shrink();
    final resolvedUrl = CdnUrlResolver.resolveImageUrl(
      'https://flagcdn.com/w40/${code.toLowerCase()}.png',
      width: 40,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: CachedNetworkImage(
        imageUrl: resolvedUrl,
        cacheManager: FzImageCacheManager.instance,
        width: 16,
        height: 12,
        fit: BoxFit.cover,
        errorWidget: (context, url, Object error) =>
            Text(_countryFlag(code), style: const TextStyle(fontSize: 14)),
        placeholder: (context, url) => Container(
          width: 16,
          height: 12,
          color: Theme.of(context).brightness == Brightness.dark
              ? FzColors.darkSurface3
              : FzColors.lightSurface3,
        ),
      ),
    );
  }
}

/// Converts a 2-letter ISO country code to its emoji flag (e.g. 'mt' → 🇲🇹).
String _countryFlag(String code) {
  final upper = code.toUpperCase();
  if (upper.length != 2) return '';
  final first = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final second = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCodes([first, second]);
}
