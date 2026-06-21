import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_feature_access.dart';
import '../../../models/auth_and_user/account_data_request_model.dart';
import '../../../models/auth_and_user/account_deletion_request_model.dart';
import '../../../models/auth_and_user/privacy_settings_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/account_data_request_service.dart';
import '../../../services/account_deletion_service.dart';
import '../../../services/privacy_settings_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../widgets/privacy_widgets.dart';
import '../../../widgets/common/fz_glass_loader.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _showNameInPoolActivity = false;
  bool _loading = true;
  bool _saving = false;
  bool _accountRequestBusy = false;
  AccountDataRequestModel? _dataRequest;
  AccountDeletionRequestModel? _deletionRequest;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!ref.read(isFullyAuthenticatedProvider)) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    try {
      final results = await Future.wait<Object?>([
        PrivacySettingsService.getSettings(),
        AccountDataRequestService.getLatestRequest(),
        AccountDeletionService.getLatestRequest(),
      ]);
      final settings = results[0] as PrivacySettingsModel;
      if (!mounted) return;
      setState(() {
        _showNameInPoolActivity = settings.showNameInPoolActivity;
        _dataRequest = results[1] as AccountDataRequestModel?;
        _deletionRequest = results[2] as AccountDeletionRequestModel?;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your privacy settings.';
      });
    }
  }

  Future<void> _requestDataAccess() async {
    if (!ref.read(isFullyAuthenticatedProvider) || _accountRequestBusy) {
      return;
    }

    final draft = await _showAccountDataRequestSheet(context);
    if (draft == null || !mounted) return;

    setState(() {
      _accountRequestBusy = true;
      _error = null;
    });
    try {
      final request = await AccountDataRequestService.createRequest(
        reason: draft.reason,
        contactEmail: draft.contactEmail,
      );
      if (!mounted) return;
      setState(() => _dataRequest = request);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account data request submitted.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not submit the account data request. Add details and try again.';
      });
    } finally {
      if (mounted) setState(() => _accountRequestBusy = false);
    }
  }

  Future<void> _cancelDataRequest() async {
    final request = _dataRequest;
    if (request == null || _accountRequestBusy) return;

    setState(() {
      _accountRequestBusy = true;
      _error = null;
    });
    try {
      final updated = await AccountDataRequestService.cancelRequest(request.id);
      if (!mounted) return;
      setState(() => _dataRequest = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account data request cancelled.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not cancel the data request right now.';
      });
    } finally {
      if (mounted) setState(() => _accountRequestBusy = false);
    }
  }

  Future<void> _requestDeletion() async {
    if (!ref.read(isFullyAuthenticatedProvider) || _accountRequestBusy) {
      return;
    }

    final draft = await _showAccountDeletionRequestSheet(context);
    if (draft == null || !mounted) return;

    setState(() {
      _accountRequestBusy = true;
      _error = null;
    });
    try {
      final request = await AccountDeletionService.createRequest(
        reason: draft.reason,
        contactEmail: draft.contactEmail,
      );
      if (!mounted) return;
      setState(() => _deletionRequest = request);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion request submitted.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not submit the account deletion request. Add details and try again.';
      });
    } finally {
      if (mounted) setState(() => _accountRequestBusy = false);
    }
  }

  Future<void> _cancelDeletionRequest() async {
    final request = _deletionRequest;
    if (request == null || _accountRequestBusy) return;

    setState(() {
      _accountRequestBusy = true;
      _error = null;
    });
    try {
      final updated = await AccountDeletionService.cancelRequest(request.id);
      if (!mounted) return;
      setState(() => _deletionRequest = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion request cancelled.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not cancel the deletion request right now.';
      });
    } finally {
      if (mounted) setState(() => _accountRequestBusy = false);
    }
  }

  Future<void> _updateSettings({bool? showNameInPoolActivity}) async {
    if (!ref.read(isFullyAuthenticatedProvider)) return;

    final previous = PrivacySettingsModel(
      showNameInPoolActivity: _showNameInPoolActivity,
    );
    final next = previous.copyWith(
      showNameInPoolActivity: showNameInPoolActivity,
    );

    setState(() {
      _showNameInPoolActivity = next.showNameInPoolActivity;
      _saving = true;
      _error = null;
    });

    try {
      await PrivacySettingsService.saveSettings(next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showNameInPoolActivity = previous.showNameInPoolActivity;
        _error = 'Could not save your privacy settings.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final isVerified = ref.watch(isFullyAuthenticatedProvider);
    final profileRoute = ref
        .watch(platformFeatureAccessProvider)
        .routeFor('profile');

    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            PrivacySettingsHeader(
              onBack: () => context.go(profileRoute),
              muted: muted,
              textColor: textColor,
            ),
            Expanded(
              child: _loading
                  ? const FzGlassLoader(message: 'Syncing...')
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                          children: [
                            if ((_error ?? '').isNotEmpty) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: FzColors.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: FzColors.error.withValues(
                                      alpha: 0.24,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: FzColors.error,
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              'Visibility Controls'.toUpperCase(),
                              style: FzTypography.sectionLabel(
                                Theme.of(context).brightness,
                              ).copyWith(color: muted),
                            ),
                            const SizedBox(height: 12),
                            if (!isVerified)
                              PrivacySourceCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Verify WhatsApp to manage privacy controls.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton(
                                      onPressed: () => context.go(
                                        '/login?from=${Uri.encodeComponent('/settings/privacy')}',
                                      ),
                                      child: const Text('Verify WhatsApp'),
                                    ),
                                  ],
                                ),
                              )
                            else
                              PrivacySourceCard(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    VisibilityControlRow(
                                      title: 'Display Name in Pool Activity',
                                      description:
                                          'Show your display name instead of your Fan ID on pool and share-card surfaces.',
                                      value: _showNameInPoolActivity,
                                      enabled: !_saving,
                                      showDivider: false,
                                      onChanged: (value) => _updateSettings(
                                        showNameInPoolActivity: value,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),
                            Text(
                              'Data and Account Requests'.toUpperCase(),
                              style: FzTypography.sectionLabel(
                                Theme.of(context).brightness,
                              ).copyWith(color: muted),
                            ),
                            const SizedBox(height: 12),
                            PrivacySourceCard(
                              padding: const EdgeInsets.all(16),
                              child: _AccountRequestPanel(
                                isVerified: isVerified,
                                dataRequest: _dataRequest,
                                deletionRequest: _deletionRequest,
                                busy: _accountRequestBusy,
                                muted: muted,
                                onVerify: () => context.go(
                                  '/login?from=${Uri.encodeComponent('/settings/privacy')}',
                                ),
                                onRequestData: _requestDataAccess,
                                onCancelData: _cancelDataRequest,
                                onRequestDeletion: _requestDeletion,
                                onCancelDeletion: _cancelDeletionRequest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDeletionDraft {
  const _AccountDeletionDraft({required this.reason, this.contactEmail});

  final String reason;
  final String? contactEmail;
}

class _AccountDataDraft {
  const _AccountDataDraft({required this.reason, this.contactEmail});

  final String reason;
  final String? contactEmail;
}

class _AccountRequestPanel extends StatelessWidget {
  const _AccountRequestPanel({
    required this.isVerified,
    required this.dataRequest,
    required this.deletionRequest,
    required this.busy,
    required this.muted,
    required this.onVerify,
    required this.onRequestData,
    required this.onCancelData,
    required this.onRequestDeletion,
    required this.onCancelDeletion,
  });

  final bool isVerified;
  final AccountDataRequestModel? dataRequest;
  final AccountDeletionRequestModel? deletionRequest;
  final bool busy;
  final Color muted;
  final VoidCallback onVerify;
  final VoidCallback onRequestData;
  final VoidCallback onCancelData;
  final VoidCallback onRequestDeletion;
  final VoidCallback onCancelDeletion;

  @override
  Widget build(BuildContext context) {
    if (!isVerified) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify WhatsApp to request account deletion or data support.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onVerify,
            child: const Text('Verify WhatsApp'),
          ),
        ],
      );
    }

    final activeDataRequest = dataRequest?.isActive == true
        ? dataRequest
        : null;
    final activeDeletionRequest = deletionRequest?.isActive == true
        ? deletionRequest
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeDataRequest != null)
          _RequestStatusBlock(
            title: 'Data request in review',
            status: activeDataRequest.status,
            reason: activeDataRequest.reason,
            muted: muted,
            actionLabel: 'Cancel data request',
            busy: busy,
            onCancel: onCancelData,
          )
        else
          _RequestActionBlock(
            title: 'Account data access',
            description:
                'Request support review for an account data export or correction. This does not expose raw data immediately.',
            actionLabel: 'Request data access',
            busy: busy,
            muted: muted,
            onPressed: onRequestData,
          ),
        const SizedBox(height: 18),
        Divider(color: muted.withValues(alpha: 0.2)),
        const SizedBox(height: 18),
        if (activeDeletionRequest != null)
          _RequestStatusBlock(
            title: 'Deletion request in review',
            status: activeDeletionRequest.status,
            reason: activeDeletionRequest.reason,
            muted: muted,
            actionLabel: 'Cancel deletion request',
            busy: busy,
            onCancel: onCancelDeletion,
          )
        else
          _RequestActionBlock(
            title: 'Account deletion',
            description:
                'Submit a request for support review. This does not immediately delete your account.',
            actionLabel: 'Request account deletion',
            busy: busy,
            muted: muted,
            onPressed: onRequestDeletion,
          ),
      ],
    );
  }
}

