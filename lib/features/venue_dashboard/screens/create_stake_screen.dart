import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../providers/home_feed_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../ordering/providers/venue_context_provider.dart';
import '../providers/venue_stake_provider.dart';
import '../../../core/di/gateway_providers.dart';

class CreateStakeScreen extends ConsumerStatefulWidget {
  const CreateStakeScreen({super.key});

  @override
  ConsumerState<CreateStakeScreen> createState() => _CreateStakeScreenState();
}

class _CreateStakeScreenState extends ConsumerState<CreateStakeScreen> {
  String? _selectedMatchId;
  final _feeController = TextEditingController(text: '50');
  bool _submitting = false;

  Future<void> _createStake() async {
    final venueId = ref.read(venueContextProvider).venueId;
    if (venueId == null || _selectedMatchId == null) return;

    setState(() => _submitting = true);
    try {
      final fee = int.tryParse(_feeController.text) ?? 0;
      await ref.read(venueStakeGatewayProvider).createStake(
        venueId: venueId,
        matchId: _selectedMatchId!,
        entryFeeFet: fee,
      );
      
      ref.invalidate(venueStakesProvider(venueId));
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: FzColors.danger),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final filter = MatchesFilter(
      dateFrom: now.toIso8601String(),
      dateTo: now.add(const Duration(days: 3)).toIso8601String(),
    );
    final matchesAsync = ref.watch(homeFeedMatchesProvider(filter));

    return Scaffold(
      appBar: AppBar(title: const Text('New Match Stake')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. SELECT MATCH', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            matchesAsync.when(
              data: (selection) {
                final upcoming = selection.upcomingMatches;
                if (upcoming.isEmpty) return const Text('No upcoming matches found.');
                
                return Column(
                  children: upcoming.map((match) {
                    final isSelected = _selectedMatchId == match.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedMatchId = match.id),
                        child: FzCard(
                          color: isSelected ? FzColors.accent2.withValues(alpha: 0.1) : null,
                          borderColor: isSelected ? FzColors.accent2 : FzColors.darkBorder,
                          child: ListTile(
                            title: Text('${match.homeTeam} vs ${match.awayTeam}'),
                            subtitle: Text(match.kickoffLabel),
                            trailing: isSelected ? const Icon(LucideIcons.checkCircle, color: FzColors.accent2) : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),
            const Text('2. ENTRY FEE (FET)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 50',
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting || _selectedMatchId == null ? null : _createStake,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FzColors.accent,
                  foregroundColor: FzColors.darkBg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_submitting ? 'CREATING...' : 'CREATE STAKE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
