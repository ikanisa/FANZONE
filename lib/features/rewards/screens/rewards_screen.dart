import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_glass_loader.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  RewardItemData? _activeReward;

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(walletServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
            children: [
              Text(
                'REWARDS STORE',
                style: FzTypography.display(
                  size: 32,
                  color: textColor,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Redeem your FET for exclusive rewards',
                style: TextStyle(fontSize: 14, color: muted),
              ),
              const SizedBox(height: 24),
              FzCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your Balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ),
                    balanceAsync.when(
                      data: (balance) => Text(
                        '$balance FET',
                        style: FzTypography.score(
                          size: 28,
                          weight: FontWeight.w700,
                          color: FzColors.coral,
                        ),
                      ),
                      loading: () => const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, _) => Text(
                        '—',
                        style: FzTypography.score(
                          size: 28,
                          weight: FontWeight.w700,
                          color: FzColors.coral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: kRewards.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                ),
                itemBuilder: (context, index) {
                  final reward = kRewards[index];
                  return _RewardCard(
                    reward: reward,
                    onTap: () => setState(() => _activeReward = reward),
                  );
                },
              ),
            ],
          ),
          _RewardWizard(
            reward: _activeReward,
            balance: balanceAsync.valueOrNull ?? 0,
            onClose: () => setState(() => _activeReward = null),
          ),
        ],
      ),
    );
  }
}

class RewardItemData {
  const RewardItemData({
    required this.id,
    required this.title,
    required this.category,
    required this.cost,
    required this.icon,
    this.requiresPhone = false,
  });

  final String id;
  final String title;
  final String category;
  final int cost;
  final IconData icon;
  final bool requiresPhone;
}

const kRewards = <RewardItemData>[
  RewardItemData(
    id: 'airtime',
    title: 'Mobile Airtime',
    category: 'Utility',
    cost: 500,
    icon: LucideIcons.smartphone,
    requiresPhone: true,
  ),
  RewardItemData(
    id: 'badge',
    title: 'Premium Badge',
    category: 'Cosmetic',
    cost: 200,
    icon: LucideIcons.star,
  ),
  RewardItemData(
    id: 'jackpot',
    title: 'Jackpot Entry',
    category: 'Gameplay',
    cost: 100,
    icon: LucideIcons.zap,
  ),
  RewardItemData(
    id: 'voucher',
    title: 'Partner Voucher',
    category: 'Utility',
    cost: 1000,
    icon: LucideIcons.gift,
  ),
];

class _RewardCard extends ConsumerWidget {
  const _RewardCard({required this.reward, required this.onTap});

  final RewardItemData reward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletServiceProvider).valueOrNull ?? 0;
    final canAfford = balance >= reward.cost;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isDark
                      ? FzColors.darkSurface2
                      : FzColors.lightSurface2),
                  shape: BoxShape.circle,
                ),
                child: Icon(reward.icon, color: FzColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reward.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: canAfford ? onTap : null,
              child: Text(
                'Redeem ${reward.cost} FET',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _RewardWizardStep { details, processing, success }

class _RewardWizard extends StatefulWidget {
  const _RewardWizard({
    required this.reward,
    required this.balance,
    required this.onClose,
  });

  final RewardItemData? reward;
  final int balance;
  final VoidCallback onClose;

  @override
  State<_RewardWizard> createState() => _RewardWizardState();
}

class _RewardWizardState extends State<_RewardWizard> {
  _RewardWizardStep _step = _RewardWizardStep.details;
  final _phoneController = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  void _resetAndClose() {
    _timer?.cancel();
    _phoneController.clear();
    setState(() => _step = _RewardWizardStep.details);
    widget.onClose();
  }

  void _redeem() {
    setState(() => _step = _RewardWizardStep.processing);
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _step = _RewardWizardStep.success);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.reward;
    if (reward == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final canSubmit =
        !reward.requiresPhone || _phoneController.text.trim().length >= 8;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _step == _RewardWizardStep.processing
                ? null
                : _resetAndClose,
            child: Container(color: Colors.black.withValues(alpha: 0.72)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border(top: BorderSide(color: border)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: switch (_step) {
                  _RewardWizardStep.details => Column(
                    key: const ValueKey('reward-details'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(reward.icon, color: FzColors.primary),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _resetAndClose,
                            icon: const Icon(LucideIcons.x, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: surface,
                              foregroundColor: muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        reward.title,
                        style: FzTypography.display(
                          size: 28,
                          color: textColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${reward.category.toUpperCase()} • ${reward.cost} FET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: muted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (reward.requiresPhone) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Mobile Money Number',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: muted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'e.g. 078XXXXXXX',
                            filled: true,
                            fillColor: surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: FzColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rewards will be sent directly to this number.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Current Balance',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: muted,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${widget.balance} FET',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: FzColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: canSubmit ? _redeem : null,
                          child: const Text('CONFIRM REDEMPTION'),
                        ),
                      ),
                    ],
                  ),
                  _RewardWizardStep.processing => const SizedBox(
                    key: ValueKey('reward-processing'),
                    height: 220,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 42,
                            height: 42,
                            child: FzGlassLoader(useBackdrop: false, size: 42),
                          ),
                          SizedBox(height: 18),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: FzColors.darkText,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Connecting to fulfillment partner',
                            style: TextStyle(
                              fontSize: 13,
                              color: FzColors.darkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _RewardWizardStep.success => Column(
                    key: const ValueKey('reward-success'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: FzColors.success.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.checkCircle2,
                          size: 40,
                          color: FzColors.success,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Redemption Successful!',
                        style: FzTypography.display(
                          size: 24,
                          color: textColor,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '-${reward.cost} FET',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: FzColors.coral,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RECEIPT ID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: muted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RWD-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'REWARD',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: muted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reward.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            if (reward.requiresPhone) ...[
                              const SizedBox(height: 12),
                              Text(
                                'DELIVERED TO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: muted,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _phoneController.text.trim(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _resetAndClose,
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
