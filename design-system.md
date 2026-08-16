# Subly — Design System

> The single source of truth for visual language, interaction patterns, and component behaviour across Subly's iPhone application. Use this document to (a) populate the Figma library and (b) audit any rendered screen.

**Product:** Subscription & recurring payment manager
**Platform:** iOS 17+ (iPhone-first, UIKit + Storyboards/XIBs)
**Bar:** Apple-grade craft, fintech-grade clarity, calm-app restraint
**Anti-bar:** Blue/purple dominance, neon, gradients, chart-heavy dashboards, decorative motion

---

## 1. Identity & Philosophy

Subly is a calm financial utility. The system is built on five principles:

| Principle | What it means in practice |
|-----------|---------------------------|
| **Minimal** | Every pixel earns its place. Restraint is the aesthetic. |
| **Calm** | Warm neutrals dominate; color is a status signal, never decoration. |
| **Premium** | Generous whitespace, soft elevation, restrained motion. |
| **Native** | Rounded numerals, SF Symbols, system controls, HIG-compliant spacing. |
| **Confident** | Strong hierarchy, single primary action per screen, fast scan paths. |

### 1.1 Reference quality bar

Visual cousins: **Apple Wallet · Copilot Money · Things 3 · Cron · Lookback (Notion)**.
The product should sit comfortably next to a first-party Apple app on the home screen.

### 1.2 Voice tone (microcopy)

- Calm, not corporate. ("You're all set." not "Operation completed successfully.")
- Specific, not jargon. ("Renews in 3 days" not "Cycle imminent.")
- Encouraging in empty states. ("Add your first subscription to start tracking.")
- Honest in errors. ("We couldn't save that. Please try again.")

---

## 2. Color tokens

### 2.1 Palette philosophy

**No blue. No purple. No neon.** The brand identity rests on:

- A **warm off-white paper** background
- A **sage-green accent** that doubles as the brand color
- **Muted amber** for warnings (renewal-near)
- **Muted terracotta** for destructive
- All accents tuned to feel like ink on paper, not pixels on a screen

### 2.2 Token table

> Hex values are sRGB. Use these exact codes when building Figma color styles. Each entry maps to a named asset in `Resources/Assets.xcassets`.

| Token | Asset name | Light (sRGB) | Dark (sRGB) | Role |
|-------|-----------|--------------|-------------|------|
| `background` | `Background` | `#FBF9F6` | `#100E0C` | App canvas |
| `surface` | `Surface` | `#FFFFFF` | `#1A1816` | Cards, sheets, cells |
| `surfaceElevated` | `SurfaceElevated` | `#F4F1EC` | `#232120` | Pickers, popovers |
| `textPrimary` | `TextPrimary` | `#1B1A18` | `#F2EFE9` | Headings, values |
| `textSecondary` | `TextSecondary` | `#67635B` | `#A39E94` | Captions, labels |
| `textTertiary` | `TextTertiary` | `#9A9489` | `#6B6856` | Disabled, hints |
| `separator` | `Separator` | `#E6E1D8` | `#2C2A26` | Hairline dividers |
| `accent` | `AccentColor` | `#3F7A5C` (sage) | `#6FA68A` | Brand, primary action |
| `success` | `SuccessColor` | `#3F7A5C` | `#6FA68A` | Confirmation |
| `warning` | `WarningColor` | `#C68A45` (amber) | `#E5B26B` | Renewal-near, caution |
| `danger` | `DangerColor` | `#C2553B` (terracotta) | `#DE7860` | Destructive |

> Token names map 1:1 with Figma styles and Swift `DesignSystem.Colors.<token>`.

### 2.3 Usage rules

| ✅ Do | ❌ Don't |
|------|---------|
| Use `accent` for **at most one** call-to-action per screen | Tint every icon with accent |
| Use `warning` for renewals within 3 days | Use `warning` as decoration |
| Pair `danger` only with destructive verbs (Delete, Cancel subscription) | Use `danger` for badges or counts |
| Tone-shift status with **opacity 0.12** for chip backgrounds | Invent new pastel variants |
| Run every screen in both light and dark before merging | Ship "we'll do dark mode later" |

### 2.4 Contrast checks

All text/background pairs in §2.2 meet **WCAG AA** at body sizes (4.5:1 minimum) in both appearances. `textTertiary` is reserved for non-critical hints and large display sizes only.

---

## 3. Typography

### 3.1 Scale

