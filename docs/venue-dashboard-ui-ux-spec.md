# Venue Dashboard UI/UX Specification

Production design target for the FANZONE venue operations console.

## 1. Kickoff Alignment

### Task Understanding

Design the venue dashboard only. This is the operational console for bars, sports bars, pubs, lounges, restaurants, and entertainment venues. It must manage the selected venue's orders, menu, manual payment confirmation, FET wallet, staked football prediction pools, centralized entertainment games, teams, participants, live TV screen, insights, and settings.

This is not the customer Flutter app, not a global admin console, and not a bar-vs-bar experience.

### Existing Implementation Found

The current repo has a standalone React/Vite PWA in `apps/venue-portal`.

Current app shell and routes:

- `apps/venue-portal/src/App.tsx`
  - `/orders`
  - `/menu`
  - `/pools`
  - `/rewards`
  - `/tables`
  - `/insights`
  - `/settings`
- `apps/venue-portal/src/components/layout/AppShell.tsx`
  - left sidebar on desktop
  - horizontal mobile nav
  - venue header using `useVenue`
- `apps/venue-portal/src/components/console/*`
  - `MetricCard`
  - `StatusChip`
  - `EmptyState`
- `apps/venue-portal/src/features/orders/LiveOrderQueuePage.tsx`
  - active order cards
  - service status actions
  - manual payment status controls
- `apps/venue-portal/src/features/menu/MenuArchitectPage.tsx`
  - menu/category/item management surface
- `apps/venue-portal/src/features/pools/VenuePoolsPage.tsx`
  - venue-linked pool management surface
- `apps/venue-portal/src/features/rewards/FETRewardsPage.tsx`
  - FET reward configuration surface
- `apps/venue-portal/src/features/settings/QRFactoryPage.tsx`
  - table QR management surface
- `apps/venue-portal/src/features/settings/VenueSettingsPage.tsx`
  - venue settings surface
- `docs/venue-dashboard-uat.md`
  - current UAT checklist for orders, menu, pools, rewards, QR, insights, and responsive behavior

Current implementation is useful but incomplete for the requested product. It has Orders, Menu, Pools, FET Rewards, Tables/QR, Insights, and Settings, but it does not yet provide the target command center, game sessions, teams, participants, TV screen control, buy FET flow, detailed wallet ledger, pool settlement workflow, staff permissions UI, notifications center, or complete modal/state system.

### Where This Fits

The venue dashboard should remain in `apps/venue-portal` as the venue-scoped PWA. The customer Flutter app should not absorb these venue operations screens.

The design should reuse the current portal foundations:

- React/Vite routing and lazy pages
- `AppShell`
- Supabase venue context
- shared console components
- dark-first design tokens imported from `packages/core/src/designTokens.css`
- lucide icons
- card-first operational layouts

### Files Likely To Change During Implementation

This spec does not implement code directly, but the target implementation would likely affect:

- `apps/venue-portal/src/App.tsx`
- `apps/venue-portal/src/components/layout/AppShell.tsx`
- `apps/venue-portal/src/index.css`
- `apps/venue-portal/src/components/console/*`
- `apps/venue-portal/src/features/dashboard/*`
- `apps/venue-portal/src/features/orders/*`
- `apps/venue-portal/src/features/menu/*`
- `apps/venue-portal/src/features/pools/*`
- `apps/venue-portal/src/features/games/*`
- `apps/venue-portal/src/features/teams/*`
- `apps/venue-portal/src/features/participants/*`
- `apps/venue-portal/src/features/screen/*`
- `apps/venue-portal/src/features/wallet/*`
- `apps/venue-portal/src/features/insights/*`
- `apps/venue-portal/src/features/settings/*`
- `apps/venue-portal/src/hooks/*`
- `apps/venue-portal/src/services/venueOperations.ts`
- related Supabase RPCs, tables, views, policies, and migrations if backend fields are missing
- `docs/venue-dashboard-uat.md`

### Data, Model, And API Impact

The dashboard must be venue-scoped at every layer. Every query, action, detail screen, modal, and export must filter by the selected `venue_id`.

Likely data surfaces:

- venues and venue staff membership
- venue wallet balance and ledger
- menu categories and items
- orders, order items, payment events, and audit logs
- prediction pools, pool participants, prediction camps, pool ledger entries, and settlement records
- game sessions, centralized game templates, rounds, teams, players, score events, and claim reviews
- live screen sessions and display commands
- notifications and staff permissions

Implementation must avoid mock production flows. Empty states can show illustrative UI, but actions should connect to real supported flows or be permission-gated until backend support exists.

### UI/UX Impact

The target dashboard shifts the portal from a set of independent admin pages into a live venue command center.

Key UX changes:

- Overview becomes the operational home.
- Global header exposes venue state, wallet balance, active orders, active games/pools, time, and quick actions.
- Orders separate service status from payment status.
- Manual mark-paid becomes an auditable confirmation modal.
- Pools become a guided staked creation and settlement workflow.
- Games become centralized session control, not custom game authoring.
- Teams and Participants become first-class operational views.
- TV screen control becomes a dedicated module.
- FET wallet becomes a financial operations area with buying, allocation, reservations, and ledger.

