import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../models/hospitality/venue_chat_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/fz_reference_modals.dart';

class VenueChatScreen extends ConsumerStatefulWidget {
  const VenueChatScreen({super.key, required this.venueId, this.orderId});

  final String venueId;
  final String? orderId;

  @override
  ConsumerState<VenueChatScreen> createState() => _VenueChatScreenState();
}

class _VenueChatScreenState extends ConsumerState<VenueChatScreen> {
  final _composerController = TextEditingController();
  final _subjectController = TextEditingController();
  List<VenueChatThreadModel> _threads = const [];
  String? _selectedThreadId;
  bool _loading = true;
  bool _submitting = false;
  Object? _error;

  VenueChatThreadModel? get _selectedThread {
    for (final thread in _threads) {
      if (thread.id == _selectedThreadId) return thread;
    }
    return _threads.isEmpty ? null : _threads.first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _composerController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!ref.read(isFullyAuthenticatedProvider)) {
      setState(() {
        _loading = false;
        _threads = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final threads = await ref
          .read(venueChatGatewayProvider)
          .fetchVenueChatThreads(widget.venueId);
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _selectedThreadId ??= threads.isEmpty ? null : threads.first.id;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final body = _composerController.text.trim();
    if (body.length < 2 || _submitting) return;

    setState(() => _submitting = true);
    try {
      final gateway = ref.read(venueChatGatewayProvider);
      final selected = _selectedThread;
      if (selected == null) {
        final thread = await gateway.createVenueChatThread(
          venueId: widget.venueId,
          initialMessage: body,
          topic: widget.orderId == null ? 'general' : 'order',
          subject: _subjectController.text.trim().isEmpty
              ? null
              : _subjectController.text.trim(),
          orderId: widget.orderId,
        );
        if (!mounted) return;
        setState(() {
          _threads = [thread, ..._threads];
          _selectedThreadId = thread.id;
        });
      } else {
        await gateway.sendVenueChatMessage(threadId: selected.id, body: body);
        await _refresh();
      }
      _composerController.clear();
      _subjectController.clear();
    } catch (_) {
      if (!mounted) return;
      await showFzNoticeSheet(
        context,
        title: 'Chat unavailable',
        message: 'Try again shortly or ask venue staff directly.',
        icon: LucideIcons.alertTriangle,
        iconColor: FzColors.warning,
        primaryLabel: 'Continue',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _promptSignIn() {
    return showFzNoticeSheet(
      context,
      title: 'Verify WhatsApp',
      message: 'Verify your WhatsApp number before chatting with the venue.',
      icon: LucideIcons.messageCircle,
      iconColor: FzColors.accent,
      primaryLabel: 'Verify',
      onPrimary: () {
        context.go(
          '/login?from=${Uri.encodeComponent('/venue/${widget.venueId}/chat')}',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authenticated = ref.watch(isFullyAuthenticatedProvider);
    final selected = _selectedThread;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            FzBackHeader(
              title: 'Venue chat',
              subtitle: 'Message venue staff',
              onClose: () => context.go('/venue/${widget.venueId}'),
            ),
            const SizedBox(height: 16),
            if (!authenticated)
              FzEmptyState(
                title: 'Verify to chat',
                description:
                    'Venue chat is only available after WhatsApp verification.',
                icon: const Icon(LucideIcons.messageCircle),
                actionLabel: 'Verify',
                onAction: _promptSignIn,
              )
            else if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              if (_error != null)
                FzCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: FzRadii.card,
                  child: Text(
                    'Could not load chat. ${_error.toString()}',
                    style: const TextStyle(
                      color: FzColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (_threads.length > 1) ...[
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final thread = _threads[index];
                      final selected = thread.id == _selectedThread?.id;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(thread.title),
                        onSelected: (_) {
                          setState(() => _selectedThreadId = thread.id);
                        },
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemCount: _threads.length,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _ConversationCard(thread: selected),
              const SizedBox(height: 14),
              if (selected == null)
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LucideIcons.tags),
                    labelText: 'Subject optional',
                    hintText: 'Example: Table help',
                  ),
                ),
              if (selected == null) const SizedBox(height: 10),
              TextField(
                key: const ValueKey('venue_chat_composer'),
                controller: _composerController,
                minLines: 3,
                maxLines: 5,
                maxLength: 2000,
                decoration: InputDecoration(
                  prefixIcon: const Icon(LucideIcons.messageSquareText),
                  labelText: selected == null
                      ? 'Start a conversation'
                      : selected.isOpen
                      ? 'Reply'
                      : 'Chat closed',
                  hintText: 'Write your message',
                ),
                enabled: selected?.isOpen ?? true,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey('venue_chat_send'),
                onPressed: _submitting || (selected != null && !selected.isOpen)
                    ? null
                    : _submit,
                icon: Icon(_submitting ? LucideIcons.loader : LucideIcons.send),
                label: Text(_submitting ? 'Sending...' : 'Send'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.thread});

  final VenueChatThreadModel? thread;

  @override
  Widget build(BuildContext context) {
    final current = thread;
    if (current == null) {
      return const FzCard(
        padding: EdgeInsets.all(18),
        borderRadius: FzRadii.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.messageCircle, color: FzColors.accent),
            SizedBox(height: 12),
            Text(
              'Start a secure venue chat',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              'Messages are visible to you and staff assigned to this venue.',
              style: TextStyle(color: FzColors.darkMuted, height: 1.4),
            ),
          ],
        ),
      );
    }

    return FzCard(
      padding: const EdgeInsets.all(14),
      borderRadius: FzRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  current.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                current.status.replaceAll('_', ' '),
                style: const TextStyle(
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (current.messages.isEmpty)
            const Text(
              'No messages yet.',
              style: TextStyle(color: FzColors.darkMuted),
            )
          else
            ...current.messages.map((message) {
              final alignRight = message.senderRole != 'customer';
              return Align(
                alignment: alignRight
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 310),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: alignRight
                        ? FzColors.accent.withValues(alpha: 0.12)
                        : FzColors.darkSurface2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: FzColors.darkBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.senderRole.replaceAll('_', ' '),
                        style: const TextStyle(
                          color: FzColors.darkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(message.body, style: const TextStyle(height: 1.4)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
