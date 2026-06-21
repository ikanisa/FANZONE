import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../models/hospitality/venue_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/fz_reference_modals.dart';
import '../../../widgets/common/state_view.dart';
import '../providers/venue_context_provider.dart';
import '../providers/venue_discovery_provider.dart';

class VenueDetailScreen extends ConsumerWidget {
  const VenueDetailScreen({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailByIdProvider(venueId));

    return Scaffold(
      body: SafeArea(
        child: venueAsync.when(
          data: (venue) {
            if (venue == null) {
              return FzEmptyState(
                title: 'Venue not found',
                description: 'Choose another.',
                icon: const Icon(LucideIcons.mapPin),
                actionLabel: 'Bars',
                onAction: () => context.go('/venues'),
              );
            }
            return _VenueDetailContent(venue: venue);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StateView.error(
            title: 'Could not load venue',
            subtitle: error.toString(),
            onRetry: () => ref.invalidate(venueDetailByIdProvider(venueId)),
          ),
        ),
      ),
    );
  }
}

class _VenueDetailContent extends ConsumerWidget {
  const _VenueDetailContent({required this.venue});

  final VenueModel venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
      children: [
        FzBackHeader(
          title: 'Bar',
          subtitle: venue.city ?? venue.countryCode.label,
          onClose: () => context.go('/venues'),
        ),
        const SizedBox(height: 18),
        Stack(
          children: [
            FzImageSurface(
              imageUrl: venue.coverUrl,
              icon: LucideIcons.utensils,
              height: 230,
            ),
            Positioned(
              left: 14,
              top: 14,
              child: FzPill(
                label: venue.isOpen ? 'Live' : 'Bar',
                icon: venue.isOpen ? LucideIcons.zap : LucideIcons.mapPin,
                color: venue.isOpen ? FzColors.success : FzColors.accent,
                selected: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          venue.name,
          style: FzTypography.display(size: 38, color: FzColors.darkText),
        ),
        const SizedBox(height: 8),
        Text(
          venue.city ?? venue.countryCode.label,
          style: const TextStyle(
            color: FzColors.darkMuted,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        FzMetricTile(
          label: 'Type',
          value: [
            venue.venueType.label,
            venue.primaryCategoryLabel,
          ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
          icon: LucideIcons.store,
        ),
        const SizedBox(height: 12),
        FzCard(
          padding: const EdgeInsets.all(16),
          borderRadius: FzRadii.card,
          child: Column(
            children: [
              _VenueInfoRow(
                icon: LucideIcons.mapPin,
                label: 'Address',
                value: venue.fullAddress.isEmpty
                    ? venue.city ?? venue.countryCode.label
                    : venue.fullAddress,
              ),
              const Divider(height: 24),
              _VenueInfoRow(
                icon: LucideIcons.clock,
                label: 'Status',
                value: venue.isOpen ? 'Open' : 'Closed',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: ValueKey('venue_detail_menu_${venue.id}'),
          onPressed: () async {
            await ref
                .read(venueContextProvider.notifier)
                .setVenueById(venue.id);
            if (context.mounted) context.go('/bar');
          },
          icon: const Icon(LucideIcons.utensils),
          label: const Text('Menu'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: ValueKey('venue_detail_create_pool_${venue.id}'),
          onPressed: () async {
            await ref
                .read(venueContextProvider.notifier)
                .setVenueById(venue.id);
            if (context.mounted) context.go('/pools/create');
          },
          icon: const Icon(LucideIcons.trophy),
          label: const Text('Create'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: ValueKey('venue_detail_chat_${venue.id}'),
          onPressed: () => context.go('/venue/${venue.id}/chat'),
          icon: const Icon(LucideIcons.messagesSquare),
          label: const Text('Chat with venue'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 10),
        _VenueSupportButton(venue: venue),
      ],
    );
  }
}

class _VenueSupportButton extends ConsumerStatefulWidget {
  const _VenueSupportButton({required this.venue});

  final VenueModel venue;

  @override
  ConsumerState<_VenueSupportButton> createState() =>
      _VenueSupportButtonState();
}

class _VenueSupportButtonState extends ConsumerState<_VenueSupportButton> {
  bool _submitting = false;

  Future<void> _openSupport() async {
    if (_submitting) return;
    if (!ref.read(isFullyAuthenticatedProvider)) {
      await showFzNoticeSheet(
        context,
        title: 'Verify WhatsApp',
        message: 'Verify your WhatsApp number before contacting venue support.',
        icon: LucideIcons.messageCircle,
        iconColor: FzColors.accent,
        primaryLabel: 'Verify',
        onPrimary: () {
          if (mounted) {
            context.go(
              '/login?from=${Uri.encodeComponent('/venue/${widget.venue.id}')}',
            );
          }
        },
      );
      return;
    }

    final draft = await _showVenueSupportRequestSheet(context, widget.venue);
    if (draft == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(venueSupportGatewayProvider)
          .createVenueSupportRequest(
            venueId: widget.venue.id,
            topic: draft.topic,
            message: draft.message,
            tableNumber: draft.tableNumber,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venue support request sent.')),
      );
    } catch (_) {
      if (!mounted) return;
      await showFzNoticeSheet(
        context,
        title: 'Support request unavailable',
        message: 'Try again shortly or ask venue staff directly.',
        icon: LucideIcons.alertTriangle,
        iconColor: FzColors.warning,
        primaryLabel: 'Continue',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: ValueKey('venue_detail_support_${widget.venue.id}'),
      onPressed: _submitting ? null : _openSupport,
      icon: const Icon(LucideIcons.messageCircle),
      label: Text(_submitting ? 'Sending...' : 'Contact venue'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }
}

class _VenueSupportDraft {
  const _VenueSupportDraft({
    required this.topic,
    required this.message,
    this.tableNumber,
  });

  final String topic;
  final String message;
  final String? tableNumber;
}

Future<_VenueSupportDraft?> _showVenueSupportRequestSheet(
  BuildContext context,
  VenueModel venue,
) {
  const topics = <String, String>{
    'general': 'General',
    'venue': 'Venue visit',
    'accessibility': 'Accessibility',
    'safety': 'Safety',
  };
  var topic = 'general';
  final messageController = TextEditingController();
  final tableController = TextEditingController();

  return showModalBottomSheet<_VenueSupportDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
      final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Contact ${venue.name}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a support request to the venue team. For urgent help, speak to staff at the venue.',
              style: TextStyle(color: muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey('venue_support_topic'),
              initialValue: topic,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.listChecks),
                labelText: 'Topic',
              ),
              items: topics.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) topic = value;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('venue_support_message'),
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.messageSquareText),
                labelText: 'Message',
                hintText: 'Add at least 10 characters',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('venue_support_table'),
              controller: tableController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.hash),
                labelText: 'Table optional',
                hintText: 'Example: 12 or VIP 2',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('venue_support_submit'),
              onPressed: () {
                final message = messageController.text.trim();
                if (message.length < 10) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Add at least 10 characters.'),
                    ),
                  );
                  return;
                }
                final tableNumber = tableController.text.trim();
                Navigator.of(sheetContext).pop(
                  _VenueSupportDraft(
                    topic: topic,
                    message: message,
                    tableNumber: tableNumber.isEmpty ? null : tableNumber,
                  ),
                );
              },
              child: const Text('Send request'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messageController.dispose();
      tableController.dispose();
    });
  });
}

class _VenueInfoRow extends StatelessWidget {
  const _VenueInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: FzColors.accent.withValues(alpha: 0.12),
            borderRadius: FzRadii.buttonRadius,
          ),
          child: Icon(icon, color: FzColors.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}
