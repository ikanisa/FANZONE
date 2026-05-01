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
  final _titleController = TextEditingController();
  final _minStakeController = TextEditingController(text: '1');
  final _maxStakeController = TextEditingController(text: '100');
  String? _selectedMatchId;
  String _scope = 'global';
  bool _submitting = false;
  String? _error;
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
    limit: 60,
  );

  @override
  void dispose() {
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
        title: 'Verify WhatsApp to create pools',
        message:
            'Verify your WhatsApp number before creating and sharing match pools.',
        from: '/pools/create',
      );
      return;
    }

    final matchId =
        _selectedMatchId ?? (matches.isEmpty ? null : matches.first.id);
    final match = matches.cast<MatchModel?>().firstWhere(
      (item) => item?.id == matchId,
      orElse: () => null,
    );
    final venueContext = ref.read(venueContextProvider);
    final minStake = int.tryParse(_minStakeController.text.trim()) ?? 1;
    final maxStake = int.tryParse(_maxStakeController.text.trim()) ?? 100;
    final trimmedTitle = _titleController.text.trim();
    final title = trimmedTitle.isNotEmpty
        ? trimmedTitle
        : match == null
        ? 'Match pool'
        : '${match.homeTeam} vs ${match.awayTeam} pool';

    if (matchId == null || matchId.isEmpty) {
      setState(() => _error = 'Choose a match before creating a pool.');
      return;
    }
    if (minStake <= 0 || maxStake < minStake) {
      setState(() => _error = 'Use a valid FET stake range.');
      return;
    }
    if (_scope == 'venue' && !venueContext.hasVenue) {
      setState(() => _error = 'Scan a table QR before creating a bar pool.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _createdPool = null;
    });

    try {
      final result = await ref
          .read(poolsRepositoryProvider)
          .createPool(
            PoolCreateRequest(
              matchId: matchId,
              scope: _scope,
              title: title,
              stakeMinFet: minStake,
              stakeMaxFet: maxStake,
              venueId: _scope == 'venue' ? venueContext.venueId : null,
            ),
          );
      ref.invalidate(poolsProvider);
      if (mounted) {
        setState(() {
          _createdPool = result;
          _submitting = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueContext = ref.watch(venueContextProvider);
    final filter = _filterFor(venueContext);
    final matchesAsync = ref.watch(matchesProvider(filter));
    if (_scope == 'venue' && !venueContext.hasVenue) {
      _scope = 'global';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create pool'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(LucideIcons.chevronLeft),
        ),
      ),
      body: matchesAsync.when(
        data: (matches) {
          if (matches.isEmpty) {
            return StateView.empty(
              title: 'No matches available',
              subtitle:
                  'Create a pool when curated upcoming matches are available.',
              action: () => ref.invalidate(matchesProvider(filter)),
              actionLabel: 'Refresh',
            );
          }

          final selectedId = _selectedMatchId ?? matches.first.id;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            children: [
              _CreateHero(venueName: venueContext.venue?.name),
              const SizedBox(height: 16),
              const _SectionLabel('Match'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                items: [
                  for (final match in matches)
                    DropdownMenuItem(
                      value: match.id,
                      child: Text(
                        '${match.homeTeam} vs ${match.awayTeam}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _selectedMatchId = value),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Scope'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ScopeChoice(
                      label: 'Global',
                      icon: LucideIcons.globe2,
                      selected: _scope == 'global',
                      onTap: () => setState(() => _scope = 'global'),
                    ),
                  ),
                  if (venueContext.hasVenue) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ScopeChoice(
                        label: 'This Bar',
                        icon: LucideIcons.mapPin,
                        selected: _scope == 'venue',
                        onTap: () => setState(() => _scope = 'venue'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Title'),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                maxLength: 80,
                decoration: const InputDecoration(
                  hintText: 'Derby table pool',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Stake settings'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minStakeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        suffixText: 'FET',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _maxStakeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        suffixText: 'FET',
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorStrip(message: _error!),
              ],
              if (_createdPool != null) ...[
                const SizedBox(height: 16),
                _CreatedPoolCard(result: _createdPool!),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _submitting ? null : () => _create(matches),
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.plus, size: 16),
                label: Text(_submitting ? 'Creating...' : 'Create pool'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
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
    );
  }
}

class _CreateHero extends StatelessWidget {
  const _CreateHero({required this.venueName});

  final String? venueName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.darkSurface, FzColors.accent2],
        ),
        borderRadius: FzRadii.heroRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'POOL BUILDER',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            venueName == null ? 'Create a match pool' : 'Create for $venueName',
            style: FzTypography.display(
              size: 32,
              color: Colors.white,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pick a match, set the stake range, then share the pool link.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeChoice extends StatelessWidget {
  const _ScopeChoice({
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
      padding: const EdgeInsets.all(14),
      borderRadius: FzRadii.compact,
      borderColor: selected ? FzColors.accent : FzColors.darkBorder,
      child: Row(
        children: [
          Icon(icon, color: selected ? FzColors.accent : FzColors.darkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatedPoolCard extends StatelessWidget {
  const _CreatedPoolCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final poolId = result['pool_id']?.toString();
    final shareUrl = result['share_url']?.toString();

    return FzCard(
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      borderColor: FzColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.badgeCheck, color: FzColors.success),
              SizedBox(width: 10),
              Text(
                'Pool created',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (shareUrl != null && shareUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              shareUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: FzColors.darkMuted),
            ),
          ],
          if (poolId != null && poolId.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/pool/$poolId'),
                icon: const Icon(LucideIcons.chevronRight, size: 16),
                label: const Text('Open pool'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FzColors.danger.withValues(alpha: 0.10),
        borderRadius: FzRadii.buttonRadius,
        border: Border.all(color: FzColors.danger.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, color: FzColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: FzColors.darkText),
            ),
          ),
        ],
      ),
    );
  }
}
