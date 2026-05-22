# Design System: FANZONE Venue Dashboard
**Project ID:** local-repo-apps/venue-portal

## 1. Visual Theme & Atmosphere
The Bar PWA is a dark, operational sports-bar console with a dense but controlled command-center feel. The mood is focused, high-contrast, and utilitarian: panels sit on a near-black canvas, orange actions signal staff operations, and blue accents carry navigation, focus, and system emphasis. The interface is built for repeated staff use during live service, so the visual language favors scanability, strong status contrast, and sturdy touch targets over decorative composition.

## 2. Color Palette & Roles
- **Service-Night Canvas (#0B0D10):** The primary background. It keeps the console quiet and reduces glare in venue environments.
- **Charcoal Work Surface (#14171C):** Main card and container fill for operational modules.
- **Raised Slate Panel (#1B2027):** Secondary panels, input fields, and grouped controls.
- **Control-Rail Slate (#242A33):** Hover surfaces, tertiary panels, and internal control groups.
- **Steel Divider (#303745):** Borders, outlines, and structural separation between dense data zones.
- **Clear White Text (#F8FAFC):** Primary readable text for labels, totals, headings, and active navigation.
- **Muted Blue-Gray Text (#94A3B8):** Secondary instructions, descriptions, timestamps, and lower-priority metadata.
- **Action Orange (#F97316):** Primary staff actions such as confirmations and major workflow buttons.
- **Electric Sky Blue (#38BDF8):** Focus states, accent highlights, and informational emphasis.
- **Operational Success Green (#22C55E):** Paid, complete, available, and healthy states.
- **Service Warning Amber (#F59E0B):** Pending, attention, and time-sensitive states.
- **Critical Red (#EF4444):** Failed, blocked, destructive, and risk states.

## 3. Typography Rules
The system uses Outfit as the main display and interface typeface, with JetBrains Mono reserved for compact operational numbers, codes, and technical identifiers. Text weight is assertive: body copy sits around semibold, controls use heavy or black weights, and headings use very heavy weights to keep hierarchy readable in a busy venue. Letter spacing is mostly neutral; uppercase micro-labels use wider spacing sparingly for section markers and state labels.

## 4. Component Stylings
* **Buttons:** Large, dependable controls with softly squared corners, a minimum 48px touch height, heavy text, and compact icon gaps. Primary buttons use Action Orange (#F97316) over dark text for service-critical actions. Secondary buttons use Raised Slate Panel (#1B2027) with Steel Divider (#303745) for lower-risk commands.
* **Cards/Containers:** Console cards use Charcoal Work Surface (#14171C), Steel Divider (#303745), and deep diffused shadows. Corners are generously but not playfully rounded, usually between 14px and 18px, giving the UI a durable equipment-panel quality.
* **Inputs/Forms:** Inputs sit on Raised Slate Panel (#1B2027), have clear Steel Divider strokes, and switch to Electric Sky Blue (#38BDF8) focus rings. Field text is bold and high-contrast because staff may interact under time pressure.
* **Status Chips:** Status markers are compact, high-weight, and color-coded. They should read instantly from a distance without relying only on text.
* **Navigation:** Navigation should feel like a fixed operations rail: dark, compact, and optimized for fast route switching between overview, orders, menu, pools, games, screen, wallet, insights, and settings.

## 5. Layout Principles
The layout uses constrained density: panels are information-rich, but spacing follows a predictable 4px rhythm so data does not collapse into clutter. Primary work areas should use full-width operational bands or grids rather than marketing-style cards. Repeated modules can use cards, but cards should not be nested inside other cards. Mobile layouts keep controls large and stacked; desktop layouts favor side navigation, scan-friendly grids, and persistent context around live orders and venue state.
