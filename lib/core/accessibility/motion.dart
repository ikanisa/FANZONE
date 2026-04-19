import 'package:flutter/widgets.dart';

bool prefersReducedMotion(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery == null) return false;
  return mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;
}

Duration motionDuration(BuildContext context, Duration duration) {
  return prefersReducedMotion(context) ? Duration.zero : duration;
}