### Risks And Assumptions

- Some requested modules may need backend schema/RPC work before full implementation.
- Existing pool code uses older concepts such as min/max stake and creator reward; target design replaces that with bar stake plus participant stake for venue-created pools.
- Existing `/rewards` and `/tables` routes overlap with target `/wallet` and `/screen`; implementation should migrate them without losing current settings/QR capabilities.
- Staff permissions must be enforced server-side, not only hidden in UI.
- Manual payment confirmation must write audit records.
- Eligibility must be calculated consistently across orders, pools, games, teams, participants, and settlement.

### Implementation Approach

1. Extend the venue shell first: target nav, global command header, quick actions, notifications, venue switcher, responsive behavior.
2. Add shared primitives: metric cards, status chips, eligibility badges, action cards, modals, QR cards, screen previews, activity feed, empty/loading/error states.
3. Refactor existing modules in place: Orders, Menu, Pools, Rewards/Wallet, Tables/Screen, Insights, Settings.
4. Add missing modules: Games, Teams, Participants, TV Screen Control, Wallet Ledger, Buy FET, Pool Settlement, Notifications, Staff Permissions.
5. Keep all data venue-scoped through existing `useVenue` and backend policies.
6. Update UAT tests/checklists and add frontend tests for routes, core states, and permission-gated actions.

### Architecture Preservation

- Keep `apps/venue-portal` as the PWA owner.
- Reuse existing hooks and services where their behavior matches the target.
- Extend `venueOperations.ts` instead of adding duplicate service layers.
- Reuse `packages/core` types and design tokens.
- Do not move customer app flows into the venue portal.
- Do not create custom game-logic authoring tools for venues.
- Do not introduce global leaderboards, country leaderboards, odds, or bar-vs-bar features.

## 2. Product Rules

### Scope Rules

- Every order, pool, game, team, participant, wallet transaction, and screen session is linked to one venue.
- Venue staff manage only their assigned venue.
- If a manager has multiple venues, switching venue changes the entire dashboard scope.
- No global leaderboard.
- No country leaderboard.
- No bar-vs-bar dashboard.
- No custom game logic created by venues.
- No payment API integration for MVP.
- No odds surfaces.
- No fake production actions.

### Payment Rules

- Payments are external.
- Rwanda uses MoMo USSD instructions.
- Malta/Europe uses Revolut link instructions.
- Cash, card, and other can be recorded as manual payment methods.
- Staff manually mark orders as paid.
- Mark-paid actions must be auditable.
- Payment status and service status are separate.

### FET Rules

- Bars buy FET from the platform into the venue wallet.
- Bars spend FET to sponsor games and prediction pools.
- Prediction pools are always staked.
- Creating a prediction pool deducts the bar stake from the bar FET wallet.
- Participant stake amount is configured by the venue.
- FET settlements depend on the eligibility rule.

### Eligibility Rule

Use this exact rule copy across the dashboard:

> To receive FET winnings, the user must place at least one order from this bar within 2 hours before the linked game/pool start time.

Eligibility states:

- Eligible
- Order Required
- Ineligible
- Settlement Pending
- Settled

Eligibility appears in:

- overview alerts
- order detail
- pool participants
- pool settlement
- game players
- team members
- participant view
- insights
- wallet settlement records

### Game Rules

Centralized platform games:

- Bar Trivia
- Fan Trivia
- Music Bingo
- Song Guess

Venue staff can start or schedule a session. They cannot create custom game logic.

Trivia and song guess rules:

- system randomly selects 20 questions from the approved question bank
- only the first correct team earns FET for each question
- no faster-answer bonus
- no speed-based scoring
- highest FET score team wins
- settlement requires a qualifying order within 2 hours before game start

Music Bingo rules:

- venue host can review bingo claims
- approved claims update team score
- rejected claims are logged
- settlement requires a qualifying order within 2 hours before game start

## 3. Design Direction

### Experience Keywords

- premium
- operational
- dark-first
- sports-bar-native
- fast
- manager-friendly
- staff-friendly
- high-trust
- readable
- simple

### Visual System

Use the FANZONEUI sports-bar visual direction as the primary visual reference: dark atmosphere, electric accents, large glass/clay cards, confident status chips, big numbers, strong spacing, and direct call-to-action hierarchy. Product conflicts from older mock concepts should be replaced by the venue rules in this document.

The dashboard should feel like a live operations console, not a decorative admin panel.

### Typography

Use large, heavy typography.

- Dashboard hero numbers: 44 to 56 px, weight 800 to 900
- Page title: 32 to 40 px, weight 800 to 900
- Section title: 24 to 30 px, weight 800
- Card title: 18 to 22 px, weight 700 to 800
- Body text: 16 to 18 px, weight 500 to 600
- Metadata: 14 to 16 px, weight 600
- Buttons and chips: 14 to 16 px, weight 700 to 800

Recommended fonts:

- Manrope or Outfit for titles and metrics
- Inter or system sans for functional UI
- JetBrains Mono only for IDs, codes, and ledger references

