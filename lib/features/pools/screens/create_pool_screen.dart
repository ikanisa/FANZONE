import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/sports/match_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/team_crest.dart';
import '../../../widgets/common/state_view.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../../ordering/providers/venue_context_provider.dart';
import '../data/pools_repository.dart';

class CreatePoolScreen extends ConsumerStatefulWidget {
  const CreatePoolScreen({super.key});

  @override
  ConsumerState<CreatePoolScreen> createState() => _CreatePoolScreenState();
}

class _CreatePoolScreenState extends ConsumerState<CreatePoolScreen> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _minStakeController = TextEditingController(text: '100');
  final _maxStakeController = TextEditingController(text: '5000');
  var _step = 0;
  var _scope = 'venue';
  var _query = '';
  String? _selectedMatchId;
  String? _error;
  bool _submitting = false;
  Map<String, dynamic>? _createdPool;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  MatchesFilter _filterFor(VenueContext venueContext) => MatchesFilter(
    status: 'scheduled',
    dateFrom: _today.toIso8601String(),
    dateTo: _today.add(const Duration(days: 14)).toIso8601String(),
    countryCode: venueContext.venue?.countryCode.name.toUpperCase(),
    venueId: venueContext.venueId,
    ascending: true,
    limit: 80,
  );

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _minStakeController.dispose();
    _maxStakeController.dispose();
    super.dispose();
  }

  Future<void> _create(List<MatchModel> matches) async {
    final isVerified = ref.read(isFullyAuthenticatedProvider);
    if (!isVerified) {
      await showSignInRequiredSheet(
        context,
        title: 'Verify WhatsApp',
        message: 'Unlock create.',
        from: '/pools/create',
      );
      return;
    }

    final match = _selectedMatch(matches);
    final venueContext = ref.read(venueContextProvider);
    final minStake = int.tryParse(_minStakeController.text.trim()) ?? 100;
    final maxStake = int.tryParse(_maxStakeController.text.trim()) ?? 5000;
    final title = _titleController.text.trim().isEmpty
        ? '${match?.homeTeam ?? 'Match'} vs ${match?.awayTeam ?? 'Pool'}'
        : _titleController.text.trim();

    if (match == null) {
      setState(() => _error = 'Pick match.');
      return;
    }
    if (minStake <= 0 || maxStake < minStake) {
      setState(() => _error = 'Invalid stake.');
      return;
    }
    if (!venueContext.hasVenue) {
      setState(() => _error = 'Bar needed.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(poolsRepositoryProvider)
          .createPool(
            PoolCreateRequest(
              matchId: match.id,
              scope: 'venue',
              title: title,
              stakeMinFet: minStake,
              stakeMaxFet: maxStake,
              venueId: venueContext.venueId,
            ),
          );
      ref.invalidate(poolsProvider);
      if (!mounted) return;
      setState(() {
        _createdPool = result;
        _submitting = false;
        _step = 3;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueContext = ref.watch(venueContextProvider);

    final filter = _filterFor(venueContext);
    final matchesAsync = ref.watch(matchesProvider(filter));

    return Scaffold(
      body: SafeArea(
        child: matchesAsync.when(
          data: (matches) {
            if (matches.isEmpty) {
              return StateView.empty(
                title: 'No matches',
                subtitle: 'Check soon.',
                icon: LucideIcons.calendar,
                action: () => ref.invalidate(matchesProvider(filter)),
                actionLabel: 'Refresh',
              );
            }

            final selected = _selectedMatch(matches);
            final visibleMatches = _visibleMatches(matches);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: FzBackHeader(
                    title: 'Create',
                    subtitle: 'Step ${(_step + 1).clamp(1, 4)} of 4',
                    onClose: () => context.go('/pools'),
                  ),
                ),
                _ProgressBar(step: _step),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
                    children: [
                      if (_step == 0)
                        _SelectMatchStep(
                          controller: _searchController,
                          query: _query,
                          matches: visibleMatches,
                          selectedMatchId: _selectedMatchId,
                          onQuery: (value) => setState(() => _query = value),
                          onSelect: (match) =>
                              setState(() => _selectedMatchId = match.id),
                        ),
                      if (_step == 1)
                        _TermsStep(
                          venueContext: venueContext,
                          scope: _scope,
                          minController: _minStakeController,
                          maxController: _maxStakeController,
                          onScope: (scope) => setState(() => _scope = scope),
                        ),
                      if (_step == 2)
                        _ReviewStep(
                          match: selected,
                          venueContext: venueContext,
                          titleController: _titleController,
                          minStake:
                              int.tryParse(_minStakeController.text.trim()) ??
                              100,
                          maxStake:
                              int.tryParse(_maxStakeController.text.trim()) ??
                              5000,
                        ),
                      if (_step == 3) _CreatedStep(result: _createdPool),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _ErrorStrip(message: _error!),
                      ],
                    ],
                  ),
                ),
                _WizardFooter(
                  step: _step,
                  submitting: _submitting,
                  canContinue: _step == 0
                      ? selected != null
                      : _step == 1
                      ? venueContext.hasVenue
                      : true,
                  onBack: _step == 0
                      ? () => context.go('/pools')
                      : () => setState(() {
                          _error = null;
                          _step--;
                        }),
                  onNext: () {
                    if (_step == 0 && selected == null) {
                      setState(() => _error = 'Pick match.');
                      return;
                    }
                    if (_step == 1 && !venueContext.hasVenue) {
                      setState(() => _error = 'Bar needed.');
                      return;
                    }
                    if (_step == 2) {
                      _create(matches);
                      return;
                    }
                    if (_step == 3) {
                      final poolId = _createdPool?['pool_id']?.toString();
                      context.go(poolId == null ? '/pools' : '/pool/$poolId');
                      return;
                    }
                    setState(() {
                      _error = null;
                      _step++;
                    });
                  },
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StateView.error(
            title: 'Matches unavailable',
            subtitle: error.toString(),
            onRetry: () => ref.invalidate(matchesProvider(filter)),
          ),
        ),
      ),
    );
  }

  List<MatchModel> _visibleMatches(List<MatchModel> matches) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return matches;
    return matches
        .where(
          (match) =>
              match.homeTeam.toLowerCase().contains(query) ||
              match.awayTeam.toLowerCase().contains(query) ||
              (match.competitionName ?? '').toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  MatchModel? _selectedMatch(List<MatchModel> matches) {
    if (_selectedMatchId == null) return null;
    return matches.cast<MatchModel?>().firstWhere(
      (match) => match?.id == _selectedMatchId,
      orElse: () => null,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var index = 0; index < 4; index++)
            Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                decoration: BoxDecoration(
                  color: index <= step
                      ? FzColors.accent
                      : FzColors.darkSurface3,
                  borderRadius: FzRadii.fullRadius,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectMatchStep extends StatelessWidget {
  const _SelectMatchStep({
    required this.controller,
    required this.query,
    required this.matches,
    required this.selectedMatchId,
    required this.onQuery,
    required this.onSelect,
  });

  final TextEditingController controller;
  final String query;
  final List<MatchModel> matches;
  final String? selectedMatchId;
  final ValueChanged<String> onQuery;
  final ValueChanged<MatchModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Match',
          style: FzTypography.display(size: 36, color: FzColors.darkText),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pick fixture.',
          style: TextStyle(
            color: FzColors.darkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          onChanged: onQuery,
          decoration: InputDecoration(
            hintText: 'Search',
            prefixIcon: const Icon(LucideIcons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      controller.clear();
                      onQuery('');
                    },
                    icon: const Icon(LucideIcons.x),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        for (final match in matches)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MatchChoiceCard(
              match: match,
              selected: selectedMatchId == match.id,
              onTap: () => onSelect(match),
            ),
          ),
      ],
    );
  }
}

class _MatchChoiceCard extends StatelessWidget {
  const _MatchChoiceCard({
    required this.match,
    required this.selected,
    required this.onTap,
  });

  final MatchModel match;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.card,
      borderColor: selected ? FzColors.accent : FzColors.darkBorder,
      color: selected ? FzColors.accent.withValues(alpha: 0.09) : null,
      child: Row(
        children: [
          TeamCrest(
            label: match.homeTeam,
            crestUrl: match.homeLogoUrl,
            size: 46,
            backgroundColor: FzColors.darkSurface2,
            borderColor: FzColors.darkBorder,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Text(
                  match.competitionName ?? 'Today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FzColors.darkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${match.homeTeam} vs ${match.awayTeam}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  match.kickoffLabel,
                  style: const TextStyle(
                    color: FzColors.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TeamCrest(
            label: match.awayTeam,
            crestUrl: match.awayLogoUrl,
            size: 46,
            backgroundColor: FzColors.darkSurface2,
            borderColor: FzColors.darkBorder,
          ),
        ],
      ),
    );
  }
}

class _TermsStep extends StatelessWidget {
  const _TermsStep({
    required this.venueContext,
    required this.scope,
    required this.minController,
    required this.maxController,
    required this.onScope,
  });

  final VenueContext venueContext;
  final String scope;
  final TextEditingController minController;
  final TextEditingController maxController;
  final ValueChanged<String> onScope;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Terms',
          style: FzTypography.display(size: 36, color: FzColors.darkText),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bar and stake.',
          style: TextStyle(
            color: FzColors.darkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ScopeCard(
                label: venueContext.hasVenue ? 'This Bar' : 'Pick Bar',
                icon: LucideIcons.mapPin,
                selected: scope == 'venue' && venueContext.hasVenue,
                onTap: () => onScope('venue'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FzCard(
          padding: const EdgeInsets.all(16),
          borderRadius: FzRadii.card,
          child: Row(
            children: [
              const Icon(LucideIcons.mapPin, color: FzColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  venueContext.hasVenue
                      ? venueContext.venue!.name
                      : 'Bar needed.',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/venues'),
                child: const Text('Browse'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StakeField(
                label: 'Your Stake',
                controller: minController,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StakeField(label: 'Max Entry', controller: maxController),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const FzCard(
          padding: EdgeInsets.all(16),
          borderRadius: FzRadii.card,
          child: Row(
            children: [
              Icon(LucideIcons.shieldCheck, color: FzColors.success),
              SizedBox(width: 12),
              Expanded(child: Text('Ledger reserves FET.')),
            ],
          ),
        ),
      ],
    );
  }
}

class _StakeField extends StatelessWidget {
  const _StakeField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, suffixText: 'FET'),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      borderColor: selected ? FzColors.accent : FzColors.darkBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: selected ? FzColors.accent : FzColors.darkMuted),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.match,
    required this.venueContext,
    required this.titleController,
    required this.minStake,
    required this.maxStake,
  });

  final MatchModel? match;
  final VenueContext venueContext;
  final TextEditingController titleController;
  final int minStake;
  final int maxStake;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review',
          style: FzTypography.display(size: 36, color: FzColors.darkText),
        ),
        const SizedBox(height: 8),
        const Text(
          'Confirm room.',
          style: TextStyle(
            color: FzColors.darkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: titleController,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Derby night room',
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        FzCard(
          padding: const EdgeInsets.all(18),
          borderRadius: FzRadii.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                match == null
                    ? 'No match'
                    : '${match!.homeTeam} vs ${match!.awayTeam}',
                style: FzTypography.display(size: 25, color: FzColors.darkText),
              ),
              const SizedBox(height: 8),
              Text(
                match?.competitionName ?? 'Room',
                style: const TextStyle(
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FzCard(
          padding: const EdgeInsets.all(18),
          borderRadius: FzRadii.card,
          child: Column(
            children: [
              _ReviewRow(
                label: 'Host',
                value: venueContext.venue?.name ?? 'Pick bar',
              ),
              const Divider(height: 24),
              _ReviewRow(label: 'Stake', value: '$minStake-$maxStake FET'),
              const Divider(height: 24),
              const _ReviewRow(label: 'Invites', value: 'After create'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _CreatedStep extends StatelessWidget {
  const _CreatedStep({required this.result});

  final Map<String, dynamic>? result;

  @override
  Widget build(BuildContext context) {
    final shareUrl = result?['share_url']?.toString();

    return Column(
      children: [
        const SizedBox(height: 30),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: FzColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: FzColors.success.withValues(alpha: 0.35)),
          ),
          child: const Icon(
            LucideIcons.badgeCheck,
            size: 38,
            color: FzColors.success,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Created',
          style: FzTypography.display(size: 36, color: FzColors.darkText),
        ),
        const SizedBox(height: 10),
        const Text(
          'Room is live.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: FzColors.darkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (shareUrl != null && shareUrl.isNotEmpty) ...[
          const SizedBox(height: 18),
          FzCard(
            padding: const EdgeInsets.all(16),
            borderRadius: FzRadii.card,
            child: Text(
              shareUrl,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FzColors.darkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.step,
    required this.submitting,
    required this.canContinue,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final bool submitting;
  final bool canContinue;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = switch (step) {
      0 => 'Terms',
      1 => 'Review',
      2 => submitting ? 'Creating...' : 'Create',
      _ => 'Open',
    };

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: FzColors.darkBg.withValues(alpha: 0.94),
          border: const Border(top: BorderSide(color: FzColors.darkBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: submitting ? null : onBack,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: submitting || !canContinue ? null : onNext,
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(14),
      borderRadius: FzRadii.compact,
      borderColor: FzColors.danger,
      color: FzColors.danger.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: FzColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: FzColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
