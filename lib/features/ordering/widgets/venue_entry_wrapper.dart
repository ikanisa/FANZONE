import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/venue_context_provider.dart';
import '../screens/venue_menu_screen.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';

class VenueEntryWrapper extends ConsumerStatefulWidget {
  const VenueEntryWrapper({
    super.key,
    this.venueSlug,
    this.venueId,
    this.tableNumber,
  }) : assert(venueSlug != null || venueId != null);

  final String? venueSlug;
  final String? venueId;
  final String? tableNumber;

  @override
  ConsumerState<VenueEntryWrapper> createState() => _VenueEntryWrapperState();
}

class _VenueEntryWrapperState extends ConsumerState<VenueEntryWrapper> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initContext();
  }

  Future<void> _initContext() async {
    try {
      final notifier = ref.read(venueContextProvider.notifier);
      final success = widget.venueSlug != null
          ? await notifier.setVenueBySlug(
              widget.venueSlug!,
              tableNumber: widget.tableNumber,
            )
          : await notifier.setVenueById(
              widget.venueId!,
              tableNumber: widget.tableNumber,
            );
      if (!success) {
        setState(() => _error = 'Venue not found');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                FzBackHeader(
                  title: 'Venue Entry',
                  subtitle: 'Resolving FANZONE link',
                ),
                Expanded(child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            children: [
              FzBackHeader(
                title: 'Venue Entry',
                subtitle: 'Resolving FANZONE link',
                onClose: () => context.go('/venues'),
              ),
              const SizedBox(height: 48),
              StateView.error(
                title: 'Venue link unavailable',
                subtitle: _error!,
                onRetry: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _initContext();
                },
              ),
            ],
          ),
        ),
      );
    }

    return VenueMenuScreen(venueSlug: widget.venueSlug);
  }
}
