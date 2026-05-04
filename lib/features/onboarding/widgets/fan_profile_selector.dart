import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/team_search_database.dart';
import '../../../theme/colors.dart';
import '../data/onboarding_gateway.dart';
import 'onboarding_step_chrome.dart';

typedef FanProfileSaveCallback =
    Future<void> Function(FanProfileSelection selection);

class FanProfileSelector extends StatefulWidget {
  const FanProfileSelector({
    super.key,
    required this.gateway,
    required this.initialTeams,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onSave,
    this.onSkip,
    this.onBack,
    this.title = 'FAN PROFILE',
    this.description =
        'Choose your local team, top European teams, and national teams.',
    this.saveLabel = 'SAVE FAN PROFILE',
    this.skipLabel = 'SKIP FOR NOW',
  });

  final OnboardingGateway gateway;
  final List<FavoriteTeamRecordDto> initialTeams;
  final Color textColor;
  final Color muted;
  final bool isDark;
  final FanProfileSaveCallback onSave;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final String title;
  final String description;
  final String saveLabel;
  final String skipLabel;

  @override
  State<FanProfileSelector> createState() => _FanProfileSelectorState();
}

class _FanProfileSelectorState extends State<FanProfileSelector> {
  final _searchController = TextEditingController();

  FanProfileTeamCategory _activeCategory = FanProfileTeamCategory.local;
  OnboardingTeam? _localTeam;
  late List<OnboardingTeam> _topEuropeanTeams;
  late List<OnboardingTeam> _nationalTeams;
  List<OnboardingTeam> _results = const <OnboardingTeam>[];
  Timer? _searchDebounce;
  int _resultsRequestId = 0;
  bool _loadingResults = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hydrateInitialSelection();
    _searchController.addListener(_handleSearchChanged);
    _loadResults();
  }

  @override
  void didUpdateWidget(covariant FanProfileSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTeams != widget.initialTeams) {
      _hydrateInitialSelection();
      _loadResults();
    }
    if (oldWidget.gateway != widget.gateway) {
      _loadResults();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), _loadResults);
  }

  void _hydrateInitialSelection() {
    final grouped = groupFanProfileTeamRecords(widget.initialTeams);
    final localRows = grouped[FanProfileTeamCategory.local] ?? const [];
    final topRows = grouped[FanProfileTeamCategory.topEuropean] ?? const [];
    final nationalRows = grouped[FanProfileTeamCategory.national] ?? const [];

    _localTeam = localRows.isEmpty ? null : _teamFromRecord(localRows.first);
    _topEuropeanTeams = topRows.map(_teamFromRecord).toList(growable: false);
    _nationalTeams = nationalRows.map(_teamFromRecord).toList(growable: false);
  }

  FanProfileSelection get _selection => FanProfileSelection(
    localTeam: _localTeam,
    topEuropeanTeams: _topEuropeanTeams,
    nationalTeams: _nationalTeams,
  );

  Set<String> get _selectedTeamIds => {
    if (_localTeam != null) _localTeam!.id,
    ..._topEuropeanTeams.map((team) => team.id),
    ..._nationalTeams.map((team) => team.id),
  };

  void _selectCategory(FanProfileTeamCategory category) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeCategory = category;
      _error = null;
      _searchController.clear();
    });
    _loadResults();
  }

  void _selectTeam(OnboardingTeam team) {
    if (team.id.isEmpty) return;

    setState(() {
      _error = null;
      switch (_activeCategory) {
        case FanProfileTeamCategory.local:
          _topEuropeanTeams = _topEuropeanTeams
              .where((existing) => existing.id != team.id)
              .toList(growable: false);
          _nationalTeams = _nationalTeams
              .where((existing) => existing.id != team.id)
              .toList(growable: false);
          _localTeam = team;
          break;
        case FanProfileTeamCategory.topEuropean:
          _addTeamToList(
            team,
            current: _topEuropeanTeams,
            onChanged: (next) => _topEuropeanTeams = next,
          );
          break;
        case FanProfileTeamCategory.national:
          _addTeamToList(
            team,
            current: _nationalTeams,
            onChanged: (next) => _nationalTeams = next,
          );
          break;
      }
    });
    _loadResults();
  }

  void _addTeamToList(
    OnboardingTeam team, {
    required List<OnboardingTeam> current,
    required ValueChanged<List<OnboardingTeam>> onChanged,
  }) {
    if (current.any((existing) => existing.id == team.id)) return;
    if (_selectedTeamIds.contains(team.id)) {
      _error = 'That team is already selected in another category.';
      return;
    }
    if (current.length >= _activeCategory.maxSelections) {
      _error =
          '${_activeCategory.title} allows ${_activeCategory.maxSelections} selections.';
      return;
    }
    onChanged([...current, team]);
  }

  void _removeTeam(FanProfileTeamCategory category, String teamId) {
    setState(() {
      _error = null;
      switch (category) {
        case FanProfileTeamCategory.local:
          if (_localTeam?.id == teamId) _localTeam = null;
          break;
        case FanProfileTeamCategory.topEuropean:
          _topEuropeanTeams = _topEuropeanTeams
              .where((team) => team.id != teamId)
              .toList(growable: false);
          break;
        case FanProfileTeamCategory.national:
          _nationalTeams = _nationalTeams
              .where((team) => team.id != teamId)
              .toList(growable: false);
          break;
      }
    });
    _loadResults();
  }

  Future<void> _loadResults() async {
    final requestId = ++_resultsRequestId;
    final query = _searchController.text.trim();
    final category = _activeCategory;

    setState(() => _loadingResults = true);

    final source = query.isEmpty
        ? await _defaultResultsForCategory(category)
        : await _queryResultsForCategory(category, query);

    if (!mounted || requestId != _resultsRequestId) return;

    setState(() {
      _results = _filterResults(source, category);
      _loadingResults = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      validateFanProfileSelection(
        localTeam: _localTeam,
        topEuropeanTeamIds: _topEuropeanTeams.map((team) => team.id).toSet(),
        nationalTeamIds: _nationalTeams.map((team) => team.id).toSet(),
      );
      await widget.onSave(_selection);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDark
        ? FzColors.darkSurface2
        : FzColors.lightSurface2;
    final borderColor = widget.isDark
        ? FzColors.darkBorder
        : FzColors.lightBorder;

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.onBack != null)
              OnboardingBackButtonRow(onBack: widget.onBack!),
            OnboardingSectionTitle(
              title: widget.title,
              textColor: widget.textColor,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: TextStyle(fontSize: 14, color: widget.muted, height: 1.45),
            ),
            const SizedBox(height: 18),
            _SelectedTeamsSummary(
              localTeam: _localTeam,
              topEuropeanTeams: _topEuropeanTeams,
              nationalTeams: _nationalTeams,
              muted: widget.muted,
              isDark: widget.isDark,
              onRemove: _removeTeam,
            ),
            const SizedBox(height: 14),
            SegmentedButton<FanProfileTeamCategory>(
              showSelectedIcon: false,
              segments: FanProfileTeamCategory.values
                  .map(
                    (category) => ButtonSegment(
                      value: category,
                      label: Text(category.shortTitle),
                    ),
                  )
                  .toList(growable: false),
              selected: {_activeCategory},
              onSelectionChanged: (selection) =>
                  _selectCategory(selection.first),
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _activeCategory.helperText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.muted,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: widget.textColor,
              ),
              decoration: InputDecoration(
                hintText: _searchHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: FzColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FzColors.error,
                  ),
                ),
              ),
            Expanded(
              child: _loadingResults
                  ? Center(
                      child: CircularProgressIndicator(
                        color: widget.textColor,
                        strokeWidth: 2.4,
                      ),
                    )
                  : _results.isEmpty
                  ? _FanProfileEmptyState(
                      query: _searchController.text,
                      category: _activeCategory,
                      muted: widget.muted,
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: borderColor.withValues(alpha: 0.65),
                      ),
                      itemBuilder: (context, index) {
                        final team = _results[index];
                        return _TeamResultTile(
                          team: team,
                          muted: widget.muted,
                          onTap: () => _selectTeam(team),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            OnboardingPrimaryButton(
              label: _saving ? 'SAVING...' : widget.saveLabel,
              onTap: _saving ? null : _save,
            ),
            if (widget.onSkip != null) ...[
              const SizedBox(height: 8),
              OnboardingPrimaryButton(
                label: widget.skipLabel,
                onTap: _saving ? null : widget.onSkip,
                tone: OnboardingButtonTone.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _searchHint {
    switch (_activeCategory) {
      case FanProfileTeamCategory.local:
        return 'Search for your local team';
      case FanProfileTeamCategory.topEuropean:
        return 'Search top European clubs';
      case FanProfileTeamCategory.national:
        return 'Search national teams';
    }
  }

  List<OnboardingTeam> _filterResults(
    List<OnboardingTeam> source,
    FanProfileTeamCategory category,
  ) {
    final selectedIds = _selectedTeamIds;
    final activeIds = _selectionsForCategory(
      category,
    ).map((team) => team.id).toSet();

    final deduped = <String, OnboardingTeam>{};
    for (final team in source) {
      if (team.id.isEmpty || activeIds.contains(team.id)) continue;
      if (selectedIds.contains(team.id)) continue;
      deduped[team.id] = team;
    }
    return deduped.values.take(16).toList(growable: false);
  }

  List<OnboardingTeam> _selectionsForCategory(FanProfileTeamCategory category) {
    switch (category) {
      case FanProfileTeamCategory.local:
        return [?_localTeam];
      case FanProfileTeamCategory.topEuropean:
        return _topEuropeanTeams;
      case FanProfileTeamCategory.national:
        return _nationalTeams;
    }
  }

  Future<List<OnboardingTeam>> _defaultResultsForCategory(
    FanProfileTeamCategory category,
  ) {
    switch (category) {
      case FanProfileTeamCategory.local:
        return widget.gateway.browseTeams(limit: 32);
      case FanProfileTeamCategory.topEuropean:
        return widget.gateway.browseTeams(
          region: 'europe',
          popularOnly: true,
          limit: 32,
        );
      case FanProfileTeamCategory.national:
        return widget.gateway.browseTeams(nationalOnly: true, limit: 32);
    }
  }

  Future<List<OnboardingTeam>> _queryResultsForCategory(
    FanProfileTeamCategory category,
    String query,
  ) async {
    switch (category) {
      case FanProfileTeamCategory.local:
        return widget.gateway.browseTeams(query: query, limit: 32);
      case FanProfileTeamCategory.topEuropean:
        final popular = await widget.gateway.browseTeams(
          query: query,
          region: 'europe',
          popularOnly: true,
          limit: 20,
        );
        final all = await widget.gateway.browseTeams(
          query: query,
          region: 'europe',
          limit: 20,
        );
        return [...popular, ...all];
      case FanProfileTeamCategory.national:
        return widget.gateway.browseTeams(
          query: query,
          nationalOnly: true,
          limit: 32,
        );
    }
  }

  OnboardingTeam _teamFromRecord(FavoriteTeamRecordDto row) {
    return OnboardingTeam(
      id: row.teamId,
      name: row.teamName,
      country: row.teamCountry ?? '',
      league: row.teamLeague,
      shortNameOverride: row.teamShortName,
      crestUrl: row.teamCrestUrl,
      countryCodeOverride: row.teamCountryCode,
    );
  }

  String _friendlyError(Object error) {
    if (error is ArgumentError && error.message != null) {
      return error.message.toString();
    }
    return 'Could not save fan profile. Please try again.';
  }
}

class _SelectedTeamsSummary extends StatelessWidget {
  const _SelectedTeamsSummary({
    required this.localTeam,
    required this.topEuropeanTeams,
    required this.nationalTeams,
    required this.muted,
    required this.isDark,
    required this.onRemove,
  });

  final OnboardingTeam? localTeam;
  final List<OnboardingTeam> topEuropeanTeams;
  final List<OnboardingTeam> nationalTeams;
  final Color muted;
  final bool isDark;
  final void Function(FanProfileTeamCategory category, String teamId) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SelectedCategoryRow(
          label: 'Local',
          teams: [?localTeam],
          max: FanProfileTeamCategory.local.maxSelections,
          muted: muted,
          isDark: isDark,
          onRemove: (teamId) => onRemove(FanProfileTeamCategory.local, teamId),
        ),
        const SizedBox(height: 8),
        _SelectedCategoryRow(
          label: 'Europe',
          teams: topEuropeanTeams,
          max: FanProfileTeamCategory.topEuropean.maxSelections,
          muted: muted,
          isDark: isDark,
          onRemove: (teamId) =>
              onRemove(FanProfileTeamCategory.topEuropean, teamId),
        ),
        const SizedBox(height: 8),
        _SelectedCategoryRow(
          label: 'National',
          teams: nationalTeams,
          max: FanProfileTeamCategory.national.maxSelections,
          muted: muted,
          isDark: isDark,
          onRemove: (teamId) =>
              onRemove(FanProfileTeamCategory.national, teamId),
        ),
      ],
    );
  }
}

class _SelectedCategoryRow extends StatelessWidget {
  const _SelectedCategoryRow({
    required this.label,
    required this.teams,
    required this.max,
    required this.muted,
    required this.isDark,
    required this.onRemove,
  });

  final String label;
  final List<OnboardingTeam> teams;
  final int max;
  final Color muted;
  final bool isDark;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$label ${teams.length}/$max',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
          ),
        ),
        Expanded(
          child: teams.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Not set',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: teams
                      .map(
                        (team) => InputChip(
                          label: Text(team.shortName),
                          avatar: const Icon(LucideIcons.shield, size: 14),
                          onDeleted: () => onRemove(team.id),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: isDark
                              ? FzColors.darkSurface3
                              : FzColors.lightSurface2,
                          side: BorderSide(
                            color: isDark
                                ? FzColors.darkBorder
                                : FzColors.lightBorder,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }
}

class _TeamResultTile extends StatelessWidget {
  const _TeamResultTile({
    required this.team,
    required this.muted,
    required this.onTap,
  });

  final OnboardingTeam team;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: FzColors.primary.withValues(alpha: 0.12),
        child: const Icon(
          LucideIcons.shield,
          size: 16,
          color: FzColors.primary,
        ),
      ),
      title: Text(
        team.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        [team.country, if (team.league != null) team.league]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join(' | '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: muted,
        ),
      ),
      trailing: const Icon(LucideIcons.plus, size: 18),
      onTap: onTap,
    );
  }
}

class _FanProfileEmptyState extends StatelessWidget {
  const _FanProfileEmptyState({
    required this.query,
    required this.category,
    required this.muted,
  });

  final String query;
  final FanProfileTeamCategory category;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    return Center(
      child: Text(
        hasQuery
            ? 'No matching teams found.'
            : 'Search to add ${category.shortTitle.toLowerCase()} teams.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: muted,
        ),
      ),
    );
  }
}