The current venue portal uses Outfit and JetBrains Mono. That is acceptable and should be retained unless the design system moves all apps to Manrope/Inter.

### Color Tokens

Use existing core tokens first:

- background: `--fz-bg`
- surface: `--fz-surface`
- surface 2: `--fz-surface-2`
- surface 3: `--fz-surface-3`
- border: `--fz-border`
- text: `--fz-text`
- muted: `--fz-muted`
- primary/electric accent: `--fz-primary`
- secondary/action: `--fz-secondary`
- success: `--fz-success`
- warning: `--fz-warning`
- danger: `--fz-error`

Target usage:

- Dark near-black background.
- Matte elevated panels with subtle clay shadows.
- Thin glass borders and low-opacity highlights.
- Electric accent reserved for primary actions, live status, wallet highlights, and selected nav.
- Warning reserved for unpaid, order-required, insufficient FET, or pending verification.
- Danger reserved for cancelled, disputed, rejected, or destructive actions.
- Success reserved for paid, served, eligible, settled, connected.

Avoid one-note palettes. The page should not read as only purple, slate, beige, brown, or neon.

### Layout

Desktop and tablet:

- left sidebar, 280 px expanded, 80 px collapsed
- global command header, 84 to 104 px high
- main content max width 1440 to 1600 px depending on page
- overview uses responsive metric grid plus live activity rail
- dense data should use cards or hybrid rows, not enterprise tables

Mobile:

- top compact venue header
- horizontal section navigation or bottom drawer
- cards stack vertically
- modal sheets use full-width bottom sheet behavior
- critical actions remain 1 to 2 taps away

### Surfaces

Use:

- large cards for metrics and operational objects
- segmented controls for filters and modes
- icon buttons for quick tools
- chips for status
- drawers or sheets for details when the user should not lose context
- full pages for creation and settlement flows

Avoid:

- nested cards
- tiny metadata
- dense table grids
- decorative hero blocks
- marketing copy
- fake analytics charts
- overly complex forms

## 4. Information Architecture

### Primary Navigation

1. Overview
2. Orders
3. Menu
4. Pools
5. Games
6. Teams
7. Screen
8. FET Wallet
9. Insights
10. Settings

Participants should be accessible from Teams, Games, Pools, Overview alerts, and Insights. It can also exist as `/participants` if implementation needs a direct route, but it should not crowd the primary nav unless research shows staff need it constantly.

### Target Routes

- `/overview`
- `/orders`
- `/orders/:orderId`
- `/menu`
- `/menu/items/new`
- `/menu/items/:itemId`
- `/pools`
- `/pools/new`
- `/pools/:poolId`
- `/pools/:poolId/settle`
- `/games`
- `/games/new`
- `/games/:sessionId/control`
- `/teams`
- `/teams/:teamId`
- `/participants`
- `/screen`
- `/wallet`
- `/wallet/buy`
- `/wallet/ledger`
- `/insights`
- `/settings`
- `/settings/profile`
- `/settings/payments`
- `/settings/permissions`
- `/settings/screen`
- `/notifications`

### Existing To Target Route Map

| Current route | Target route | Action |
| --- | --- | --- |
| `/orders` | `/orders` | Keep and refactor to target order cards, detail route, and mark-paid modal. |
| `/menu` | `/menu` | Keep and refactor into menu overview plus item create/edit. |
| `/pools` | `/pools` | Keep and replace older pool model UI with bar stake plus participant stake flow. |
| `/rewards` | `/wallet` or `/settings/fet-rewards` | Migrate reward settings into Wallet and Settings. |
| `/tables` | `/screen` and `/settings/screen` | Keep QR utility but move TV/live screen control to Screen module. |
| `/insights` | `/overview` and `/insights` | Split command center from deeper insights. |
| `/settings` | `/settings/*` | Keep and add payment, staff, screen, FET reward settings. |

## 5. Global Shell

### Sidebar

Use icon-led nav with labels:

- Overview: `LayoutDashboard`
- Orders: `ClipboardList`
- Menu: `Utensils`
- Pools: `Trophy`
- Games: `Gamepad2`
- Teams: `UsersRound`
- Screen: `MonitorPlay`
- FET Wallet: `Coins`
- Insights: `ChartNoAxesCombined`
- Settings: `Settings`

Each item has:

- active selected state
- unread/attention dot where needed
- permission lock if staff role cannot access
- collapsed icon-only mode with tooltip

### Global Header

Every screen should show:

- selected venue name
- venue switcher if user can manage multiple venues
- Open/Closed/Paused live status
- current date/time
- FET wallet balance
- active orders count
- active games/pools count
- notification button
- staff profile and role
- quick action button

Header layout:

- left: venue name, location, open status
- center: live metrics as compact pills
- right: notifications, profile, primary quick action

Quick action menu:

- Start Game
- Create Pool
- Add Menu Item
- Open Screen

### Notification Center

Notification categories:

- Payment submitted
- Payment dispute
- Order waiting
- Eligible settlement ready
- User joined but needs order
- FET wallet low
- Screen disconnected
- Pool joining deadline near
- Bingo claim pending
- Permission blocked