| Token | Style | Weight | Apple text style | Notes |
|-------|-------|--------|------------------|-------|
| `largeTitle` | 34pt | Bold | `.largeTitle` | Navigation large titles, hero screens |
| `title` | 22pt | Semibold | `.title2` | Card headers, sheet titles |
| `headline` | 17pt | Semibold | `.headline` | Primary cell text, buttons |
| `body` | 17pt | Regular | `.body` | Default reading text |
| `subhead` | 15pt | Regular | `.subheadline` | Secondary cell text |
| `footnote` | 13pt | Regular | `.footnote` | Hint text, dates |
| `caption` | 12pt | Regular | `.caption1` | Chips, micro labels |
| `amount` | 28pt | Bold, **SF Rounded** | `.title1` | Dashboard total, detail price |
| `amountCompact` | 17pt | Semibold, **SF Rounded** | `.headline` | List row prices |

### 3.2 Rules

- Every text style is registered against an Apple text style — Dynamic Type scaling is automatic.
- All currency, totals, and numeric emphasis use **SF Pro Rounded** (`amount`, `amountCompact`). It feels more native to Apple's finance surfaces and reads better at a glance.
- Every label sets `adjustsFontForContentSizeCategory = true`.
- Never set a literal `UIFont.systemFont(ofSize:)` outside `DesignSystem.Typography`.

### 3.3 Line length

- Body copy stays under ~66 characters per line.
- Display labels (amounts) wrap to two lines maximum, then truncate.

---

## 4. Spacing

### 4.1 Scale (8-pt grid)

| Token | Value | Use for |
|-------|-------|---------|
| `xs` | 4 | Icon ↔ text within a chip, hairline padding |
| `sm` | 8 | Tight vertical stacks |
| `md` | 12 | Default vertical rhythm between related lines |
| `lg` | 16 | Card edge padding, default screen padding |
| `xl` | 24 | Section separation, generous whitespace |
| `xxl` | 32 | Top-level hero gaps |
| `xxxl` | 48 | Empty-state breathing room |

### 4.2 Layout rules

- Default screen padding: `lg` (16) on leading/trailing.
- Cards: `lg` internal padding, `lg` between cards.
- Sections: `xl` between unrelated content groups.
- No arbitrary numbers. No `padding: 14`.

---

## 5. Shape tokens

| Token | Radius | Use for |
|-------|--------|---------|
| `sm` | 6 | Chips, micro tags, text fields |
| `md` | 10 | Compact buttons |
| `lg` | 16 | Cards, sheets, modals |
| `pill` | 999 | Pill chips, CTA buttons, segmented controls |

All radii use `cornerCurve = .continuous` (iOS squircle) — never plain circular corners.

---

## 6. Elevation (shadow tokens)

| Token | Y-offset | Blur | Opacity | Use for |
|-------|----------|------|---------|---------|
| `low` | 1 | 4 | 0.04 | Default cards |
| `medium` | 2 | 10 | 0.08 | Floating buttons, modals |
| `high` | 6 | 20 | 0.12 | Critical sheets only (rare) |

Shadows are **black at low opacity** — never colored. In dark mode, shadows render but read very subtly; that's intentional.

---

## 7. Motion tokens

| Token | Duration | Curve | Use for |
|-------|----------|-------|---------|
| `durationFast` | 150ms | easeOut | Cell select, chip toggle |
| `durationStandard` | 250ms | easeOut | Card insert/delete, sheet present |
| `durationSlow` | 400ms | easeInOut | Full-screen transitions |

### 7.1 Rules

- No spring, bounce, or "spring-with-damping" effects. Linear ease, native feel.
- No animation longer than 400ms.
- No animation purely for delight. Motion **communicates state change** — entering, leaving, updating.
- Reduce Motion: when `UIAccessibility.isReduceMotionEnabled`, fade-only.

---

## 8. Haptic tokens

| Event | Trigger |
|-------|---------|
| `selection` | Tapping a list row (light haptic before navigation) |
| `lightImpact` | Tapping `+` add buttons, archive action |
| `mediumImpact` | Reserved for future swipe-confirm gestures |
| `success` | Save confirmed (form persists) |
| `warning` | Confirming a destructive action |
| `error` | Validation or save failure |

All haptics route through `HapticsService` — never instantiate `UIImpactFeedbackGenerator` in a view controller.

---

## 9. Iconography

- **Source:** SF Symbols 5 only. No raster icons in the main app.
- **Weights:** match the adjacent text style. Default `regular`; headlines pair with `semibold`.
- **Sizes:** driven by typography, not literal point sizes. Use `UIImage.SymbolConfiguration(font:)`.
- **Tint:** monochrome by default. Tinted only with semantic color tokens — never decorative.

