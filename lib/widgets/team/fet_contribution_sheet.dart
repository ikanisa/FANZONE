import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/team_model.dart';
import '../../services/team_community_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../match/match_list_widgets.dart';

/// Bottom sheet for contributing FET to a team.
///
/// Shows current balance, amount input, quick-select chips,
/// and clear success/failure states.
class FETContributionSheet extends ConsumerStatefulWidget {
  const FETContributionSheet({super.key, required this.team});

  final TeamModel team;

  /// Show as a modal bottom sheet. Returns true if contribution succeeded.
  static Future<bool?> show(BuildContext context, TeamModel team) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FETContributionSheet(team: team),
    );
  }

  @override
  ConsumerState<FETContributionSheet> createState() =>
      _FETContributionSheetState();
}

class _FETContributionSheetState extends ConsumerState<FETContributionSheet> {
  final _controller = TextEditingController();
  int _amount = 0;
  _SheetState _state = _SheetState.input;
  String? _errorMessage;

  static const _quickAmounts = [10, 25, 50, 100, 250, 500];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setAmount(int amount) {
    setState(() {
      _amount = amount;
      _controller.text = amount.toString();
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_amount <= 0) {
      setState(() => _errorMessage = 'Enter an amount greater than 0');
      return;
    }

    final balance = ref.read(walletServiceProvider).valueOrNull ?? 0;
    if (_amount > balance) {
      setState(() => _errorMessage = 'Insufficient FET balance');
      return;
    }

    setState(() {
      _state = _SheetState.loading;
      _errorMessage = null;
    });

    try {
      await ref
          .read(teamContributionServiceProvider.notifier)
          .contributeFet(widget.team.id, _amount);

      // Refresh wallet balance
      ref.invalidate(walletServiceProvider);

      if (mounted) {
        setState(() => _state = _SheetState.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _SheetState.error;
          _errorMessage = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'Contribution failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final balanceAsync = ref.watch(walletServiceProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: _state == _SheetState.success
              ? _buildSuccess(isDark, muted)
              : _buildInput(isDark, muted, balanceAsync),
        ),
      ),
    );
  }

  Widget _buildInput(bool isDark, Color muted, AsyncValue<int> balanceAsync) {
    final isLoading = _state == _SheetState.loading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: muted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),

        // Team header
        Row(
          children: [
            TeamAvatar(
              name: widget.team.name,
              logoUrl: widget.team.logoUrl ?? widget.team.crestUrl,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contribute FET',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    widget.team.name,
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Balance pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.wallet, size: 14, color: FzColors.secondary),
              const SizedBox(width: 8),
              Text('Balance: ', style: TextStyle(fontSize: 14, color: muted)),
              balanceAsync.when(
                data: (b) => Text(
                  '$b FET',
                  style: FzTypography.scoreCompact(
                    color: isDark ? FzColors.darkText : FzColors.lightText,
                  ),
                ),
                loading: () =>
                    Text('...', style: TextStyle(fontSize: 14, color: muted)),
                error: (_, _) =>
                    Text('—', style: TextStyle(fontSize: 14, color: muted)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Amount input
        TextField(
          controller: _controller,
          enabled: !isLoading,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: FzTypography.score(
            size: 32,
            color: isDark ? FzColors.darkText : FzColors.lightText,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: FzTypography.score(
              size: 32,
              color: muted.withValues(alpha: 0.4),
            ),
            suffixText: 'FET',
            suffixStyle: TextStyle(fontSize: 14, color: muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _amount = int.tryParse(value) ?? 0;
              _errorMessage = null;
            });
          },
        ),
        const SizedBox(height: 14),

        // Quick-select chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickAmounts.map((amount) {
            final isSelected = _amount == amount;
            return InkWell(
              onTap: isLoading ? null : () => _setAmount(amount),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FzColors.primary.withValues(alpha: 0.15)
                      : (isDark
                            ? FzColors.darkSurface2
                            : FzColors.lightSurface2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? FzColors.primary : Colors.transparent,
                  ),
                ),
                child: Text(
                  '$amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? FzColors.primary
                        : (isDark ? FzColors.darkText : FzColors.lightText),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Error message
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: FzColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  size: 16,
                  color: FzColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 14, color: FzColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: isLoading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: FzColors.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CupertinoActivityIndicator(
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Confirm Contribution',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(bool isDark, Color muted) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: muted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: FzColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.check,
            size: 32,
            color: FzColors.success,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Contribution Sent!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '$_amount FET contributed to ${widget.team.name}',
          style: TextStyle(fontSize: 14, color: muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: FzColors.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

enum _SheetState { input, loading, success, error }
