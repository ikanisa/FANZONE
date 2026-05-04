import 'dart:async';

import 'package:flutter/material.dart';

import '../typography/app_typography.dart';

class AppCountdown extends StatefulWidget {
  const AppCountdown({super.key, required this.target});

  final DateTime target;

  @override
  State<AppCountdown> createState() => _AppCountdownState();
}

class _AppCountdownState extends State<AppCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.target.difference(DateTime.now());
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final hours = clamped.inHours;
    final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Text(
      '$hours:$minutes:$seconds',
      style: AppTypography.metric(size: 28),
    );
  }
}
