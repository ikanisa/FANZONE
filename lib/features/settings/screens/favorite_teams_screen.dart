import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/team_search_database.dart';
import '../../onboarding/providers/onboarding_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/team_crest.dart';

/// Settings > Favorite Teams management screen.
///
/// Allows users to add/remove favorite teams after onboarding (or if they
/// skipped that step). Changes trigger re-evaluation of inferred currency.
class FavoriteTeamsScreen extends ConsumerStatefulWidget {
  const FavoriteTeamsScreen({super.key});

  @override
  ConsumerState<FavoriteTeamsScreen> createState() =>
      _FavoriteTeamsScreenState();
}

class _FavoriteTeamsScreenState extends ConsumerState<FavoriteTeamsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<FavoriteTeamRecordDto> _savedTeams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    final teams = await OnboardingService.getUserFavoriteTeams();
    if (mounted) {
      setState(() {
        _savedTeams = teams;
        _loading = false;
      });
    }
  }

  Future<void> _addTeam(OnboardingTeam team) async {
    HapticFeedback.selectionClick();
    await OnboardingService.addFavoriteTeam(team);
    await _loadTeams();
    if (mounted) {
      _searchController.clear();
      setState(() => _query = '');
    }
  }

  Future<void> _removeTeam(String teamId) async {
    HapticFeedback.lightImpact();
    await OnboardingService.deleteFavoriteTeam(teamId);
    await _loadTeams();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final searchResults = searchTeams(_query, limit: 10);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FAVORITE TEAMS',
          style: FzTypography.display(size: 24, color: textColor),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Search
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? FzColors.darkSurface2
                        : FzColors.lightSurface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search teams to add',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: muted.withValues(alpha: 0.7),
                      ),
                      prefixIcon: Icon(
                        LucideIcons.search,
                        size: 20,
                        color: muted,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // Search results
                if (_query.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...searchResults.map((team) {
                    final alreadyAdded = _savedTeams.any(
                      (saved) => saved.teamId == team.id,
                    );
                    return ListTile(
                      leading: TeamCrest(
                        label: team.shortName,
                        crestUrl: team.resolvedCrestUrl,
                        fallbackEmoji: team.logoEmoji,
                        size: 36,
                        backgroundColor: isDark
                            ? FzColors.darkSurface2
                            : FzColors.lightSurface2,
                        borderColor: isDark
                            ? FzColors.darkBorder
                            : FzColors.lightBorder,
                      ),
                      title: Text(
                        team.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      subtitle: Text(
                        '${team.country} · ${team.league}',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                      trailing: alreadyAdded
                          ? const Icon(
                              LucideIcons.check,
                              size: 18,
                              color: FzColors.accent,
                            )
                          : IconButton(
                              icon: const Icon(
                                LucideIcons.plus,
                                size: 18,
                                color: FzColors.accent,
                              ),
                              onPressed: () => _addTeam(team),
                            ),
                    );
                  }),
                ],

                const SizedBox(height: 24),

                // Saved Teams
                Text(
                  'YOUR TEAMS',
                  style: FzTypography.display(
                    size: 18,
                    color: textColor,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),

                if (_savedTeams.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            LucideIcons.trophy,
                            size: 40,
                            color: muted.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No teams selected yet',
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Search above to add your favorites',
                            style: TextStyle(
                              fontSize: 12,
                              color: muted.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                ..._savedTeams.map((saved) {
                  final name = saved.teamName;
                  final countryCode = saved.teamCountryCode ?? '';
                  final source = saved.source;
                  final teamId = saved.teamId;

                  // Try to find the team in DB for emoji
                  final dbTeam = allTeams
                      .where((t) => t.id == teamId)
                      .firstOrNull;

                  return Dismissible(
                    key: ValueKey(teamId),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _removeTeam(teamId),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: FzColors.error.withValues(alpha: 0.1),
                      child: const Icon(
                        LucideIcons.trash2,
                        color: FzColors.error,
                        size: 20,
                      ),
                    ),
                    child: ListTile(
                      leading: TeamCrest(
                        label: dbTeam?.shortName ?? name,
                        crestUrl: saved.teamCrestUrl ?? dbTeam?.resolvedCrestUrl,
                        fallbackEmoji: dbTeam?.logoEmoji ?? '⚽',
                        size: 40,
                        backgroundColor: isDark
                            ? FzColors.darkSurface2
                            : FzColors.lightSurface2,
                        borderColor: isDark
                            ? FzColors.darkBorder
                            : FzColors.lightBorder,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (countryCode.isNotEmpty) countryCode,
                          if (source == 'local') 'Local favorite',
                        ].join(' · '),
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                      trailing: IconButton(
                        icon: Icon(LucideIcons.x, size: 16, color: muted),
                        onPressed: () => _removeTeam(teamId),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 32),

                // Info text
                Text(
                  'Your inferred currency is derived from your team selections. '
                  'Changing teams may update how FET values are displayed.',
                  style: TextStyle(
                    fontSize: 11,
                    color: muted.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
