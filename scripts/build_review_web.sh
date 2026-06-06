#!/usr/bin/env bash
set -euo pipefail

flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release -t lib/main_review.dart \
  --dart-define=APP_RUNTIME_MODE=web_review \
  --dart-define=APP_ENV="${APP_ENV:-staging}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=DEV_WHATSAPP_OTP_PHONE="${DEV_WHATSAPP_OTP_PHONE:-+3567718613}" \
  --dart-define=DEV_WHATSAPP_OTP_CODE="${DEV_WHATSAPP_OTP_CODE:-123456}" \
  --dart-define=GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)}" \
  --dart-define=GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse HEAD 2>/dev/null || true)}"
