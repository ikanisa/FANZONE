# UI Review Protocol

Use the Flutter review PWA for fast browser review of the mobile guest app.
Comments must be specific enough for a developer or Codex to act on.

## Required Comment Context

Every actionable comment should include:

- route;
- device preset;
- clicked screen location;
- severity;
- component key when known;
- screenshot or visible reproduction context;
- expected change.

## Severity

- `blocker`: prevents a core flow from being used or reviewed.
- `high`: creates a likely production UX failure or serious confusion.
- `medium`: visible issue that should be fixed before release.
- `low`: minor usability or consistency issue.
- `polish`: visual refinement that does not block release.

## Good Comments

- "On `/pools`, Pixel 4a, `pools.joinButton`: label wraps and reduces tap clarity. Keep icon visible and move long copy below the button."
- "On `/wallet`, iPhone Large, `wallet.balanceCard`: available balance is visually weaker than secondary metrics. Increase hierarchy without adding explanatory text."

## Poor Comments

- "Make this nicer."
- "This looks wrong."
- "Fix mobile."

These are not actionable unless they include route, device, visible issue, and
expected outcome.

## Resolution Status

- `open`: not reviewed or not started.
- `accepted`: valid and planned.
- `fixed`: resolved in shared Flutter code and ready for retest.
- `rejected`: not changing, with reason documented.

## Retest Rule

Browser review can approve layout direction, but final release approval still
requires real Android/iOS UAT for native behavior, performance, keyboard,
deep links, notifications, auth, and permissions.
