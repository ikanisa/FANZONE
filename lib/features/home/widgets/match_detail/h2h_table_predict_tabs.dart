part of '../../screens/match_detail_screen.dart';

class _H2HTab extends ConsumerWidget {
  const _H2HTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final matchesAsync = ref.watch(
      competitionMatchesProvider(match.competitionId),
    );

    return matchesAsync.when(
      data: (allMatches) {
        final meetings = allMatches.where((m) {
          if (!m.isFinished) return false;
          if (m.id == match.id) return false;
          final teams = {m.homeTeam, m.awayTeam};
          return teams.contains(match.homeTeam) &&
              teams.contains(match.awayTeam);
        }).toList()..sort((a, b) => b.date.compareTo(a.date));
        final recent = meetings.take(5).toList();

        List<String> formGuide(String teamName) {
          return allMatches
              .where(
                (m) =>
                    m.isFinished &&
                    (m.homeTeam == teamName || m.awayTeam == teamName),
              )
              .take(5)
              .map((m) {
                final isHome = m.homeTeam == teamName;
                final scored = isHome ? (m.ftHome ?? 0) : (m.ftAway ?? 0);
                final conceded = isHome ? (m.ftAway ?? 0) : (m.ftHome ?? 0);
                if (scored > conceded) return 'W';
                if (scored < conceded) return 'L';
                return 'D';
              })
              .toList();
        }

        final homeForm = formGuide(match.homeTeam);
        final awayForm = formGuide(match.awayTeam);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Recent Form',
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 12),
            FzCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _FormRow(
                    teamName: match.homeTeam,
                    form: homeForm,
                    isDark: isDark,
                    muted: muted,
                  ),
                  const SizedBox(height: 12),
                  _FormRow(
                    teamName: match.awayTeam,
                    form: awayForm,
                    isDark: isDark,
                    muted: muted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Last Meetings',
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              FzCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No previous meetings found.',
                  style: TextStyle(fontSize: 14, color: muted),
                ),
              )
            else
              ...recent.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FzCard(
                    padding: EdgeInsets.zero,
                    child: MatchListRow(
                      match: m,
                      onTap: () => context.push('/match/${m.id}'),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const FzGlassLoader(message: 'Syncing...'),
      error: (err, st) => StateView.error(
        title: 'H2H unavailable',
        onRetry: () =>
            ref.invalidate(competitionMatchesProvider(match.competitionId)),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.teamName,
    required this.form,
    required this.isDark,
    required this.muted,
  });

  final String teamName;
  final List<String> form;
  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamAvatar(name: teamName, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            teamName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: form.map((result) {
            return Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: _formColor(result),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  result,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _formColor(String result) {
    switch (result) {
      case 'W':
        return FzColors.success;
      case 'L':
        return FzColors.danger;
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _PredictTab extends ConsumerWidget {
  const _PredictTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (match.isFinished) {
      return StateView.empty(
        title: 'Markets Closed',
        subtitle: 'This match has ended.',
        icon: LucideIcons.lock,
      );
    }

    final catalog = ref
        .watch(matchMarketCatalogProvider(match.competitionId))
        .valueOrNull;
    final odds = ref.watch(matchOddsProvider(match.id)).valueOrNull;
    final selections = ref.watch(predictionSlipProvider);
    final matchResultMarket = _catalogById(catalog, 'match_result');
    final bttsMarket = _catalogById(catalog, 'btts');
    final overUnderMarket = _catalogById(catalog, 'over_under_2_5');

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'MATCH MARKETS',
                style: FzTypography.display(
                  size: 20,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FzColors.darkText
                      : FzColors.lightText,
                  letterSpacing: 2.2,
                ),
              ),
            ),
            _MoreMarketsButton(match: match),
          ],
        ),
        const SizedBox(height: 24),
        _SourceMarketGroup(
          title: 'Match Result',
          options: [
            _SourceMarketOption(
              keyLabel: '1',
              valueLabel: _formatMultiplier(odds?.homeMultiplier) ?? 'OPEN',
              earnLabel: _earnLabel(matchResultMarket?.baseFet),
              isSelected: _isSelected(
                selections,
                match.id,
                PredictionType.matchResult,
                '1',
              ),
              onTap: () => ref
                  .read(predictionSlipProvider.notifier)
                  .toggleMatchResult(
                    match,
                    '1',
                    multiplier: odds?.multiplierForSelection('1'),
                  ),
            ),
            _SourceMarketOption(
              keyLabel: 'X',
              valueLabel: _formatMultiplier(odds?.drawMultiplier) ?? 'OPEN',
              earnLabel: _earnLabel(matchResultMarket?.baseFet),
              isSelected: _isSelected(
                selections,
                match.id,
                PredictionType.matchResult,
                'X',
              ),
              onTap: () => ref
                  .read(predictionSlipProvider.notifier)
                  .toggleMatchResult(
                    match,
                    'X',
                    multiplier: odds?.multiplierForSelection('X'),
                  ),
            ),
            _SourceMarketOption(
              keyLabel: '2',
              valueLabel: _formatMultiplier(odds?.awayMultiplier) ?? 'OPEN',
              earnLabel: _earnLabel(matchResultMarket?.baseFet),
              isSelected: _isSelected(
                selections,
                match.id,
                PredictionType.matchResult,
                '2',
              ),
              onTap: () => ref
                  .read(predictionSlipProvider.notifier)
                  .toggleMatchResult(
                    match,
                    '2',
                    multiplier: odds?.multiplierForSelection('2'),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SourceMarketGroup(
          title: 'Both Teams to Score',
          options: [
            _SourceMarketOption(
              keyLabel: 'Yes',
              valueLabel: 'OPEN',
              earnLabel: _earnLabel(bttsMarket?.baseFet),
              isSelected: _isSelected(
                selections,
                match.id,
                PredictionType.bothTeamsToScore,
                'yes',
              ),
              onTap: bttsMarket == null
                  ? null
                  : () => ref
                        .read(predictionSlipProvider.notifier)
                        .toggleBothTeamsToScore(
                          match,
                          'yes',
                          marketTypeId: bttsMarket.id,
                          baseFet: bttsMarket.baseFet,
                        ),
            ),
            _SourceMarketOption(
              keyLabel: 'No',
              valueLabel: 'OPEN',
              earnLabel: _earnLabel(bttsMarket?.baseFet),
              isSelected: _isSelected(
                selections,
                match.id,
                PredictionType.bothTeamsToScore,
                'no',
              ),
              onTap: bttsMarket == null
                  ? null
                  : () => ref
                        .read(predictionSlipProvider.notifier)
                        .toggleBothTeamsToScore(
                          match,
                          'no',
                          marketTypeId: bttsMarket.id,
                          baseFet: bttsMarket.baseFet,
                        ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SourceMarketGroup(
          title: 'Over / Under 2.5',
          options: [
            _SourceMarketOption(
              keyLabel: 'Over',
              valueLabel: 'OPEN',
              earnLabel: _earnLabel(overUnderMarket?.baseFet),
              isSelected: _isSelected(
                selections,
                match.id,
                PredictionType.overUnder25,
                'over',
              ),
              onTap: overUnderMarket == null
                  ? null
                  : () => ref
                        .read(predictionSlipProvider.notifier)
                        .toggleOverUnder25(
                          match,
                          'over',
                          marketTypeId: overUnderMarket.id,
                          baseFet: overUnderMarket.baseFet,
                        ),
            ),
            _SourceMarketOption(
              keyLabel: 'Under',
              valueLabel: 'OPEN',
              earnLabel: _earnLabel(overUnderMarket?.baseFet),
              isSelected: _isSelected(
                selections,
                match.id,
                PredictionType.overUnder25,
                'under',
              ),
              onTap: overUnderMarket == null
                  ? null
                  : () => ref
                        .read(predictionSlipProvider.notifier)
                        .toggleOverUnder25(
                          match,
                          'under',
                          marketTypeId: overUnderMarket.id,
                          baseFet: overUnderMarket.baseFet,
                        ),
            ),
          ],
        ),
      ],
    );
  }
}

PredictionMarketCatalogItem? _catalogById(
  List<PredictionMarketCatalogItem>? catalog,
  String id,
) {
  if (catalog == null) return null;
  for (final item in catalog) {
    if (item.id == id) return item;
  }
  return null;
}

bool _isSelected(
  List<PredictionSelection> selections,
  String matchId,
  PredictionType type,
  String value,
) {
  return selections.any(
    (selection) =>
        selection.match.id == matchId &&
        selection.type == type &&
        selection.selection == value,
  );
}

String? _earnLabel(int? baseFet) {
  if (baseFet == null || baseFet <= 0) return null;
  return '+$baseFet FET';
}

String? _formatMultiplier(double? value) {
  if (value == null || value <= 0) return null;
  return value.toStringAsFixed(2);
}

class _SourceMarketGroup extends StatelessWidget {
  const _SourceMarketGroup({required this.title, required this.options});

  final String title;
  final List<_SourceMarketOption> options;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.96,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: options,
          ),
        ],
      ),
    );
  }
}

class _SourceMarketOption extends StatelessWidget {
  const _SourceMarketOption({
    required this.keyLabel,
    required this.valueLabel,
    required this.isSelected,
    required this.onTap,
    this.earnLabel,
  });

  final String keyLabel;
  final String valueLabel;
  final String? earnLabel;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isSelected
        ? FzColors.primary.withValues(alpha: 0.18)
        : (isDark ? FzColors.darkSurface3 : FzColors.lightSurface3);
    final border = isSelected
        ? FzColors.primary.withValues(alpha: 0.4)
        : (isDark ? FzColors.darkBorder : FzColors.lightBorder);
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              keyLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: text,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              earnLabel ?? '',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: FzColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreMarketsButton extends StatelessWidget {
  const _MoreMarketsButton({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showMarketSelectorSheet(context, match),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FzColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 14, color: FzColors.primary),
            SizedBox(width: 8),
            Text(
              'More Markets',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FzColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showMarketSelectorSheet(BuildContext context, MatchModel match) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MarketSelectorSheet(match: match),
  );
}

class _MarketSelectorSheet extends ConsumerStatefulWidget {
  const _MarketSelectorSheet({required this.match});

  final MatchModel match;

  @override
  ConsumerState<_MarketSelectorSheet> createState() =>
      _MarketSelectorSheetState();
}

class _MarketSelectorSheetState extends ConsumerState<_MarketSelectorSheet> {
  static const _tabs = ['Match', 'Goals', 'Players', 'Corners', 'Cards'];
  String _activeTab = 'Match';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final catalog = ref
        .watch(matchMarketCatalogProvider(widget.match.competitionId))
        .valueOrNull;
    final items = _itemsForTab(_activeTab, catalog);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'SELECT MARKET',
                    style: FzTypography.display(
                      size: 24,
                      color: text,
                      letterSpacing: 2.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, size: 24, color: muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search markets...',
                prefixIcon: Icon(LucideIcons.search, size: 18, color: muted),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final selected = tab == _activeTab;
                return InkWell(
                  onTap: () => setState(() => _activeTab = tab),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? FzColors.primary : surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? Colors.transparent : border,
                      ),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? FzColors.darkBg : muted,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, separatorIndex) => const SizedBox(width: 8),
              itemCount: _tabs.length,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              children: [
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Additional markets sync here when available.',
                        style: TextStyle(fontSize: 14, color: muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: text,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: FzColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: FzColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Text(
                                item.actionLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: FzColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: FzColors.primary,
                  foregroundColor: FzColors.darkBg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'RETURN TO MATCH MARKETS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_MarketSelectorItem> _itemsForTab(
    String tab,
    List<PredictionMarketCatalogItem>? catalog,
  ) {
    switch (tab) {
      case 'Match':
        return [
          _MarketSelectorItem(
            title: 'Full Time Result (1X2)',
            actionLabel: _selectorActionLabel(
              _catalogById(catalog, 'match_result'),
            ),
          ),
          const _MarketSelectorItem(
            title: 'Double Chance (1X)',
            actionLabel: 'OPEN',
          ),
          const _MarketSelectorItem(title: 'Draw No Bet', actionLabel: 'OPEN'),
          const _MarketSelectorItem(
            title: 'Correct Score',
            actionLabel: 'OPEN',
          ),
        ];
      case 'Goals':
        return [
          _MarketSelectorItem(
            title: 'Both Teams to Score',
            actionLabel: _selectorActionLabel(_catalogById(catalog, 'btts')),
          ),
          _MarketSelectorItem(
            title: 'Over / Under 2.5',
            actionLabel: _selectorActionLabel(
              _catalogById(catalog, 'over_under_2_5'),
            ),
          ),
        ];
      default:
        return const [];
    }
  }
}

String _selectorActionLabel(PredictionMarketCatalogItem? item) {
  if (item == null) return 'OPEN';
  if (item.baseFet > 0) return '+${item.baseFet} FET';
  return 'OPEN';
}

class _MarketSelectorItem {
  const _MarketSelectorItem({required this.title, required this.actionLabel});

  final String title;
  final String actionLabel;
}
