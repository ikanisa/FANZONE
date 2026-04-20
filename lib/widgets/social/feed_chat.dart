import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/feed_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../theme/colors.dart';
import '../common/state_view.dart';
import '../../widgets/common/fz_glass_loader.dart';

/// Reusable social feed chat widget — drop into any channel.
///
/// Usage: `FeedChat(channelType: 'match', channelId: matchId)`
class FeedChat extends ConsumerStatefulWidget {
  const FeedChat({
    super.key,
    required this.channelType,
    required this.channelId,
    this.maxHeight,
  });

  final String channelType;
  final String channelId;
  final double? maxHeight;

  @override
  ConsumerState<FeedChat> createState() => _FeedChatState();
}

class _FeedChatState extends ConsumerState<FeedChat> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSending = false;
  String? _error;

  String get _channelKey => '${widget.channelType}:${widget.channelId}';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await sendFeedMessage(
        ref,
        channelType: widget.channelType,
        channelId: widget.channelId,
        content: text,
      );
      _controller.clear();
      unawaited(HapticFeedback.lightImpact());
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final isAuth = ref.watch(isAuthenticatedProvider);
    final messagesAsync = ref.watch(feedMessagesProvider(_channelKey));

    return Column(
      children: [
        // Messages list
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.messageCircle,
                        size: 32,
                        color: muted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No messages yet',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                      Text(
                        'Be the first to say something!',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isOwn =
                      message.userId == ref.read(currentUserProvider)?.id;
                  return _MessageBubble(
                    message: message,
                    isOwn: isOwn,
                    isDark: isDark,
                    muted: muted,
                    onReact: (emoji) async {
                      try {
                        await reactToMessage(
                          ref,
                          messageId: message.id,
                          emoji: emoji,
                        );
                        unawaited(HapticFeedback.selectionClick());
                      } catch (_) {}
                    },
                  );
                },
              );
            },
            loading: () => const FzGlassLoader(message: 'Syncing...'),
            error: (e, _) => StateView.error(
              title: 'Could not load chat',
              onRetry: () => ref.invalidate(feedMessagesProvider(_channelKey)),
            ),
          ),
        ),

        // Error banner
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: FzColors.error.withValues(alpha: 0.1),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 11, color: FzColors.error),
            ),
          ),

        // Input bar
        if (isAuth)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
              border: Border(
                top: BorderSide(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLength: 500,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Say something...',
                        hintStyle: TextStyle(fontSize: 13, color: muted),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? FzColors.darkSurface3
                            : FzColors.lightSurface3,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: FzColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                LucideIcons.send,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Sign in to join the conversation',
              style: TextStyle(fontSize: 12, color: muted),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.isDark,
    required this.muted,
    required this.onReact,
  });

  final FeedMessage message;
  final bool isOwn;
  final bool isDark;
  final Color muted;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final alignment = isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isOwn
        ? FzColors.primary.withValues(alpha: 0.15)
        : (isDark ? FzColors.darkSurface3 : FzColors.lightSurface3);
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            message.content,
            style: TextStyle(
              fontSize: 11,
              color: muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // User label + time
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${message.userId.substring(0, 6)} · ${timeFormat.format(message.createdAt.toLocal())}',
              style: TextStyle(fontSize: 9, color: muted),
            ),
          ),
          // Bubble
          GestureDetector(
            onDoubleTap: () => onReact('🔥'),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isOwn ? 14 : 4),
                  bottomRight: Radius.circular(isOwn ? 4 : 14),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(fontSize: 13, color: textColor),
              ),
            ),
          ),
          // Reactions
          if (message.hasReactions)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: 4,
                children: message.reactions.entries.map((entry) {
                  return GestureDetector(
                    onTap: () => onReact(entry.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? FzColors.darkSurface3
                            : FzColors.lightSurface3,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.key} ${entry.value}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