Notification item anatomy:

- icon
- short title
- venue-scoped entity link
- timestamp
- severity chip
- action button where useful

## 6. Reusable Components

### Metric Card

Used on Overview, Wallet, Orders, Pools, Games, Insights.

Anatomy:

- icon in 44 px square
- label, 14 to 16 px bold
- primary value, 44 to 56 px black weight
- comparison or supporting note, 16 px
- optional status chip
- optional quick action

States:

- neutral
- success
- warning
- danger
- live
- loading skeleton
- empty

### Status Chips

Status chips must be visually clear, readable, and large enough for staff to scan quickly.

Order service:

- Received: blue/electric
- Preparing: warning/amber
- Served: success
- Cancelled: danger

Payment:

- Unpaid: warning
- Submitted: electric/info
- Paid: success
- Partial: amber
- Refunded: muted/info
- Disputed: danger

Pools/Games:

- Draft: muted
- Scheduled: info
- Live: success/electric with pulse dot
- Closed: muted
- Settling: warning
- Settled: success
- Cancelled: danger

Eligibility:

- Eligible: success
- Order Required: warning
- Ineligible: danger
- Settlement Pending: info
- Settled: success with check

### Eligibility Badge

Reusable badge with:

- state label
- icon
- optional countdown window
- optional "N needs order" aggregate
- tooltip or drawer with the exact eligibility rule

Badge must appear consistently and never use ambiguous labels such as "maybe eligible."

### Action Card

Used for quick actions and empty states.

Anatomy:

- icon
- title
- one-line operational context
- primary CTA
- optional secondary CTA

### Activity Feed

Used on Overview, order detail, pool detail, game control, team detail, participant view.

Entry anatomy:

- icon/status
- event text
- actor
- timestamp
- entity link
- audit marker where applicable

### Confirmation Modal

Used for high-impact actions:

- Mark Paid
- Cancel Order
- Create Pool
- Deduct FET Stake
- Settle Pool
- Start Game
- End Game
- Approve/Reject Bingo Claim
- Buy FET Request

Anatomy:

- clear title
- consequence summary
- required fields
- audit warning where applicable
- primary confirm button
- secondary cancel button
- permission state

### QR Card

Used for pool invites, game join links, team invites, table links, and TV screen preview.

Anatomy:

- QR image
- destination label
- short code or URL
- copy button
- display on screen button
- download/share button where supported

### Screen Preview Card

Miniature TV frame with:

- aspect ratio 16:9
- current mode label
- connected status
- venue brand strip
- QR area
- live content preview
- push to screen CTA

### Empty States

Every empty state has:

- icon
- short title
- one helpful sentence
- one clear CTA
- optional secondary link only when useful

No empty state should use fake rows as if real data exists.

## 7. Screen Specifications

### 7.1 Login / Venue Access

Purpose:

Authenticate staff and select a venue.

Layout:

- full-screen dark venue access screen
- left side or top area: venue console brand and product category
- main panel: email/password or magic link auth
- after login: venue selection if staff has multiple venues

Fields:

- email
- password or magic link
- optional staff code if required later

States:

- unauthenticated
- loading
- invalid credentials
- no assigned venue
- multiple venues
- insufficient permissions

Primary actions:

- Sign in
- Continue to selected venue
- Contact owner/admin if no venue assigned

### 7.2 Overview

Purpose:

Operational command center for the current venue.

Top section:

- page title: "Live command center"
- subtitle: selected venue, open status, current shift
- quick actions row:
  - Create Prediction Pool
  - Start Bar Trivia
  - Start Fan Trivia
  - Start Music Bingo
  - View Orders
  - Open TV Screen

Metric cards:

- Today's orders
- Pending payments
- Served orders
- Active games
- Active prediction pools
- FET wallet balance
- FET staked today
- FET rewards pending
- Active teams
- Players currently joined
- Live screen status
- Revenue/order summary

Eligibility alert band:

- users joined games/pools but have not ordered
- users eligible for FET settlement
- pools/games approaching start with missing orders

Main layout:

- left: metric grid and active operations
- right: live activity feed

Live operations cards:

- current active orders
- active game session
- active pool
- next scheduled pool/game
- screen currently showing

Empty states:

- no active orders: CTA "Open Orders"
- no active games: CTA "Start Game"
- no active pools: CTA "Create Pool"
- no screen connected: CTA "Open Screen Control"

### 7.3 Orders List

Purpose:

Fast order operations with separate service and payment controls.

Layout:

- page title and summary metrics
- segmented filters:
  - Active
  - Pending Payment
  - Served
  - Cancelled
  - All
- search by order number, user ID, table/reference
- order cards in priority order

Order card anatomy:

- order number
- customer 6-digit user ID
- table/reference
- items summary
- total amount and currency
- payment method:
  - MoMo USSD
  - Revolut link
  - cash
  - card
  - other
- payment status chip
- service status chip
- FET earned
- linked eligibility impact
- time received
- action buttons:
  - Mark Paid
  - Mark Served
  - Cancel
  - View Details

Priority rules:

- payment submitted or disputed orders at top
- unpaid active orders next
- preparing/received orders next
- served paid orders lower

### 7.4 Order Detail

Purpose:

Full order audit and eligibility context.

Sections:

- order hero with number, user ID, table, total, service status, payment status
- full item list with quantity, modifiers, item notes, FET earned
- payment timeline
- service timeline
- manual payment audit trail
- linked pools/games affected by the eligibility rule
- staff action panel

Staff actions:

- Mark Paid
- Mark Served
- Cancel
- Add internal note
- View participant profile

Audit trail row:

- action
- before/after status
- amount
- payment method
- reference/note
- staff actor
- timestamp

### 7.5 Manual Mark-Paid Flow

Trigger:

- order card
- order detail
- payment submitted notification

Modal/sheet fields:

- amount received
- payment method
- reference/note
- staff confirmation checkbox
- optional partial payment toggle if supported

Required warning:

> This action will be logged.

Confirmation summary:

- order number
- user ID
- amount due
- amount received
- selected method
- eligibility impact

After confirmation:

- order payment status becomes Paid or Partial
- payment event is written
- audit log is written
- linked eligibility statuses refresh
- dashboard shows eligibility update

Blocked states:

- cancelled order
- insufficient permission
- amount missing
- duplicate payment confirmation

### 7.6 Menu Management

Purpose:

Manage what guests can order and how FET is earned from items/categories.

Top metrics:

- active items
- unavailable items
- top ordered items
- items with FET rewards

Controls:

- category segmented filter
- search
- Add Menu Item
- Manage Categories
- Promotions

Menu item card:

- item image placeholder or image
- item name
- category
- price
- currency
- availability chip
- FET earn rate
- quick edit price
- availability toggle
- edit action

Category management:

- category name
- sort order
- active/unavailable
- item count
- drag reorder if supported

### 7.7 Menu Item Create/Edit

Purpose:

Create and update menu items without dense admin forms.

Fields:

- item name
- category
- description
- price
- currency
- image
- availability
- FET earn rate override
- modifiers/options if supported
- promotion flag if supported

Layout:

- left: form
- right: live item card preview

Validation:

- price required
- currency required
- category required
- FET earn rate cannot be negative

Actions:

- Save Item
- Save And Mark Available
- Mark Unavailable
- Delete only for permitted owner/manager roles

### 7.8 Prediction Pools List

Purpose:

Manage staked football prediction pools for the venue.

Top metrics:

- live pools
- scheduled pools
- FET staked
- pending settlement
- users needing orders

Pool card:

- match
- league
- pool status
- start time/countdown
- linked venue
- bar stake amount
- participant stake amount
- total pot FET
- number of participants
- prediction distribution:
  - home win
  - draw
  - away win
- order eligibility stats:
  - joined users
  - eligible users
  - joined but no qualifying order
- actions:
  - View Pool
  - Invite Public
  - Show on Screen
  - Close Joining
  - Settle Pool

Filters:

- Live
- Scheduled
- Closed
- Settling
- Settled

### 7.9 Create Prediction Pool Flow

Use a step-by-step full-page flow with a persistent summary rail.

Step 1: Select match

- search match
- league
- home team
- away team
- start time
- venue eligibility window preview

Step 2: Set stake

- bar stake FET
- participant stake FET
- bar wallet balance
- projected initial pot
- warning if insufficient FET

Step 3: Set rules

- join deadline
- eligibility reminder:
  - "Winners receive FET only if they placed at least one order from this bar within 2 hours before start time."
- schedule/recurring if supported

Step 4: Preview

- match
- total initial pot
- participant stake
- bar stake
- join deadline
- eligibility rule
- invite/public link preview
- screen preview

Step 5: Confirm

- staff confirmation
- audit note
- deduct bar stake from bar wallet
- create pool
- generate QR/invite link

Blocked states:

- insufficient FET balance
- match already has venue pool if rules disallow duplicates
- missing join deadline
- start time in past
- permission denied

### 7.10 Pool Detail

Purpose:

Operate one pool from creation through settlement.

Hero:

- match teams
- league
- status
- countdown
- start time
- Show on Screen button

Metric cards:

- total pot
- bar stake
- participant stake
- participants
- eligible participants
- participants needing order

Prediction camps:

- home win
- draw
- away win

Each camp card:

- participant count
- total camp stake
- distribution percentage
- eligible count
- order-required count

Participant list:

- 6-digit user ID
- selected prediction camp
- stake amount
- order eligibility state
- order reference if eligible
- settlement state

Tools:

- Invite/share
- QR card
- Close Joining
- Settle Pool
- View Audit
- Open TV Screen

Audit trail:

- created
- bar stake deducted
- participant joined
- joining closed
- result entered
- settlement confirmed

### 7.11 Pool Settlement

Purpose:

Confirm final result and distribute FET to eligible winners.

Sections:

- final match result
- winning option
- total winners
- eligible winners
- ineligible winners
- total FET pot
- amount per eligible winner
- ledger preview
- audit note

Settlement preview row:

- user ID
- prediction
- eligibility
- order reference
- payout amount
- payout status

Confirmation:

- checkbox: "I confirm the final result and settlement preview."
- required audit note for manual correction
- Confirm Settlement button

After settlement:

- pool status becomes Settled
- eligible winner ledger entries are created
- ineligible winners remain visible with reason
- wallet pending settlement updates
- TV winner screen can be launched

### 7.12 Games List

Purpose:

Start, schedule, and monitor centralized game sessions.

Top metrics:

- active sessions
- scheduled sessions
- completed today
- teams playing
- players joined
- FET reserved

Game templates:

- Bar Trivia
- Fan Trivia
- Music Bingo
- Song Guess

Template card:

- game icon
- game name
- short operational description
- estimated duration if known
- Start button
- Schedule button

Session card:

- game name
- status
- start time
- reward pool FET
- teams count
- players count
- current round
- order eligibility stats
- actions:
  - Control
  - View Teams
  - Show on Screen
  - End Game

### 7.13 Start Game Flow

Use a guided flow with the same pattern as pool creation.

Step 1: Choose game

- Bar Trivia
- Fan Trivia
- Music Bingo
- Song Guess

Step 2: Set reward

- reward pool FET
- bar wallet balance
- warning if insufficient balance
- estimated payout model

Step 3: Schedule

- start now
- schedule later
- recurring option if supported

Step 4: Rules preview

- 20 questions selected by system
- first correct team wins each question
- no speed bonus
- highest FET score team wins
- FET settlement requires qualifying order within 2 hours before start time

Step 5: Confirm

- reserve/deduct reward pool FET according to ledger rules
- create game session
- generate join QR/invite link
- show screen option

Blocked states:

- insufficient FET
- no permission
- no centralized template available
- screen unavailable if trying to launch immediately

### 7.14 Game Control Screen

Purpose:

Live operator console for venue host.

Global game bar:

- game name
- status
- current round out of 20
- start/pause/resume/end buttons
- next round button if manual
- show on screen button

Main layout:

- left: current question/song/bingo state
- center: live teams and answer/claim state
- right: leaderboard and eligibility stats

Trivia/song guess round card:

- current question
- answer options
- round timer if supported
- first correct validated team
- FET awarded
- round status
- Next Round

Music Bingo claim card:

- claim team
- claimed line/pattern
- pending verification
- approve/reject buttons
- score impact preview

Leaderboard:

- team rank
- team name
- FET score
- eligible member count
- members needing orders

Operator safety:

- ending game requires confirmation
- rejected claims require optional note
- settlement preview appears after completion

### 7.15 Teams List

Purpose:

Manage teams/camps linked to game sessions.

Top metrics:

- active teams
- active games
- eligible members
- members needing order

Team card:

- team name
- linked game
- members count
- FET score
- eligibility count:
  - eligible members
  - members needing order
- invite code
- status
- actions:
  - View Team
  - Copy Invite
  - Show QR

Filters:

- Active
- Needs Order
- Winning
- Completed

### 7.16 Team Detail

Purpose:

Inspect a team and member eligibility.

Sections:

- team hero with game, score, status
- member list by 6-digit user ID
- each member eligibility state
- score contributions
- invite link/QR
- audit/activity log

Member row:

- user ID
- joined time
- eligibility badge
- latest qualifying order if any
- FET pending
- FET settled
- remove/flag action if permitted

Audit:

- team created
- member joined
- score event
- eligibility updated
- member removed/flagged

### 7.17 Participants / Player View

Purpose:

Global venue-scoped participant operations view.

Access:

- direct route `/participants`
- linked from Overview alerts, Pools, Games, Teams, and Insights

Participant row:

- 6-digit user ID
- joined pools
- joined games
- team
- order status
- eligibility status
- FET pending
- FET settled
- activity timestamp

Detail drawer:

- user ID
- joined pools
- joined games
- team/camp history
- qualifying orders
- eligibility timeline
- FET ledger entries
- staff notes if supported

Filters:

- Eligible
- Order Required
- Ineligible
- Settlement Pending
- Settled

Primary actions:

- View Orders
- View Team
- View Pool
- Copy User ID

### 7.18 TV Screen Control

Purpose:

Control what appears on the bar TV/live display.

Top status:

- connected screen indicator
- current mode
- last pushed timestamp
- active venue display session
- reset screen button

Screen modes:

- Venue welcome
- Menu/promotions
- Active prediction pool
- Pool distribution
- Active game lobby
- Game question
- Game leaderboard
- Winner celebration
- QR join screen
- Order promo / FET reminder

Layout:

- left: display mode selector
- center: 16:9 TV preview
- right: content source and controls

Controls:

- select display mode
- choose linked pool/game/menu promotion
- generate QR code
- sponsor/promo strip toggle
- push to screen
- reset screen

Disconnected state:

- headline: "No screen connected"
- body: "Connect a venue display to push live games, pools, menus, and QR screens."
- CTA: "Create Screen Link"

### 7.19 TV Screen Preview

Purpose:

Show exactly what staff will push to the venue display.

Prediction Pool preview:

- match
- pot
- participant distribution
- QR code
- eligibility reminder

Game preview:

- game title
- current round
- leaderboard
- QR code
- venue brand strip