Common symbols in use:

| Symbol | Where |
|--------|-------|
| `creditcard` | Default subscription glyph |
| `play.tv`, `music.note`, `briefcase`, `newspaper`, `icloud`, `figure.run` | Category avatars |
| `bell.badge` | Reminders, notifications |
| `chart.pie` | Insights |
| `tray`, `exclamationmark.triangle` | Empty / error states |
| `archivebox`, `trash`, `pencil` | Row context actions |

---

## 10. Components

Each component below is named, scoped, and described to be built in Figma as a single component with variants. Swift counterparts already exist or will be created under `DesignSystem/Components/`.

### 10.1 `SublyPrimaryButton`

A full-width CTA. One per screen, max.

| Property | Default | Variants |
|----------|---------|----------|
| `title` | "Get Started" | required |
| `state` | enabled | enabled · disabled · loading |
| `size` | regular | regular · compact |

- Background: `accent`
- Foreground: white (`#FFFFFF`)
- Font: `headline` (semibold)
- Radius: `lg` (16) for regular, `pill` for floating
- Padding: vertical `md`, horizontal `xl`
- Pressed: 80% scale opacity overlay
- Disabled: 0.4 opacity, no haptic

### 10.2 `SublySecondaryButton`

Inline secondary action — usually next to a primary or in toolbars.

- Background: `surfaceElevated`
- Foreground: `textPrimary`
- Same shape, padding, and states as primary.

### 10.3 `SublyDestructiveButton`

For "Delete subscription" actions inside detail views.

- Foreground: `danger`
- Background: clear (text link style)
- Triggers `warning` haptic on confirmation flow.

### 10.4 `SublyCardView`

Container for grouped content (e.g., monthly total).

- Background: `surface`
- Radius: `lg` (16)
- Shadow: `low`
- Internal padding: `lg`
- Does **not** clip to bounds (so shadow renders).

### 10.5 `SublyChip`

Tiny pill for categories, tags, status.

| Variant | Foreground | Background | Use |
|---------|------------|------------|-----|
| `neutral` | `textSecondary` | `textSecondary × 0.12` | Category name |
| `accent` | `accent` | `accent × 0.12` | "New" indicator |
| `warning` | `warning` | `warning × 0.12` | "Renews in 2 days" |
| `danger` | `danger` | `danger × 0.12` | "Past due" |

- Optional leading SF Symbol at `caption` size.
- Padding: vertical `xs`, horizontal `sm`.
- Radius: `pill`.

### 10.6 `SublyAmountLabel`

A `UILabel` subclass with three emphasis modes.

| Emphasis | Style |
|----------|-------|
| `display` | `amount` (28pt SF Rounded bold), `textPrimary` |
| `primary` | `amountCompact` (17pt SF Rounded semibold), `textPrimary` |
| `secondary` | `subhead`, `textSecondary` |

Always sets content-hugging to `.required` horizontally so it never gets compressed in a row.

### 10.7 `SublyAvatarView`

Round container with a tinted SF Symbol for category icons.

- Default size: 40×40
- Radius: 50% of size (always a circle)
- Background: `tint × 0.14`
- Symbol tint: full `tint`
- Symbol point size: 18

### 10.8 `SublyEmptyStateView`

Stack of icon + title + message, optional CTA.

- Icon: large SF Symbol at 44pt, `textTertiary`
- Title: `headline`, `textPrimary`, centered
- Message: `subhead`, `textSecondary`, centered, max 2 lines
- Optional `SublyPrimaryButton` below

Used for: empty list, empty dashboard, empty timeline, empty insights, error fallback.

### 10.9 `SectionHeaderView`

Apple-style table section header.

- Title: `footnote`, `textSecondary`, **UPPERCASE**, letter-spacing default
- Optional trailing count: `footnote`, `textTertiary`

### 10.10 `SubscriptionCell`

The canonical list row. Composed entirely of design-system tokens.

```
┌────────────────────────────────────────────────────────┐
│ [Avatar]  Primary text                       Amount    │
│           Secondary text · Renews date                 │
│           [Chip · Category]                            │
└────────────────────────────────────────────────────────┘
```

- Background: `surface`
- Vertical padding: `md`
- Avatar: `SublyAvatarView`
- Primary: `body`, `textPrimary`
- Secondary: `footnote`, `textSecondary`
- Category chip: `SublyChip.neutral`
- Amount: `SublyAmountLabel.primary`
- Accessory: `disclosureIndicator`
- Accessibility: `isAccessibilityElement = true`, `.button` trait, full label + hint
- Long-press: context menu (Edit, Archive, Delete)
- Swipe-trailing: Archive (warning tint) + Delete (destructive)

