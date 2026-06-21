# FANZONE Flutter Mobile UX Matrix Summary

Generated from `release/qa/flutter-mobile-ux-matrix.json`.
Matrix timestamp: `2026-06-21T15:23:38Z`.

This summary is generated. Update it with `npm run generate:flutter-mobile-ux-summary`.

## Readiness

- Applicable surfaces passing strict evidence: 0/57 (0.0%).
- Incomplete applicable surfaces: 57.
- Incomplete P0/P1 surfaces: 57.
- Final 100% claim remains blocked until `node tool/validate_flutter_mobile_ux_matrix.mjs --require-pass` passes.

## Status Counts

| Value | Count |
| --- | ---: |
| pass | 0 |
| partial | 22 |
| planned | 35 |
| blocked | 0 |
| not_applicable | 1 |

## Priority Counts

| Value | Count |
| --- | ---: |
| P0 | 37 |
| P1 | 20 |
| P2 | 1 |

## Surface Type Counts

| Value | Count |
| --- | ---: |
| route | 32 |
| redirect | 3 |
| wizard | 3 |
| overlay | 19 |
| component | 1 |

## P0/P1 Incomplete Surfaces

| Priority | Status | Type | Path | Name | Missing Proof Buckets | Source |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | partial | route | /splash | Splash | compact, medium, expanded, largeText, screenReader, contrast, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/auth/screens/splash_screen.dart |
| P0 | planned | route | /feature-unavailable | Feature unavailable | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/settings/screens/feature_unavailable_screen.dart |
| P0 | partial | redirect | / | Root redirect | productBoundary, evidencePath | lib/app_router.dart |
| P0 | partial | wizard | /onboarding | Onboarding wizard | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/onboarding/screens/onboarding_screen.dart |
| P0 | partial | route | /login | WhatsApp phone login | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/auth/screens/whatsapp_login_screen.dart |
| P1 | partial | redirect | /upgrade | Upgrade redirect | productBoundary, evidencePath | lib/app_router.dart |
| P0 | planned | route | /v/:venueSlug | Venue slug entry | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/ordering/widgets/venue_entry_wrapper.dart |
| P0 | planned | route | /bar | Bar menu entry | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/ordering/screens/venue_menu_screen.dart |
| P0 | planned | route | /venue/:venueId | Venue detail | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/ordering/screens/venue_detail_screen.dart |
| P0 | partial | route | /venue/:venueId/chat | Venue chat | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, evidencePath | lib/features/ordering/screens/venue_chat_screen.dart |
| P0 | planned | route | /venues | Browse venues | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/ordering/screens/browse_venues_screen.dart |
| P0 | planned | route | /venues/location | Location access | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/ordering/screens/location_access_screen.dart |
| P1 | planned | route | /search | Global search | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/home/screens/global_search_screen.dart |
| P1 | planned | route | /match/:id | Match detail | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/home/screens/match_detail_screen.dart |
| P0 | partial | route | /checkout | Checkout | compact, medium, expanded, largeText, screenReader, contrast, reducedMotion, errorEmptyLoading, evidencePath | lib/features/ordering/screens/checkout_screen.dart |
| P0 | planned | route | /order/:orderId/success | Order success | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/ordering/screens/order_success_screen.dart |
| P0 | planned | route | /order/:orderId/receipt | Order receipt | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/ordering/screens/order_receipt_screen.dart |
| P0 | partial | route | /order/:orderId | Order tracking | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, evidencePath | lib/features/ordering/screens/order_tracking_screen.dart |
| P1 | planned | route | /notifications | Notifications | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/profile/screens/notifications_screen.dart |
| P0 | planned | route | /profile | Profile | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/profile/screens/profile_screen.dart |
| P0 | planned | route | /orders | Order history | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/ordering/screens/orders_screen.dart |
| P0 | planned | route | /wallet | FET rewards | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/wallet/screens/wallet_screen.dart |
| P1 | planned | route | /wallet/transaction/:transactionId | FET transaction details | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/wallet/screens/transaction_details_screen.dart |
| P1 | planned | route | /pool/:poolId | Pool detail | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/pools/screens/pool_detail_screen.dart |
| P1 | planned | wizard | /pool/:poolId/join | Join pool | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/pools/screens/join_pool_screen.dart |
| P1 | planned | wizard | /pools/create | Create pool | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/pools/screens/create_pool_screen.dart |
| P1 | planned | route | /game/:gameId | Game detail | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/games/screens/game_detail_screen.dart |
| P1 | partial | redirect | /games | Games redirect | productBoundary, evidencePath | lib/app_router.dart |
| P0 | partial | route | /home | Home feed | largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/home/screens/home_feed_screen.dart |
| P1 | planned | route | /home/matches | Home matches | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/home/screens/home_matches_screen.dart |
| P1 | partial | route | /pools | Pools | largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/pools/screens/pools_screen.dart |
| P1 | planned | route | /pools/games | Games list | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/games/screens/games_screen.dart |
| P0 | partial | route | /settings | Settings | largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/settings/screens/settings_screen.dart |
| P0 | partial | route | /settings/privacy | Privacy settings | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/settings/screens/privacy_settings_screen.dart |
| P0 | partial | route | /settings/help | Help and FAQ | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/settings/screens/support_info_screen.dart |
| P0 | partial | route | /settings/privacy-policy | Privacy policy | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/settings/screens/support_info_screen.dart |
| P0 | partial | route | /settings/terms | Terms of service | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/settings/screens/support_info_screen.dart |
| P1 | planned | route | /pools/:shareSlug | Pool share entry | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/pools/screens/pool_share_entry_screen.dart |
| P0 | partial | overlay | sheet:account-data-request | Account data request sheet | compact, medium, expanded, largeText, screenReader, contrast, reducedMotion, errorEmptyLoading, evidencePath | lib/features/settings/screens/privacy_settings_screen.dart |
| P0 | partial | overlay | sheet:account-deletion-request | Account deletion request sheet | compact, medium, expanded, largeText, screenReader, contrast, reducedMotion, errorEmptyLoading, evidencePath | lib/features/settings/screens/privacy_settings_screen.dart |
| P0 | planned | overlay | dialog:session-expired | Session expired dialog | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/app.dart |
| P0 | planned | overlay | sheet:sign-in-required | Sign-in required sheet | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/auth/widgets/sign_in_required_sheet.dart |
| P0 | planned | overlay | sheet:onboarding-country-code-picker | Onboarding country code picker | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/onboarding/widgets/country_code_picker.dart |
| P0 | planned | overlay | sheet:login-country-picker | Login country picker | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/auth/screens/whatsapp_login_screen.dart |
| P0 | partial | overlay | sheet:menu-item-detail | Menu item detail and customization sheet | compact, medium, expanded, largeText, screenReader, contrast, reducedMotion, errorEmptyLoading, evidencePath | lib/features/ordering/widgets/menu_item_detail_sheet.dart |
| P0 | partial | overlay | sheet:venue-support-request | Venue support request sheet | compact, medium, expanded, largeText, screenReader, contrast, reducedMotion, errorEmptyLoading, evidencePath | lib/features/ordering/screens/venue_detail_screen.dart |
| P0 | planned | overlay | sheet:payment-handoff | Off-platform payment handoff sheet | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/ordering/widgets/payment_handoff_sheet.dart |
| P0 | partial | overlay | sheet:order-support-request | Order issue, cancellation, and refund review request sheet | compact, medium, expanded, largeText, screenReader, contrast, reducedMotion, errorEmptyLoading, evidencePath | lib/features/ordering/screens/order_tracking_screen.dart |
| P0 | partial | overlay | sheet:payment-proof | Payment proof and recovery sheet | compact, medium, expanded, largeText, screenReader, contrast, reducedMotion, evidencePath | lib/features/ordering/screens/order_tracking_screen.dart |
| P1 | planned | overlay | sheet:insufficient-fet | Insufficient FET sheet | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/widgets/common/fz_reference_modals.dart |
| P1 | planned | overlay | sheet:invite-friends | Invite friends sheet | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/widgets/common/fz_reference_modals.dart |
| P1 | planned | overlay | sheet:winner-celebration | Winner celebration sheet | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/widgets/common/fz_reference_modals.dart |
| P1 | planned | overlay | sheet:notice | Notice sheet | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/widgets/common/fz_reference_modals.dart |
| P0 | planned | overlay | sheet:profile-fan-editor | Profile fan editor sheet | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, evidencePath | lib/features/profile/screens/profile_screen.dart |
| P1 | planned | overlay | dialog:game-team-name | Game team-name dialog | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/features/games/screens/game_detail_screen.dart |
| P1 | planned | overlay | sheet:eligibility-rule | Eligibility rule sheet | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, productBoundary, testEvidence, evidencePath | lib/widgets/common/fz_eligibility_rule_card.dart |
| P0 | planned | component | component:app-modal-sheet | Shared app modal sheet component | compact, medium, expanded, largeText, screenReader, contrast, keyboardSafeArea, reducedMotion, errorEmptyLoading, testEvidence, evidencePath | lib/design_system/components/app_modal_sheet.dart |

## Next Evidence Actions

- Capture compact, medium, and expanded screenshots for every P0/P1 route and overlay.
- Add or link large-text, screen-reader, contrast, keyboard/safe-area, reduced-motion, and state evidence for every P0/P1 row.
- Promote rows to `pass` only after each proof bucket points to current evidence.
- Run `node tool/validate_flutter_mobile_ux_matrix.mjs --require-pass` before any 100% or world-class claim.