Winner preview:

- winning team/camp
- FET won
- celebration animation state
- QR to join next game or order

Preview rules:

- fixed 16:9 frame
- never cropped in desktop or tablet
- text remains readable
- QR always high contrast
- screen status visible outside the preview frame

### 7.20 FET Wallet

Purpose:

Manage the venue's FET balance, allocations, reservations, settlements, and top-ups.

Hero:

- bar FET balance
- Buy FET CTA
- wallet status
- low balance warning if applicable

Metric cards:

- FET staked in pools
- FET reserved for games
- FET pending settlement
- FET distributed
- FET bought this month

Wallet actions:

- Buy FET from platform
- Allocate FET to pool
- Allocate FET to game
- View ledger
- Download/export statement if supported

Transaction history:

- type
- amount
- direction
- reference
- date
- staff/admin actor
- linked entity
- status

### 7.21 Buy FET Flow

Purpose:

Let venues request or initiate FET wallet top-up from the platform.

Flow:

1. Amount selector
2. Package cards
3. Payment instruction or invoice request
4. Staff confirmation
5. Confirmation pending state
6. Wallet top-up status

Package card:

- FET amount
- estimated local currency price if available
- best for label
- Select button

Payment instruction panel:

- platform instructions
- reference code
- support/contact action
- pending confirmation note

States:

- pending invoice
- awaiting platform confirmation
- completed
- rejected
- expired

### 7.22 Wallet Ledger

Purpose:

Auditable financial record for FET movement.

Ledger row:

- type
- amount
- direction
- reference
- date
- staff/admin actor
- linked pool/game/order
- status

Transaction types:

- FET purchase
- pool stake reserved
- game reward reserved
- participant stake received
- settlement paid
- refund
- adjustment

Filters:

- All
- In
- Out
- Reserved
- Settlement
- Purchase
- Adjustment

Export:

- CSV or statement download if supported
- export action permission-gated

### 7.23 Insights

Purpose:

Simple operational guidance, not overloaded analytics.

Top metrics:

- orders today
- revenue/order summary
- active game participation
- pool participation
- FET used to attract customers
- settlement pending

Cards:

- top menu items
- best performing game types
- users joined but did not order
- users made eligible through orders
- revenue/FET relationship
- wallet outlook

Recommendation cards:

- "Start Fan Trivia before tonight's match."
- "12 joined users still need an order to unlock FET settlement."
- "Music Bingo performed well after last match."
- "Your FET wallet is low for upcoming pools."

Avoid:

- complex dashboards
- tiny charts
- global comparisons
- country/bar leaderboards

### 7.24 Settings

Purpose:

Configure venue operations.

Sections:

- venue profile
- opening hours
- payment settings
- MoMo USSD instructions
- Revolut link
- staff permissions
- screen settings
- FET reward settings
- notification settings

Venue profile:

- venue name
- address
- phone/contact
- logo
- cover image
- open/closed status

Payment settings:

- available external methods
- MoMo USSD instructions
- Revolut link
- cash/card/other toggles
- manual payment note requirements

Screen settings:

- display pairing code
- default welcome mode
- promo strip
- idle timeout
- emergency reset

FET reward settings:

- default earn rate
- category/item override behavior
- wallet low balance threshold
- settlement approval rules if needed

### 7.25 Staff Permissions

Purpose:

Make role capabilities visible and permission-friendly.

Roles:

- Owner
- Manager
- Cashier
- Waiter
- Game Host

Permission matrix:

- buy FET
- create pool
- stake FET
- settle pool
- mark paid
- refund/dispute
- edit menu
- start game
- end game
- approve bingo claim
- manage screen
- manage staff

UI behavior:

- allowed actions are visible and enabled
- restricted actions can show locked state with short reason
- high-impact actions show confirmation modal
- backend must enforce permissions

### 7.26 Notifications

Purpose:

Keep staff aware of operational issues without noise.

Notification filters:

- Orders
- Payments
- Eligibility
- Wallet
- Games
- Pools
- Screen
- System

Notification item:

- icon
- title
- short description
- entity link
- status chip
- timestamp
- action button

Examples:

- "Payment submitted for order #A184"
- "8 pool participants still need an order"
- "Bingo claim needs review"
- "FET wallet below planned game reward"
- "TV screen disconnected"

### 7.27 Empty, Loading, And Error States

Required empty states:

- No active orders: CTA "View Menu QR"
- No active games: CTA "Start Game"
- No active pools: CTA "Create Pool"
- No teams yet: CTA "Open Game Lobby"
- No FET wallet balance: CTA "Buy FET"
- No menu items: CTA "Add Menu Item"
- No screen connected: CTA "Create Screen Link"
- No eligible winners yet: CTA "Review Eligibility"

Loading states:

- skeleton metric cards
- skeleton cards for order/pool/game lists
- spinner only for short modal submissions
- full-page loading only on first route load

Error states:

- failed load with retry
- permission denied with role context
- network error with retry
- insufficient FET with Buy FET CTA
- screen push failed with reconnect action

## 8. Module-Specific Interaction Details

### Orders