### 10.11 `UpcomingRenewalCell`

Variant of the list row tailored for the dashboard "Next 7 days" surface.

- No category chip
- Date label replaces secondary
- Smaller vertical padding (`sm`)

### 10.12 `RenewalBadge` *(reserved — Phase 3)*

A future component for inline urgency markers ("in 2 days") attached to a `SubscriptionCell`.

### 10.13 `SublyStatCard`

Used in the Insights surface to display a labelled metric.

- Subclass of `SublyCardView` (inherits surface, radius, shadow).
- Vertical stack: caption (`subhead`, secondary) → value (`SublyAmountLabel.display`) → optional footnote (`footnote`, tertiary).
- Configured via `SublyStatCard.ViewModel(caption:value:footnote:)`.
- `accessibilityLabel` is the comma-joined caption + value + footnote.
- Variants come from how it's composed (full-width vs. half-width in a `UIStackView.distribution = .fillEqually`).

### 10.14 `TimelineItem` *(reserved — Phase 2.5)*

Used in the Timeline view: date marker + subscription chip + amount. To be specified when Timeline ships.

---

## 11. Screen specifications

Each screen below names every component used, the navigation owner, and the empty-state behaviour. Use these as the source of truth when laying out Figma frames at 393×852 (iPhone 17 Pro).

### 11.1 Onboarding

| | |
|-|-|
| **Owner** | `OnboardingCoordinator` |
| **Structure** | Centered SF Symbol → headline → message → `SublyPrimaryButton` pinned to bottom safe area |
| **Padding** | `xl` (24) leading/trailing, `xl` above CTA |
| **Spacing** | Icon → text: `xl`; title → message: `md` |
| **Hero icon** | `creditcard` at 72pt, `accent` tint |
| **Title** | "Welcome to Subly" — `largeTitle` |
| **Message** | "Track every recurring payment in one calm, focused place." — `body`, `textSecondary` |
| **CTA** | "Get Started" → triggers main shell |
| **Transitions** | Crossfade into TabBar |

### 11.2 Dashboard (Home)

| | |
|-|-|
| **Owner** | `DashboardCoordinator` |
| **Navigation bar** | Large title "Dashboard"; trailing bar button `+` (light haptic) |
| **Hero card** | `SublyCardView` — "Monthly total" caption (`subhead`, secondary) → `SublyAmountLabel.display` → "X active subscriptions" (`footnote`, secondary) |
| **Upcoming section** | Section header (`subhead`, secondary): "Upcoming renewals · next 7 days" |
| **Upcoming list** | `UITableView.insetGrouped` of `UpcomingRenewalCell`, non-scrollable, sized to content |
| **Empty state** | When no subscriptions: `SublyEmptyStateView` with `tray` icon, "No subscriptions yet", "Tap + to add your first subscription." |
| **States** | `idle`, `loading`, `loaded`, `empty`, `failed` (single `ViewState<Snapshot>`) |
| **Pulls live data** | Observes `SubscriptionRepository.observe()` as an `AsyncStream` |

### 11.3 Subscription List

| | |
|-|-|
| **Owner** | `SubscriptionListCoordinator` |
| **Navigation bar** | Large title "Subscriptions" |
| **Structure** | `UITableView.insetGrouped`, diffable data source |
| **Grouping** | By category (`SectionHeaderView` with row count) |
| **Sort** | By next renewal date ascending |
| **Row** | `SubscriptionCell` |
| **Swipe-trailing** | Archive (warning) + Delete (destructive) |
| **Context menu** | Edit · Archive · Delete (long-press) |
| **Empty state** | Same `SublyEmptyStateView` pattern as dashboard, message: "Add your first subscription from the Dashboard." |
| **Future** | Search bar (`UISearchController`), filter chips — Phase 2.5 |

### 11.4 Subscription Detail

| | |
|-|-|
| **Owner** | `SubscriptionDetailCoordinator` (push from list) |
| **Navigation bar** | Inline title (subscription name); trailing "Edit" |
| **Hero card** | `SublyCardView` — `SublyAmountLabel.display` + billing cycle (`subhead`, secondary) |
| **Field rows** | `Next renewal`, `Started`, `Category`, `Currency` — title (`footnote`, secondary) + value (`body`, primary) |
| **Notes** | `body` block, shown only if present |
| **Destructive action** | "Delete subscription" — `SublyDestructiveButton`, opens action sheet with `warning` haptic on confirm |
| **History section** | Reserved for Phase 3 |

