import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../features/auth/widgets/sign_in_required_sheet.dart';

/// Guards a protected action by checking if the user is fully authenticated
/// (non-anonymous). If the user is a guest, shows the sign-in sheet and
/// returns false.
///
/// Usage:
/// ```dart
/// if (!requireFullAuth(context, ref, feature: 'predictions')) return;
/// // ... perform protected action
/// ```
bool requireFullAuth(BuildContext context, WidgetRef ref, {String? feature}) {
  final isGuest = ref.read(isGuestProvider);
  final isAuth = ref.read(isAuthenticatedProvider);

  // Not authenticated at all — shouldn't happen in normal flow
  if (!isAuth) {
    context.go('/login');
    return false;
  }

  // Fully authenticated — allow action
  if (!isGuest) return true;

  // Guest user — show upgrade prompt
  final featureLabel = feature ?? 'this feature';
  showSignInRequiredSheet(
    context,
    title: 'Sign In Required',
    message:
        'Create a free account to access $featureLabel. '
        'Verify with WhatsApp to unlock predictions, pools, wallet, and more.',
    from: GoRouterState.of(context).uri.toString(),
  );

  return false;
}

/// Same as [requireFullAuth] but usable with a [Ref] instead of [WidgetRef].
/// For use in plain providers or service methods.
bool checkFullAuth(Ref ref) {
  final isGuest = ref.read(isGuestProvider);
  final isAuth = ref.read(isAuthenticatedProvider);
  return isAuth && !isGuest;
}
