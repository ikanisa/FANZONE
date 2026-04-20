part of '../screens/predict_screen.dart';

class _JoinPoolSheet extends ConsumerStatefulWidget {
  const _JoinPoolSheet({required this.pool});

  final ScorePool pool;

  @override
  ConsumerState<_JoinPoolSheet> createState() => _JoinPoolSheetState();
}

class _JoinPoolSheetState extends ConsumerState<_JoinPoolSheet> {
  final _homeScoreController = TextEditingController();
  final _awayScoreController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  Future<void> _joinPool() async {
    if (!ref.read(isAuthenticatedProvider)) {
      await showSignInRequiredSheet(
        context,
        title: 'Sign in to join this pool',
        message:
            'Guests can browse pools freely. Phone verification is only required when you want to join one.',
        from: '/pool/${widget.pool.id}',
      );
      return;
    }

    final homeScore = int.tryParse(_homeScoreController.text);
    final awayScore = int.tryParse(_awayScoreController.text);

    if (homeScore == null || awayScore == null) {
      setState(() => _error = 'Enter valid score predictions.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(poolServiceProvider.notifier)
          .joinPool(
            poolId: widget.pool.id,
            homeScore: homeScore,
            awayScore: awayScore,
            stake: widget.pool.stake,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ArgumentError catch (error) {
      setState(() => _error = error.message.toString());
    } on StateError catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: _SheetScaffold(
        title: 'Join pool',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.pool.matchName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Stake: ${formatFET(widget.pool.stake, currency)}',
              style: const TextStyle(fontSize: 13, color: FzColors.primary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _homeScoreController,
                    label: 'Home',
                    enabled: !_submitting,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    controller: _awayScoreController,
                    label: 'Away',
                    enabled: !_submitting,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: FzColors.error)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _joinPool,
                child: Text(_submitting ? 'Joining...' : 'Join pool'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
    );
  }
}
