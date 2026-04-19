import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/search_result_model.dart';
import '../../../providers/search_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/common/fz_glass_loader.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        setState(() => _query = value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final searchAsync = query.length >= 2
        ? ref.watch(searchProvider(query))
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: 'Team, competition, match',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (query.length < 2)
            StateView.empty(
              title: 'Search',
              subtitle: 'Type at least 2 characters.',
              icon: Icons.search_rounded,
            )
          else
            searchAsync!.when(
              data: (results) {
                if (results.isEmpty) {
                  return StateView.empty(
                    title: 'No results',
                    subtitle: 'No matches for "$query".',
                    icon: Icons.search_off_rounded,
                  );
                }
                return Column(
                  children: [
                    if (results.competitions.isNotEmpty)
                      _SearchSection(
                        title: 'Competitions',
                        results: results.competitions,
                      ),
                    if (results.teams.isNotEmpty)
                      _SearchSection(title: 'Teams', results: results.teams),
                    if (results.matches.isNotEmpty)
                      _SearchSection(
                        title: 'Matches',
                        results: results.matches,
                      ),
                  ],
                );
              },
              loading: () => const FzGlassLoader(message: 'Syncing...'),
              error: (error, stackTrace) => StateView.error(
                title: 'Search unavailable',
                subtitle: 'Try again.',
                onRetry: () => ref.invalidate(searchProvider(query)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({required this.title, required this.results});

  final String title;
  final List<SearchResultModel> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: FzTypography.sectionLabel(Theme.of(context).brightness),
        ),
        const SizedBox(height: 10),
        ...results.map(
          (result) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FzCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: InkWell(
                onTap: () => context.push(result.route),
                child: Row(
                  children: [
                    _SearchLeading(type: result.type, title: result.title),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (result.subtitle.isNotEmpty)
                            Text(
                              result.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? FzColors.darkMuted
                                    : FzColors.lightMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SearchLeading extends StatelessWidget {
  const _SearchLeading({required this.type, required this.title});

  final SearchResultType type;
  final String title;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case SearchResultType.team:
        return TeamAvatar(name: title);
      case SearchResultType.competition:
        return const Icon(Icons.emoji_events_outlined, color: FzColors.accent);
      case SearchResultType.match:
        return const Icon(Icons.sports_soccer_rounded, color: FzColors.accent);
    }
  }
}