### 11.5 Add / Edit Subscription (modal)

| | |
|-|-|
| **Owner** | `AddEditSubscriptionCoordinator` |
| **Presentation** | `.formSheet` modal with its own `UINavigationController` |
| **Navigation bar** | Title "Add Subscription" / "Edit Subscription"; leading `Cancel`, trailing `Save` |
| **Form** | Single scroll view, vertical stack of `FormFieldView`s |
| **Fields** | Name · Amount · Billing cycle (segmented) · Next renewal (compact date picker) · Category (menu button) · Reminder (segmented: Off / Same day / 1d / 3d / 7d) · Notes (textview) |
| **Validation** | Save disabled until name non-empty and amount > 0 |
| **Saving state** | Save → spinner replaces save item, view interaction-disabled, no blocking overlay |
| **Errors** | Alert with `userMessage`, `error` haptic |
| **Success** | `success` haptic → dismiss |

### 11.6 Timeline

| | |
|-|-|
| **Owner** | `TimelineCoordinator` |
| **Phase 1 state** | Placeholder `SublyEmptyStateView` ("Timeline coming soon", `calendar` icon) |
| **Phase 2.5** | List of `TimelineItem` rows grouped by week |

### 11.7 Insights

| | |
|-|-|
| **Owner** | `InsightsCoordinator` |
| **Navigation bar** | Large title "Insights" |
| **Stat grid** | Top row: two `SublyStatCard`s side-by-side — Monthly (with active count) + Yearly (projected). Full-width below: Biggest upcoming charge (with name + date footnote). |
| **"Where it goes" section** | Title (`title`) + `SublyCardView` wrapping `CategoryBreakdownChartView` — horizontal bar list, one per category, sorted by share descending. Each row shows category icon + name + monthly amount on top, then a 6pt accent bar at proportional width. |
| **"Next four weeks" section** | Title (`title`) + `SublyCardView` with four `ProjectionRow`s (week-of date · count · projected total), separated by 0.5pt hairlines. |
| **Charts** | Pure UIKit (Auto Layout-driven `UIView` subviews). No `CGContext.draw`, no SwiftUI. |
| **Empty state** | `SublyEmptyStateView` — "Not enough data yet", "Add a few subscriptions to start seeing insights.", icon `chart.pie`. |
| **Calculators** | Pure value-type structs in `Domain/UseCases/`: `MonthlySpendCalculator`, `YearlyProjectionCalculator`, `CategoryBreakdownCalculator`, `RenewalProjectionCalculator`. No persistence or UIKit. |
| **Data source** | `SubscriptionRepository.observe()` → calculators → `InsightsViewModel.Snapshot` → view renders. Derived data is recomputed, never stored. |
| **Tone** | Positive values in `accent`, never both `accent` and `danger` on the same chart. |

### 11.8 Settings

| | |
|-|-|
| **Owner** | `SettingsCoordinator` |
| **Structure** | `UITableView.insetGrouped` |
| **Sections** | Preferences (Currency, Appearance) · Notifications (Permission) · About (Version) |
| **Row content** | Title (`body`) + detail (`subhead`, secondary). No accessory in v1 — read-only. |

### 11.9 Empty states (global)

| Surface | Title | Message | Icon |
|---------|-------|---------|------|
| Dashboard (no subs) | "No subscriptions yet" | "Tap + to add your first subscription." | `tray` |
| List (no subs) | "Nothing here yet" | "Add your first subscription from the Dashboard." | `tray` |
| Timeline | "Timeline coming soon" | "Upcoming renewals will appear here." | `calendar` |
| Insights (no data) | "Not enough data yet" | "Add a few subscriptions to start seeing insights." | `chart.pie` |
| Error fallback | "Something went wrong" | `<UserFacingError.userMessage>` | `exclamationmark.triangle` |

All empty states feel **friendly and motivating** — never apologetic or technical.

---

## 12. Navigation architecture

### 12.1 Shape

```
Onboarding (one-time)
    │ Get Started
    ▼
Tab Bar  ─── Dashboard
         │── Subscriptions
         │── Timeline
         │── Insights
         └── Settings
```

- **Tab bar:** five flat tabs (Apple HIG maximum). No deep submenus. Each tab owns a `UINavigationController`.
- **Modals:** Add/Edit only. No multi-modal stacks.
- **Detail:** push from list. Back gesture always works.

### 12.2 Rules

