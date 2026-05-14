#!/usr/bin/env bash
set -euo pipefail

flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release -t lib/main_review.dart \
  --dart-define=APP_RUNTIME_MODE=web_review \
  --dart-define=APP_ENV="${APP_ENV:-staging}" \
  --dart-define=GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)}" \
  --dart-define=GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse HEAD 2>/dev/null || true)}"