class _RequestStatusBlock extends StatelessWidget {
  const _RequestStatusBlock({
    required this.title,
    required this.status,
    required this.reason,
    required this.muted,
    required this.actionLabel,
    required this.busy,
    required this.onCancel,
  });

  final String title;
  final String status;
  final String? reason;
  final Color muted;
  final String actionLabel;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Status: ${status.replaceAll('_', ' ')}',
          style: TextStyle(color: muted, fontWeight: FontWeight.w700),
        ),
        if (reason?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Text(reason!, style: TextStyle(color: muted)),
        ],
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: busy ? null : onCancel,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _RequestActionBlock extends StatelessWidget {
  const _RequestActionBlock({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.busy,
    required this.muted,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String actionLabel;
  final bool busy;
  final Color muted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(description, style: TextStyle(color: muted, height: 1.4)),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: busy ? null : onPressed,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

Future<_AccountDataDraft?> _showAccountDataRequestSheet(BuildContext context) {
  final reasonController = TextEditingController();
  final contactController = TextEditingController();

  return showModalBottomSheet<_AccountDataDraft>(
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
            const Text(
              'Request data access',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Support reviews data access and correction requests before exporting or changing account data.',
              style: TextStyle(color: muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('account_data_reason'),
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Request details',
                hintText: 'Add at least 10 characters',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('account_data_contact'),
              controller: contactController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Contact email optional',
                hintText: 'you@example.com',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can cancel a pending request from this screen.',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('account_data_submit'),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.length < 10) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Add at least 10 characters.'),
                    ),
                  );
                  return;
                }
                final contact = contactController.text.trim();
                Navigator.of(sheetContext).pop(
                  _AccountDataDraft(
                    reason: reason,
                    contactEmail: contact.isEmpty ? null : contact,
                  ),
                );
              },
              child: const Text('Submit request'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reasonController.dispose();
      contactController.dispose();
    });
  });
}

Future<_AccountDeletionDraft?> _showAccountDeletionRequestSheet(
  BuildContext context,
) {
  final reasonController = TextEditingController();
  final contactController = TextEditingController();

  return showModalBottomSheet<_AccountDeletionDraft>(
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
            const Text(
              'Request account deletion',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Support reviews account deletion requests before permanent action.',
              style: TextStyle(color: muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('account_deletion_reason'),
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Add at least 10 characters',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('account_deletion_contact'),
              controller: contactController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Contact email optional',
                hintText: 'you@example.com',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can cancel a pending request from this screen.',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('account_deletion_submit'),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.length < 10) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Add at least 10 characters.'),
                    ),
                  );
                  return;
                }
                final contact = contactController.text.trim();
                Navigator.of(sheetContext).pop(
                  _AccountDeletionDraft(
                    reason: reason,
                    contactEmail: contact.isEmpty ? null : contact,
                  ),
                );
              },
              child: const Text('Submit request'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reasonController.dispose();
      contactController.dispose();
    });
  });
}