- Every transition has an owner coordinator. **No** `present` / `pushViewController` calls inside view controllers.
- Modal sheets use `.formSheet` (medium) detents only — never full-screen unless system-required.
- Default back navigation is the system back button. No custom back chevrons.

### 12.3 Haptic + animation pairings

| Transition | Haptic | Motion |
|------------|--------|--------|
| Tap row → push detail | `selection` | system push (durationStandard equivalent) |
| Tap + → present Add | `lightImpact` | system modal |
| Save → dismiss | `success` | system modal dismiss |
| Confirm Delete | `warning` | system action sheet |

---

## 13. Accessibility

### 13.1 Mandatory checklist (per screen)

- [ ] Every interactive element has an `accessibilityLabel` (action-revealing verb if button).
- [ ] Interactive elements have `.button` trait.
- [ ] List rows are single accessibility elements with a combined label.
- [ ] Hints describe non-obvious interactions ("Swipe left for actions.").
- [ ] All text uses Dynamic Type (`adjustsFontForContentSizeCategory = true`).
- [ ] Touch targets ≥ 44×44 pt.
- [ ] Color is never the sole signal (warning chips include icon + text).
- [ ] Screen passes contrast checker at body sizes in both appearances.
- [ ] VoiceOver can complete the **add → view → delete** flow without sight.
- [ ] Reduce Motion: rich transitions degrade to fade.
- [ ] Large Content Viewer supported on small icons in navigation/tab bars.

### 13.2 Localization readiness

- All strings live in `Localizable.strings` (Phase 2 housekeeping item).
- Numeric formatting uses `NumberFormatter` with `Locale.current`.
- Dates use `DateFormatter` with `.medium` / `.long` styles, never literal templates.
- RTL: layout anchors use `leading`/`trailing` (never `left`/`right`).

---

## 14. Token mapping — Figma ↔ Swift

| Figma style (suggested name) | Swift symbol |
|-----|------|
| Color / Background | `DesignSystem.Colors.background` |
| Color / Surface | `DesignSystem.Colors.surface` |
| Color / SurfaceElevated | `DesignSystem.Colors.surfaceElevated` |
| Color / Text / Primary | `DesignSystem.Colors.textPrimary` |
| Color / Text / Secondary | `DesignSystem.Colors.textSecondary` |
| Color / Text / Tertiary | `DesignSystem.Colors.textTertiary` |
| Color / Separator | `DesignSystem.Colors.separator` |
| Color / Accent | `DesignSystem.Colors.accent` |
| Color / Status / Success | `DesignSystem.Colors.success` |
| Color / Status / Warning | `DesignSystem.Colors.warning` |
| Color / Status / Danger | `DesignSystem.Colors.danger` |
| Text / Large Title | `DesignSystem.Typography.largeTitle` |
| Text / Title | `DesignSystem.Typography.title` |
| Text / Headline | `DesignSystem.Typography.headline` |
| Text / Body | `DesignSystem.Typography.body` |
| Text / Subhead | `DesignSystem.Typography.subhead` |
| Text / Footnote | `DesignSystem.Typography.footnote` |
| Text / Caption | `DesignSystem.Typography.caption` |
| Text / Amount Display | `DesignSystem.Typography.amount` |
| Text / Amount Compact | `DesignSystem.Typography.amountCompact` |
| Spacing / xs … xxxl | `DesignSystem.Spacing.xs` … `xxxl` |
| Radius / sm … pill | `DesignSystem.Radius.sm` … `pill` |
| Effect / Shadow / Low · Medium · High | `DesignSystem.Shadow.low` · `.medium` · `.high` |
| Motion / Fast · Standard · Slow | `DesignSystem.Motion.durationFast` · `.durationStandard` · `.durationSlow` |

---

## 15. Don'ts (system-wide)

| ❌ | ✅ |
|---|---|
| Blue or purple primary | Sage `accent` |
| Gradient backgrounds | Solid `background` |
| Drop shadows with color | Black low-opacity only |
| Bouncy spring animations | Linear ease 150–400ms |
| Decorative icons | SF Symbols with semantic intent |
| Literal `UIColor(red: …)` outside DesignSystem | Asset-backed token |
| Literal `UIFont.systemFont(ofSize: …)` outside DesignSystem | Typography token |
| Multiple primary CTAs per screen | One primary, others secondary/destructive |
| Numeric values in default `body` font | `SublyAmountLabel` with `amount`/`amountCompact` |
| Custom back chevrons | System back |
| Full-screen modals when a sheet would do | `.formSheet` |

---

## 16. Open questions / decisions to revisit

