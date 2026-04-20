import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/account_deletion_request_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/account_deletion_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/fz_glass_loader.dart';

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final _reasonController = TextEditingController();
  final _contactController = TextEditingController();

  AccountDeletionRequestModel? _request;
  bool _loading = true;
  bool _submitting = false;
  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadRequest() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final request = await AccountDeletionService.getLatestRequest();
      if (!mounted) return;
      setState(() {
        _request = request;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your deletion request status.';
      });
    }
  }

  Future<void> _submitRequest() async {
    final reason = _reasonController.text.trim();
    final contactEmail = _contactController.text.trim();

    if (reason.length < 10) {
      setState(() {
        _error = 'Add a short reason so support can verify the request.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final request = await AccountDeletionService.createRequest(
        reason: reason,
        contactEmail: contactEmail,
      );
      if (!mounted) return;
      setState(() {
        _request = request;
        _submitting = false;
        _reasonController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion request submitted.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Invalid argument(s): ', '');
      });
    }
  }

  Future<void> _cancelRequest() async {
    final request = _request;
    if (request == null) return;

    setState(() {
      _cancelling = true;
      _error = null;
    });

    try {
      final updated = await AccountDeletionService.cancelRequest(request.id);
      if (!mounted) return;
      setState(() {
        _request = updated;
        _cancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deletion request cancelled.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ACCOUNT DELETION',
          style: FzTypography.display(size: 26, color: textColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FzCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request account deletion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This creates a support-reviewed deletion request. Your app access will remain available until the request is verified and completed.',
                  style: TextStyle(fontSize: 13, color: muted, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!isAuthenticated)
            StateView.empty(
              title: 'Sign in required',
              subtitle:
                  'You need to sign in before you can request account deletion.',
              icon: LucideIcons.userX,
              action: () => context.go(
                '/login?from=%2Fprofile%2Fsettings%2Faccount-deletion',
              ),
              actionLabel: 'Sign in',
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: FzGlassLoader(message: 'Syncing...'),
            )
          else if (_error != null && _request == null)
            StateView.error(
              title: 'Deletion request unavailable',
              subtitle: _error!,
              onRetry: _loadRequest,
            )
          else ...[
            if (_request != null) ...[
              _RequestStatusCard(
                request: _request!,
                muted: muted,
                textColor: textColor,
              ),
              const SizedBox(height: 16),
            ],
            if (_request?.isActive ?? false)
              FzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your deletion request is already active.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you submitted this by mistake, cancel it before support starts processing.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _cancelling ? null : _cancelRequest,
                      icon: _cancelling
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: FzGlassLoader(
                                useBackdrop: false,
                                size: 14,
                              ),
                            )
                          : const Icon(LucideIcons.xCircle, size: 16),
                      label: Text(
                        _cancelling ? 'Cancelling...' : 'Cancel request',
                      ),
                    ),
                  ],
                ),
              )
            else
              FzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before you submit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We will verify the request against your account and contact details. Add enough context for support to confirm it safely.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reasonController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText:
                            'Example: I no longer use the app and want my account removed.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Contact email (optional)',
                        hintText: 'name@example.com',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: FzColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submitRequest,
                        icon: _submitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CupertinoActivityIndicator(
                                  color: FzColors.error,
                                ),
                              )
                            : const Icon(LucideIcons.userX, size: 16),
                        label: Text(
                          _submitting
                              ? 'Submitting...'
                              : 'Submit deletion request',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _RequestStatusCard extends StatelessWidget {
  const _RequestStatusCard({
    required this.request,
    required this.muted,
    required this.textColor,
  });

  final AccountDeletionRequestModel request;
  final Color muted;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final requestedAt = DateFormat(
      'dd MMM yyyy, HH:mm',
    ).format(request.requestedAt.toLocal());

    return FzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(status: request.status),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Submitted $requestedAt',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
          if ((request.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              request.reason!,
              style: TextStyle(fontSize: 13, color: textColor, height: 1.4),
            ),
          ],
          if ((request.resolutionNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              request.resolutionNotes!,
              style: TextStyle(fontSize: 12, color: muted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'completed':
        color = FzColors.success;
        break;
      case 'rejected':
      case 'cancelled':
        color = FzColors.error;
        break;
      case 'in_review':
        color = FzColors.teal;
        break;
      default:
        color = FzColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