Service statuses:

- received
- preparing
- served
- cancelled

Payment statuses:

- unpaid
- payment_submitted
- paid
- partially_paid
- refunded
- disputed

Payment method labels:

- MoMo USSD
- Revolut link
- Cash
- Card
- Other

Design rule:

Service status and payment status must never be combined into one ambiguous label.

### Pools

Bars create official venue pools using:

- selected match
- bar stake FET
- participant stake FET
- join deadline
- eligibility rule

The old "min stake / max stake / creator reward" pattern should not be the primary venue-created pool UI. If retained for migration or admin compatibility, hide it behind legacy compatibility only and expose the target simple model to venue staff.

### Games

The dashboard can:

- choose a centralized template
- set reward pool
- start now
- schedule later
- control session
- show on TV
- end game
- settle FET according to rules

The dashboard cannot:

- create custom questions
- create custom scoring logic
- add speed bonuses
- add venue-specific game variants in MVP

### Screen Control

TV control must be treated as an operations module, not just a QR table utility.

Core jobs:

- push active pool screen
- push game lobby
- push current question
- push leaderboard
- push winner screen
- show order/FET reminder
- reset to venue welcome

### Wallet

Wallet must distinguish:

- available balance
- reserved FET
- staked FET
- pending settlement
- distributed FET

This prevents venue staff from accidentally over-allocating FET to games or pools.

## 9. Responsive Behavior

### Desktop

- left nav expanded by default
- global header shows all live pills
- overview metric grid uses 4 columns where space allows
- detail pages use two-column layout
- game control uses three operational columns
- TV preview stays 16:9 and large

### Tablet

- left nav can collapse automatically
- global header wraps live pills
- cards use 2 columns
- modals can become side sheets
- game control stacks current round above leaderboard

### Mobile

- compact header
- horizontal nav or bottom sheet section switcher
- primary action remains sticky where useful
- cards stack
- forms become single column
- TV preview remains 16:9
- no text truncation that hides critical values

## 10. Accessibility And Readability

- Minimum touch target: 44 px.
- Buttons use icon plus text for critical operations.
- Icon-only buttons require labels/tooltips.
- Body text should not drop below 16 px in operational cards.
- Chips should be readable at a glance.
- Color cannot be the only status indicator.
- QR codes must have high contrast.
- Confirmation modals must identify consequences in plain language.
- All keyboard focus states must be visible.

## 11. Audit And Permission UX

Audit-required actions:

- mark paid
- change payment status
- cancel order
- create pool
- deduct/stake FET
- close joining
- settle pool
- start game
- end game
- approve/reject bingo claim
- buy FET request
- wallet adjustment
- staff permission changes
- screen reset if logged

Audit UI pattern:

- show "This action will be logged."
- show entity and before/after impact
- require note for risky changes
- show actor after confirmation in activity feed

Permission UI pattern:

- disabled/locked action uses lock icon and reason
- do not hide important modules entirely from staff who need read-only context
- backend policy is the source of truth

## 12. Implementation Phasing

### Phase 1: Shell And Design System

- update `AppShell` nav to target IA
- add command header
- add notification entry point
- add quick action menu
- extend shared console components
- define status and eligibility chip taxonomy

### Phase 2: Existing Module Refactor

- refactor Orders into target list/detail/mark-paid modal
- refactor Menu into overview plus item create/edit
- refactor Pools into target staked flow and detail screen
- migrate Rewards into Wallet and Settings
- split Insights from Overview

### Phase 3: Missing Operations Modules

- add Games list/start/control screens
- add Teams list/detail
- add Participants view
- add Screen control and TV preview
- add Buy FET and Wallet ledger
- add Staff Permissions and Notifications

### Phase 4: Verification And Polish

- frontend route tests
- permission state tests
- modal validation tests
- responsive screenshots for desktop/tablet/mobile
- UAT checklist update
- manual data checks against Supabase RLS/RPC rules

## 13. Regression Guardrails

- Do not change customer Flutter app routes for venue staff operations.
- Do not introduce mock venue production actions.
- Do not duplicate service layers when `venueOperations.ts` can be extended.
- Do not show cross-venue data.
- Do not show global/country/bar-vs-bar leaderboards.
- Do not merge payment and service status.
- Do not let UI-only permission checks replace backend enforcement.
- Do not settle FET without eligibility state visible to staff.
- Do not create custom venue game logic in MVP.

## 14. Acceptance Checklist

The design is implementation-ready when:

- all 27 requested screens/states are mapped
- target routes are defined
- global shell and header behavior are defined
- reusable components are defined
- status and eligibility chips are defined
- manual payment confirmation is auditable
- prediction pool creation includes bar stake and participant stake
- games are centralized platform sessions
- teams and participants are visible and venue-scoped
- TV/live screen control has modes and preview
- FET wallet has balance, top-up, reservations, settlements, and ledger
- settings include payment, staff, screen, FET, and notifications
- empty/loading/error states have clear CTAs
- responsive behavior is specified for desktop, tablet, and mobile
- implementation preserves existing portal architecture and replaces conflicting legacy pool/reward/table concepts cleanly

