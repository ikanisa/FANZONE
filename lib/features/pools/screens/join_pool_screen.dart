import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/fz_reference_modals.dart';
import '../../../widgets/common/state_view.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../data/pools_repository.dart';

class JoinPoolScreen extends ConsumerStatefulWidget {
  const JoinPoolScreen({
    super.key,
    required this.poolId,
    this.initialCampId,
    this.inviteCode,
    this.source,
  });

  final String poolId;
  final String? initialCampId;
  final String? inviteCode;
  final String? source;

  @override
  ConsumerState<JoinPoolScreen> createState() => _JoinPoolScreenState();
}

class _JoinPoolScreenState extends ConsumerState<JoinPoolScreen> {
  final _stakeController = TextEditingController();
  String? _selectedCampId;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCampId = widget.initialCampId;
  }

  @override
  void dispose() {
    _stakeController.dispose();
    super.dispose();
  }

  Future<void> _confirm(PoolSummary pool, int availableFet) async {
    final isVerified = ref.read(isFullyAuthenticatedProvider);
    if (!isVerified) {
      final returnTo = Uri(
        path: '/pool/${pool.id}/join',
        queryParameters: {
          if (widget.initialCampId != null) 'camp': widget.initialCampId!,
          if (widget.inviteCode != null) 'invite': widget.inviteCode!,
          if (widget.source != null) 'source': widget.source!,
        },
      ).toString();
      await showSignInRequiredSheet(
        context,
        title: 'Verify WhatsApp to join pools',
        message:
            'Verify your WhatsApp number before staking FET into a match pool.',
        from: returnTo,
      );
      return;
    }

    final campId = _selectedCampId;
    final amount =
        int.tryParse(_stakeController.text.trim()) ?? pool.defaultStakeFet;
    if (campId == null || campId.isEmpty) {
      setState(() => _error = 'Choose a camp before confirming.');
      return;
    }
    if (amount < pool.stakeMinFet || amount > pool.stakeMaxFet) {
      setState(
        () => _error =
            'Stake must be between ${pool.stakeMinFet} and ${pool.stakeMaxFet} FET.',
      );
      return;
    }
    if (availableFet < amount) {
      setState(() => _error = null);
      await showFzInsufficientFetSheet(
        context,
        requiredFet: amount,
        availableFet: availableFet,
        onOpenWallet: () {
          if (mounted) context.push('/wallet');
        },
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(poolsRepositoryProvider)
          .stakeInPool(
            poolId: pool.id,
            campId: campId,
            stakeAmountFet: amount,
            source: widget.inviteCode == null
                ? _safeSource(widget.source)
                : 'invite_link',
            inviteCode: widget.inviteCode,
          );
      ref.invalidate(poolsProvider);
      ref.invalidate(poolDetailProvider(pool.id));
      ref.invalidate(poolEntryStateProvider(pool.id));
      ref.invalidate(walletBalanceProvider);
      ref.invalidate(transactionServiceProvider);
      if (mounted) {
        context.go('/pool/${pool.id}');
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
    final poolAsync = ref.watch(poolDetailProvider(widget.poolId));
    final walletAsync = ref.watch(walletBalanceProvider);

    return Scaffold(
      body: SafeArea(
        child: poolAsync.when(
          data: (pool) {
            if (pool == null) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                children: [
                  const FzBackHeader(
                    title: 'Join Pool',
                    subtitle: 'Choose a camp and stake FET',
                  ),
                  const SizedBox(height: 48),
                  StateView.empty(
                    title: 'Pool not found',
                    subtitle: 'Open Pools to choose another pool.',
                    action: () => context.go('/pools'),
                    actionLabel: 'Open Pools',
                  ),
                ],
              );
            }

            if (_stakeController.text.isEmpty) {
              _stakeController.text = pool.defaultStakeFet.toString();
            }

            return walletAsync.when(
              data: (wallet) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                children: [
                  const FzBackHeader(
                    title: 'Join Pool',
                    subtitle: 'Choose a camp and stake FET',
                  ),
                  const SizedBox(height: 18),
                  _JoinHero(pool: pool, availableFet: wallet.availableFet),
                  const SizedBox(height: 16),
                  const _SectionLabel('Choose your camp'),
                  const SizedBox(height: 10),
                  ...pool.camps.map(
                    (camp) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CampChoice(
                        camp: camp,
                        selected: _selectedCampId == camp.id,
                        onTap: () => setState(() => _selectedCampId = camp.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel('Stake amount'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _stakeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      prefixIcon: const Icon(LucideIcons.coins),
                      suffixText: 'FET',
                      helperText:
                          'Range ${pool.stakeMinFet}-${pool.stakeMaxFet} FET',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorStrip(message: _error!),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => _confirm(pool, wallet.availableFet),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.lock, size: 16),
                    label: Text(
                      _submitting ? 'Confirming...' : 'Stake FET now',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
              loading: () => const _JoinLoadingState(),
              error: (error, _) => StateView.error(
                title: 'Wallet unavailable',
                subtitle: error.toString(),
                onRetry: () => ref.invalidate(walletBalanceProvider),
              ),
            );
          },
          loading: () => const _JoinLoadingState(),
          error: (error, _) => StateView.error(
            title: 'Pool unavailable',
            subtitle: error.toString(),
            onRetry: () => ref.invalidate(poolDetailProvider(widget.poolId)),
          ),
        ),
      ),
    );
  }
}

String _safeSource(String? source) {
  switch (source) {
    case 'venue_qr':
    case 'social_share':
      return source!;
    default:
      return 'direct';
  }
}

class _JoinHero extends StatelessWidget {
  const _JoinHero({required this.pool, required this.availableFet});

  final PoolSummary pool;
  final int availableFet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.darkSurface, FzColors.teal, FzColors.action],
          stops: [0, 0.58, 1],
        ),
        borderRadius: FzRadii.heroRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'JOIN POOL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pool.title,
            style: FzTypography.display(
              size: 30,
              color: Colors.white,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick one camp and stake from your available FET. Settlement is automatic after the final result.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeroMetric(label: 'Available', value: '$availableFet FET'),
              const SizedBox(width: 10),
              _HeroMetric(
                label: 'Default',
                value: '${pool.defaultStakeFet} FET',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JoinLoadingState extends StatelessWidget {
  const _JoinLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          FzBackHeader(
            title: 'Join Pool',
            subtitle: 'Choose a camp and stake FET',
          ),
          Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class _CampChoice extends StatelessWidget {
  const _CampChoice({
    required this.camp,
    required this.selected,
    required this.onTap,
  });

  final PoolCamp camp;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      borderColor: selected ? FzColors.action : FzColors.darkBorder,
      color: selected ? FzColors.action.withValues(alpha: 0.10) : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? FzColors.action.withValues(alpha: 0.16)
                  : FzColors.darkSurface2,
              borderRadius: FzRadii.buttonRadius,
              border: Border.all(
                color: selected ? FzColors.action : FzColors.darkBorder,
              ),
            ),
            child: Icon(
              selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              color: selected ? FzColors.action : FzColors.darkMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  camp.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${camp.memberCount} members',
                  style: const TextStyle(
                    fontSize: 12,
                    color: FzColors.darkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: FzColors.darkSurface2,
              borderRadius: FzRadii.buttonRadius,
              border: Border.all(color: FzColors.darkBorder),
            ),
            child: Text(
              '${camp.totalStakedFet} FET',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: FzRadii.buttonRadius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