These need product/design alignment before Phase 3:

1. Should category colors be tunable per-category (each category has its own sage/amber/etc tint) or remain monochrome accent?
2. Should the dashboard hero card show **yearly** projection as a sub-line under monthly total?
3. Should currency conversion be reflected in dashboard totals from v1 or deferred to v2 (current: deferred per `roadmap.md`)?
4. Reminder timing presets — keep four (Off / Same day / 1d / 3d / 7d) or add custom interval picker?

Bring these to the next design review.

---

## 17. XIB / Storyboard conversion pattern

The codebase is gradually moving from programmatic UI to XIB-backed views, per `cloud.md` §4.3. This section documents the three canonical patterns, plus the active conversion backlog.

### 17.1 Convention summary

| Element type | XIB file location | Loader pattern |
|--------------|-------------------|----------------|
| **Reusable `UIView` component** | next to the Swift class (e.g., `DesignSystem/Components/SublyChip.xib`) | `Bundle.loadNibNamed` inside `init(frame:)` / `init(coder:)` |
| **`UITableViewCell`** | next to the Swift class | `tableView.register(UINib(...), forCellReuseIdentifier:)` |
| **`UIViewController`** | next to the Swift class | `super.init(nibName: String(describing: Self.self), bundle: nil)` |

XIB file names match the Swift type name exactly. Use `String(describing: Self.self)` so refactors stay safe.

### 17.2 Reusable `UIView` template — `SublyChip` ([source](Subly/DesignSystem/Components/SublyChip.xib))

- **File's Owner** = the component class (`customClass="SublyChip" customModule="Subly" customModuleProvider="target"`).
- **Root object** is a plain `UIView` — *not* the component class — that gets added as a subview of `self` and pinned to all edges.
- All outlets connect from File's Owner to subviews inside the root view.
- Swift class loads the XIB in a private `commonInit()` called from both `init(frame:)` and `init(coder:)`:

  ```swift
  private func loadContentView() {
      let bundle = Bundle(for: Self.self)
      let nib = UINib(nibName: String(describing: Self.self), bundle: bundle)
      guard let content = nib.instantiate(withOwner: self).first as? UIView else { return }
      content.translatesAutoresizingMaskIntoConstraints = false
      addSubview(content)
      NSLayoutConstraint.activate([
          content.topAnchor.constraint(equalTo: topAnchor),
          content.leadingAnchor.constraint(equalTo: leadingAnchor),
          content.trailingAnchor.constraint(equalTo: trailingAnchor),
          content.bottomAnchor.constraint(equalTo: bottomAnchor)
      ])
  }
  ```

- Visual styling that can't be expressed in IB (corner radius via tokens, dynamic font configuration) lives in an `applyStyling()` helper called once.
- `configure(with viewModel:)` keeps configuration imperative — only IBOutlet'd subviews are touched.

### 17.3 `UITableViewCell` template — `SettingsDisclosureCell` ([source](Subly/DesignSystem/Components/Settings/SettingsDisclosureCell.xib))

- **File's Owner** = `UIResponder` (no class).
- **Root object** *is* the cell — `<tableViewCell ... customClass="SettingsDisclosureCell" customModule="Subly">`.
- The reuse identifier is set inside the XIB (`reuseIdentifier="SettingsDisclosureCell"`); the Swift type still exposes a `static let reuseIdentifier` so call sites use a typed constant.
- Outlets connect from the cell root to subviews.
- Swift class:
  - No custom `init`. Cell is materialized by the runtime from the nib.
  - `awakeFromNib()` runs once after load — set traits/accessibility there.
  - `prepareForReuse()` resets visibility / state.
  - `configure(...)` mutates outlet'd subviews.
- Table view registration:

  ```swift
  tableView.register(
      UINib(nibName: String(describing: SettingsDisclosureCell.self), bundle: nil),
      forCellReuseIdentifier: SettingsDisclosureCell.reuseIdentifier
  )
  ```

- Dequeue site uses `guard let cell = … as? SettingsDisclosureCell else { return UITableViewCell() }` — no programmatic fallback (cell **must** load from the nib).

### 17.4 `UIViewController` template — `OnboardingPageViewController` ([source](Subly/Modules/Onboarding/OnboardingPageViewController.xib))

- **File's Owner** = the view controller class. The `view` outlet of File's Owner connects to the XIB's root view.
- Initializer becomes:

  ```swift
  init(page: OnboardingViewModel.Page, index: Int) {
      self.page = page
      self.pageIndex = index
      super.init(nibName: String(describing: Self.self), bundle: nil)
  }
  ```

