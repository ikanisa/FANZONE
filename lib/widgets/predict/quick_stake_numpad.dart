import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'package:flutter/services.dart';

class QuickStakeNumpad extends StatelessWidget {
  const QuickStakeNumpad({
    super.key,
    required this.currentStake,
    required this.onStakeChanged,
    required this.walletBalance,
  });

  final int currentStake;
  final ValueChanged<int> onStakeChanged;
  final int walletBalance;

  void _handleKey(String key) {
    HapticFeedback.lightImpact();
    if (key == 'DEL') {
      final str = currentStake.toString();
      if (str.length > 1) {
        onStakeChanged(int.parse(str.substring(0, str.length - 1)));
      } else {
        onStakeChanged(0);
      }
    } else if (key == 'MAX') {
      onStakeChanged(walletBalance);
    } else if (key.startsWith('+')) {
      final val = int.parse(key.substring(1));
      onStakeChanged(currentStake + val);
    } else {
      final newVal = int.parse('${currentStake == 0 ? '' : currentStake}$key');
      if (newVal <= walletBalance) {
        onStakeChanged(newVal);
      } else {
        onStakeChanged(walletBalance);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _QuickChip(label: '+10', onTap: () => _handleKey('+10')),
              const SizedBox(width: 8),
              _QuickChip(label: '+50', onTap: () => _handleKey('+50')),
              const SizedBox(width: 8),
              _QuickChip(label: '+100', onTap: () => _handleKey('+100')),
              const SizedBox(width: 8),
              _QuickChip(label: '+500', onTap: () => _handleKey('+500')),
              const SizedBox(width: 8),
              _QuickChip(
                label: 'MAX',
                onTap: () => _handleKey('MAX'),
                isMax: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Numpad Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 2.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var i = 1; i <= 9; i++)
              _NumKey(
                label: '$i',
                onTap: () => _handleKey('$i'),
                bg: gridColor,
                textColor: textColor,
              ),
            _NumKey(
              label: '00',
              onTap: () => _handleKey('00'),
              bg: gridColor,
              textColor: textColor,
            ),
            _NumKey(
              label: '0',
              onTap: () => _handleKey('0'),
              bg: gridColor,
              textColor: textColor,
            ),
            _NumKey(
              label: 'DEL',
              onTap: () => _handleKey('DEL'),
              bg: gridColor,
              textColor: muted,
              icon: Icons.backspace_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.isMax = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isMax;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isMax
              ? (isDark ? FzColors.darkSurface3 : FzColors.lightSurface3)
              : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isMax ? FontWeight.w700 : FontWeight.w600,
            color: isMax ? FzColors.danger : null,
          ),
        ),
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  const _NumKey({
    required this.label,
    required this.onTap,
    required this.bg,
    required this.textColor,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final Color bg;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: icon != null
              ? Icon(icon, color: textColor, size: 20)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
        ),
      ),
    );
  }
}
