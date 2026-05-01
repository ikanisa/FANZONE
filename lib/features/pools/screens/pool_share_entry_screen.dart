import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/common/state_view.dart';
import '../../ordering/providers/venue_context_provider.dart';
import '../data/pools_repository.dart';

class PoolShareEntryScreen extends ConsumerStatefulWidget {
  const PoolShareEntryScreen({
    super.key,
    required this.shareSlug,
    this.inviteCode,
    this.source,
  });

  final String shareSlug;
  final String? inviteCode;
  final String? source;

  @override
  ConsumerState<PoolShareEntryScreen> createState() =>
      _PoolShareEntryScreenState();
}

class _PoolShareEntryScreenState extends ConsumerState<PoolShareEntryScreen> {
  bool _opening = false;

  void _openPool(PoolSummary pool) {
    if (_opening) return;
    _opening = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final venueId = pool.venueId;
      if (venueId != null && venueId.isNotEmpty) {
        await ref.read(venueContextProvider.notifier).setVenueById(venueId);
      }

      if (!mounted) return;
      final queryParameters = <String, String>{
        if (widget.inviteCode != null && widget.inviteCode!.isNotEmpty)
          'invite': widget.inviteCode!,
        if (widget.source != null && widget.source!.isNotEmpty)
          'source': widget.source!,
      };
      final path = widget.inviteCode == null
          ? '/pool/${pool.id}'
          : '/pool/${pool.id}/join';
      context.go(
        Uri(
          path: path,
          queryParameters: queryParameters.isEmpty ? null : queryParameters,
        ).toString(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final poolAsync = ref.watch(poolBySlugProvider(widget.shareSlug));

    return Scaffold(
      body: poolAsync.when(
        data: (pool) {
          if (pool == null) {
            return StateView.empty(
              title: 'Pool link expired',
              subtitle: 'Open Pools to find another match pool.',
              action: () => context.go('/pools'),
              actionLabel: 'Open Pools',
            );
          }

          _openPool(pool);
          return const Center(child: CircularProgressIndicator());
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateView.error(
          title: 'Pool link unavailable',
          subtitle: error.toString(),
          onRetry: () => ref.invalidate(poolBySlugProvider(widget.shareSlug)),
        ),
      ),
    );
  }
}