- `viewDidLoad()`:
  - Calls `applyStyling()` to set fonts/colors/symbol configs that come from `DesignSystem` tokens (these can't live in IB without losing token cohesion).
  - Calls `apply(page)` (or equivalent) to bind data into outlets.

### 17.5 Constraints, colors, and tokens

- **Constraints** live in the XIB. Programmatic constraints are only used for the loader pattern in §17.2.
- **Asset-backed colors** (e.g., `Background`, `Surface`, `TextPrimary`) are referenced by name via `<color name="X">`. The XIB embeds an sRGB fallback inside `<resources>` so Xcode IB renders the design-system palette without needing the asset catalog open.
- **Typography** uses the closest matching Dynamic Type style (e.g., `style="UICTFontTextStyleBody"`). Weight overrides (e.g., bold large title) are applied programmatically in `applyStyling()` until we ship `IBDesignable` font configuration.

### 17.6 Converted (all VCs + all cells + all composite views)

**View controllers (14):** Onboarding, OnboardingPage, Dashboard, SubscriptionList, SubscriptionDetail, AddEditSubscription, Timeline, Insights, Settings, AppearancePicker, LanguagePicker, ReminderDefaults, Account, Paywall.

**Table cells (5):** SettingsDisclosureCell, SettingsValueCell, SettingsToggleCell, SubscriptionCell, UpcomingRenewalCell.

**Reusable views (7):**

| Asset | Pattern |
|-------|---------|
| `DesignSystem/Components/SublyChip.xib` | §17.2 — File's Owner = class, content view pinned to self |
| `DesignSystem/Components/SublyAvatarView.xib` | §17.2 — circular tinted container + centered icon |
| `DesignSystem/Components/SectionHeaderView.xib` | §17.2 variant — content loaded into `contentView` (UITableViewHeaderFooterView constraint) |
| `DesignSystem/Components/SublyEmptyStateView.xib` | §17.2 — icon + title + message centered stack |
| `DesignSystem/Components/SublyStatCard.xib` | §17.2 — composes `SublyCardView` + `SublyAmountLabel` via `customClass` |
| `Modules/AddEditSubscription/Views/FormFieldView.xib` | §17.2 — title + slot container that hosts arbitrary `contentView` |
| `Modules/Paywall/Views/PaywallPlanCard.xib` | §17.2 — `UIControl` host with composed `SublyChip` + `SublyAmountLabel` + radio image |

Total: **26 nibs** in the app bundle. Every navigable screen and every cell on every screen renders via XIB. The chip and amount label embedded in cells flow through their own XIB content load — so a subscription row touches 3 nibs (Cell + Chip + Avatar).

### 17.7 Conversion backlog (styling-only atoms + dynamic chart)

Only four reusable components remain programmatic, and each is **deliberately** kept so:

| Component | Why it stays programmatic |
|-----------|---------------------------|
| `SublyPrimaryButton` | Uses `UIButton.Configuration` API — Apple's configuration system has no IB representation. Documented in §17.8. |
| `SublyCardView` | Styling-only atom (background, corner radius, shadow). No subviews — a XIB would be an empty container with overhead. |
| `SublyAmountLabel` | Styling-only atom (font + color emphasis enum on a single `UILabel`). No subviews to lay out. |
| `CategoryBreakdownChartView` | Dynamic bar widths driven by `NSLayoutConstraint(item:multiplier:)` — not expressible in IB. Documented in §17.8. |

These three styling atoms are still consumed by other XIBs as `customClass="…"` references (e.g., `SubscriptionCell.xib` references `SublyAvatarView` and `SublyChip` and `SublyAmountLabel`; `SublyStatCard.xib` references `SublyCardView` and `SublyAmountLabel`). They render correctly inside the host XIBs because Interface Builder instantiates them via `init(coder:)`, which still applies their styling.

### 17.8 What stays programmatic, indefinitely

- Adaptive layout in `OnboardingViewController` (uses `UIPageViewController` container).
- `CategoryBreakdownChartView` bar rendering (dynamic widths driven by `NSLayoutConstraint multiplier`).
- Anything that uses `UIControl.Configuration` (Apple's API only supports configuration in code).

---

## 18. Guiding principle

> Subly's design system is a discipline, not a decoration kit. Every token, every component, every screen exists so a future engineer or designer falls naturally into the calm, native, premium pattern. Restraint is the aesthetic. Discipline is the deliverable. Maintainability is the product.

This document is the bar. Anything that fails it gets revised.
