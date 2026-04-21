import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// FANZONE confetti celebration overlay.
///
/// Matches the reference `confetti.ts` — fires on pool wins, jackpot
/// completions, and achievements. Uses brand colors.
class FzConfetti extends StatefulWidget {
  const FzConfetti({super.key, required this.child});

  final Widget child;

  /// Triggers the confetti burst from the nearest [FzConfetti] ancestor.
  static void fire(BuildContext context) {
    context.findAncestorStateOfType<FzConfettiState>()?.fire();
  }

  @override
  State<FzConfetti> createState() => FzConfettiState();
}

class FzConfettiState extends State<FzConfetti> {
  late final ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void fire() => _controller.play();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 30,
            maxBlastForce: 25,
            minBlastForce: 8,
            emissionFrequency: 0.06,
            gravity: 0.2,
            colors: const [
              FzColors.primary, // Soft Mint
              FzColors.secondary, // Warm Coral
              FzColors.cyan, // Cyan
            ],
          ),
        ),
      ],
    );
  }
}
