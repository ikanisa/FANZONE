import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/venue_context_provider.dart';
import '../screens/venue_menu_screen.dart';

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }

    return VenueMenuScreen(venueSlug: widget.venueSlug);
  }
}
