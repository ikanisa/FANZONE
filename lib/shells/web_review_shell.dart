import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_router.dart' show router;
import '../config/app_config.dart';
import '../core/review_mode/review_comment_repository.dart';
import '../core/review_mode/review_component_keys.dart';
import '../core/review_mode/review_device.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';

class WebReviewShell extends StatefulWidget {
  const WebReviewShell({super.key, required this.child});

  final Widget child;

  @override
  State<WebReviewShell> createState() => _WebReviewShellState();
}

class _WebReviewShellState extends State<WebReviewShell> {
  final ReviewCommentRepository _repository = ReviewCommentRepository();
  final TextEditingController _reviewerNameController = TextEditingController();
  final TextEditingController _reviewerContactController =
      TextEditingController();

  ReviewDevicePreset _device = ReviewDevicePresets.pixel4a;
  bool _commentMode = false;
  bool _commentDialogOpen = false;
  String? _statusMessage;
  final List<_ReviewPin> _pins = <_ReviewPin>[];

  @override
  void dispose() {
    _reviewerNameController.dispose();
    _reviewerContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: router.routeInformationProvider,
      builder: (context, _) {
        final route = router.routeInformationProvider.value.uri.toString();
        return Scaffold(
          backgroundColor: FzColors.darkBg,
          body: SafeArea(
            child: Column(
              children: [
                _ReviewToolbar(
                  route: route,
                  device: _device,
                  commentMode: _commentMode,
                  statusMessage: _statusMessage,
                  reviewerNameController: _reviewerNameController,
                  reviewerContactController: _reviewerContactController,
                  onDeviceChanged: (device) => setState(() => _device = device),
                  onCommentModeChanged: (value) =>
                      setState(() => _commentMode = value),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = math.max(
                        constraints.maxWidth - FzSpacing.xxl,
                        1,
                      );
                      final availableHeight = math.max(
                        constraints.maxHeight - FzSpacing.xxl,
                        1,
                      );
                      final scale = math.min(
                        1.0,
                        math.min(
                          availableWidth / _device.width,
                          availableHeight / _device.height,
                        ),
                      );

                      return Center(
                        child: SizedBox(
                          width: _device.width * scale,
                          height: _device.height * scale,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: _DeviceFrame(
                              device: _device,
                              commentMode: _commentMode && !_commentDialogOpen,
                              pins: _pins,
                              onTapForComment: (position) =>
                                  _openCommentDialog(route, position),
                              child: widget.child,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCommentDialog(String route, Offset position) async {
    if (_commentDialogOpen) return;
    setState(() => _commentDialogOpen = true);

    final dialogContext = router.routerDelegate.navigatorKey.currentContext;
    _ReviewCommentDraft? submitted;
    try {
      submitted = await showDialog<_ReviewCommentDraft>(
        context: dialogContext ?? context,
        builder: (context) => _ReviewCommentDialog(
          route: route,
          position: position,
          device: _device,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _commentDialogOpen = false);
      }
    }

    if (!mounted || submitted == null) return;
    final draft = submitted;

    setState(() => _statusMessage = 'Saving review comment...');
    final result = await _repository.save(
      route: route,
      viewportWidth: _device.width.round(),
      viewportHeight: _device.height.round(),
      devicePreset: _device.name,
      xPosition: position.dx,
      yPosition: position.dy,
      comment: draft.comment,
      severity: draft.severity,
      componentKey: draft.componentKey,
      reviewerName: _reviewerNameController.text,
      reviewerContact: _reviewerContactController.text,
    );
    if (!mounted) return;

    setState(() {
      _pins.add(
        _ReviewPin(
          position: position,
          comment: draft.comment,
          severity: draft.severity,
        ),
      );
      _statusMessage = result.savedRemotely
          ? 'Saved to Supabase review comments.'
          : 'Saved locally for export when Supabase is unavailable.';
    });
  }
}

class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({
    required this.device,
    required this.commentMode,
    required this.pins,
    required this.onTapForComment,
    required this.child,
  });

  final ReviewDevicePreset device;
  final bool commentMode;
  final List<_ReviewPin> pins;
  final ValueChanged<Offset> onTapForComment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SizedBox(
      width: device.width,
      height: device.height,
      child: Stack(
        children: [
          MediaQuery(
            data: media.copyWith(
              size: device.size,
              padding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
            ),
            child: SizedBox(
              width: device.width,
              height: device.height,
              child: child,
            ),
          ),
          ...pins.map((pin) => _PinMarker(pin: pin)),
          if (commentMode)
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.precise,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      onTapForComment(details.localPosition),
                  child: ColoredBox(
                    color: FzColors.accent.withValues(alpha: 0.04),
                    child: const Center(child: _CommentModeHint()),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewToolbar extends StatelessWidget {
  const _ReviewToolbar({
    required this.route,
    required this.device,
    required this.commentMode,
    required this.statusMessage,
    required this.reviewerNameController,
    required this.reviewerContactController,
    required this.onDeviceChanged,
    required this.onCommentModeChanged,
  });

  final String route;
  final ReviewDevicePreset device;
  final bool commentMode;
  final String? statusMessage;
  final TextEditingController reviewerNameController;
  final TextEditingController reviewerContactController;
  final ValueChanged<ReviewDevicePreset> onDeviceChanged;
  final ValueChanged<bool> onCommentModeChanged;

  @override
  Widget build(BuildContext context) {
    final commit = AppConfig.gitCommit.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FzSpacing.md),
      decoration: const BoxDecoration(
        color: FzColors.darkSurface,
        border: Border(bottom: BorderSide(color: FzColors.darkBorder)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: FzSpacing.md,
        runSpacing: FzSpacing.sm,
        children: [
          const _ToolbarTitle(),
          _Badge(
            label: AppConfig.environmentName,
            color: AppConfig.isProduction ? FzColors.danger : FzColors.success,
          ),
          const _Badge(label: 'Review shell', color: FzColors.accent),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<ReviewDevicePreset>(
              initialValue: device,
              dropdownColor: FzColors.darkSurface2,
              decoration: const InputDecoration(
                labelText: 'Device',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: ReviewDevicePresets.all
                  .map(
                    (preset) => DropdownMenuItem(
                      value: preset,
                      child: Text(
                        '${preset.name} ${preset.width.round()}x${preset.height.round()}',
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) onDeviceChanged(value);
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: reviewerNameController,
              decoration: const InputDecoration(
                labelText: 'Reviewer',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 210,
            child: TextField(
              controller: reviewerContactController,
              decoration: const InputDecoration(
                labelText: 'Contact',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          FilterChip(
            selected: commentMode,
            label: const Text('Comment mode'),
            avatar: Icon(commentMode ? Icons.push_pin : Icons.add_comment),
            onSelected: onCommentModeChanged,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              'Route: $route',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FzColors.darkTextSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (commit.isNotEmpty)
            _Badge(
              label:
                  'Commit ${commit.length > 7 ? commit.substring(0, 7) : commit}',
              color: FzColors.warning,
            ),
          if (statusMessage != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                statusMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: FzColors.darkTextSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolbarTitle extends StatelessWidget {
  const _ToolbarTitle();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.phone_android, color: FzColors.accent),
        SizedBox(width: FzSpacing.sm),
        Text(
          'FANZONE Review PWA',
          style: TextStyle(
            color: FzColors.darkText,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FzSpacing.md,
        vertical: FzSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ReviewCommentDialog extends StatefulWidget {
  const _ReviewCommentDialog({
    required this.route,
    required this.position,
    required this.device,
  });

  final String route;
  final Offset position;
  final ReviewDevicePreset device;

  @override
  State<_ReviewCommentDialog> createState() => _ReviewCommentDialogState();
}

class _ReviewCommentDialogState extends State<_ReviewCommentDialog> {
  final TextEditingController _commentController = TextEditingController();
  String _severity = 'medium';
  String? _componentKey;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: FzColors.darkSurface,
      title: const Text('Add review comment'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.device.name} at ${widget.position.dx.round()}, ${widget.position.dy.round()}',
              style: const TextStyle(color: FzColors.darkTextSecondary),
            ),
            const SizedBox(height: FzSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _severity,
              dropdownColor: FzColors.darkSurface2,
              decoration: const InputDecoration(
                labelText: 'Severity',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'blocker', child: Text('Blocker')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'polish', child: Text('Polish')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _severity = value);
              },
            ),
            const SizedBox(height: FzSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _componentKey,
              dropdownColor: FzColors.darkSurface2,
              decoration: const InputDecoration(
                labelText: 'Component key',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Unspecified'),
                ),
                ...ReviewComponentKeys.all.map(
                  (key) => DropdownMenuItem(value: key, child: Text(key)),
                ),
              ],
              onChanged: (value) => setState(() => _componentKey = value),
            ),
            const SizedBox(height: FzSpacing.md),
            TextField(
              controller: _commentController,
              minLines: 4,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'Describe the issue or requested change.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;
    Navigator.of(context).pop(
      _ReviewCommentDraft(
        comment: comment,
        severity: _severity,
        componentKey: _componentKey,
      ),
    );
  }
}

class _CommentModeHint extends StatelessWidget {
  const _CommentModeHint();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FzColors.darkBg.withValues(alpha: 0.72),
          borderRadius: FzRadii.fullRadius,
          border: Border.all(color: FzColors.accent),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: FzSpacing.lg,
            vertical: FzSpacing.sm,
          ),
          child: Text(
            'Click a screen area to comment',
            style: TextStyle(
              color: FzColors.darkText,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.pin});

  final _ReviewPin pin;

  @override
  Widget build(BuildContext context) {
    final color = switch (pin.severity) {
      'blocker' => FzColors.danger,
      'high' => FzColors.orange,
      'low' => FzColors.success,
      'polish' => FzColors.accent,
      _ => FzColors.warning,
    };

    return Positioned(
      left: pin.position.dx - 8,
      top: pin.position.dy - 8,
      child: Tooltip(
        message: pin.comment,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: FzColors.darkBg, width: 2),
          ),
        ),
      ),
    );
  }
}

class _ReviewCommentDraft {
  const _ReviewCommentDraft({
    required this.comment,
    required this.severity,
    this.componentKey,
  });

  final String comment;
  final String severity;
  final String? componentKey;
}

class _ReviewPin {
  const _ReviewPin({
    required this.position,
    required this.comment,
    required this.severity,
  });

  final Offset position;
  final String comment;
  final String severity;
}
