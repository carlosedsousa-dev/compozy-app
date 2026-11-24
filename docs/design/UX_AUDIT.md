# CompozyOS App UX Audit & Improvement Roadmap

**Target Repository:** `compozy-app` (Flutter Material 3 / Riverpod)  
**Spec Reference:** `docs/design/REFERENCE_GUIDE.md` (`lockup-dark.png`, `lockup-light.png`, `hero.jpg`, `board.jpg`, `loops.jpg`)  
**Audit Scope:** Entire codebase (`lib/`), covering Theme Foundation, Design Systems, Information Architecture, Motion, Accessibility, and Interaction Ergonomics.  
**Wave Plan:**
- **Batch 1 (This Lane):** Theme Foundation (`CompozyPalette`), Shared Primitives (`CompozyFeedback`, `CompozyEmptyState`, `CompozyErrorState`, `CompozySkeleton`), Shell & Toggle migration.
- **Batch 2:** Sessions List, Session Chat, Chat Bubbles, Tool Execution Pills, Approvals, Subagent Drawer.
- **Batch 3:** Loops Catalog, Run Loop Sheet, Settings Screen, Connection Resilience.

---

## Executive Summary & Top Prioritized Findings

| ID | Severity | Surface | Finding | Evidence (`file:line`) | Target Wave |
|---|---|---|---|---|---|
| **AUD-001** | **P0** | App-wide Themes | **Light Mode Broken App-Wide:** With `ThemeMode.light`, `Scaffold` background paints `#F4F4F5` while components throughout sessions, loops, and settings hardcode dark `CompozyColors.*`, causing white-on-white text, invisible borders, and inverted contrasts. | `sessions_list_screen.dart:28`, `session_chat_screen.dart:282`, `loops_catalog_screen.dart:33`, `settings_screen.dart:317` | Batch 1 (Foundation), Batch 2 & 3 (Screen Migrations) |
| **AUD-002** | **P0** | Error Surfaces | **Raw `error.toString()` Leaked to Users:** Raw socket, HTTP, or parser exceptions are rendered directly in the user-facing UI without human copy, triage guidance, or collapsed technical disclosures. | `sessions_list_screen.dart:229`, `session_chat_screen.dart:621`, `loops_catalog_screen.dart:329` | Batch 1 (Primitive), Batch 2 & 3 (Adoption) |
| **AUD-003** | **P1** | Loading States | **Layout Shifting Bare Spinners:** Initial screen loads and refreshes show unconstrained `CircularProgressIndicator`s causing jarring layout shifts when content loads, rather than structural breathing skeletons. | `sessions_list_screen.dart:53`, `loops_catalog_screen.dart:68`, `session_chat_screen.dart:600` | Batch 1 (`CompozySkeleton`), Batch 2 & 3 (Adoption) |
| **AUD-004** | **P1** | Touch & A11y | **Sub-48dp Touch Targets & Missing Semantics:** Interactive controls (e.g., chat prompt send button at 32×32dp, compact icon toggles) violate WCAG 2.5.5 / Android 48dp minimum touch target guidelines and lack screen-reader labels. | `session_chat_screen.dart:755`, `theme_mode_toggle.dart:57`, `tool_execution_pill.dart:94` | Batch 1 (`ThemeModeToggle`), Batch 2 (Chat) |
| **AUD-005** | **P1** | Sessions IA | **Monospace `session.id` Prioritized Over Needs:** Session cards present cryptic technical UUIDs (`session.id`) as primary line, without search, without "Needs you" attention filtering, and without pinned urgent triage. | `sessions_list_screen.dart:306`, `sessions_list_screen.dart:78` | Batch 2 (Sessions Wave) |

---

## Detailed Audit Findings

### 1. Theme Foundation & Hardcoded Dark Tokens (Severity: P0)
- **Evidence:** `grep -rn "CompozyColors\." lib/` surfaces 120+ occurrences across `sessions_list_screen.dart`, `session_chat_screen.dart`, `chat_bubble.dart`, `tool_execution_pill.dart`, `approval_card.dart`, `subagents_drawer.dart`, `loops_catalog_screen.dart`, `loop_card.dart`, `run_loop_sheet.dart`, and `settings_screen.dart`.
- **Impact:** Light mode toggle switches the application `ThemeData.light`, but 95% of screens remain hardcoded to `#0A0A0A`, `#161616`, and `#FFFFFF` text. On a light scaffold (`#F4F4F5`), components render dark cards with mismatched borders or white text on white surfaces, making content unreadable.
- **Remediation Plan:**
  - *Batch 1:* Define `CompozyPalette` as a `ThemeExtension<CompozyPalette>`, providing `context.palette` with both `dark` and `light` definitions. Migrate `AppNavigationShell`, `ThemeModeToggle`, and `ConnectionBanner`.
  - *Batch 2:* Migrate all session widgets to `context.palette`.
  - *Batch 3:* Migrate loops and settings screens to `context.palette`.

### 2. Error Presentation & Raw Exception Disclosures (Severity: P0)
- **Evidence:**
  - `sessions_list_screen.dart:229`: `Text(error.toString())` inside `_buildErrorView`.
  - `session_chat_screen.dart:621`: `Text(error.toString())` in transcript failure view.
  - `loops_catalog_screen.dart:329`: `Text(error.toString())` in loop catalog error view.
- **Impact:** Users are exposed to internal stack traces, socket timeouts (`SocketException: OS Error: Connection refused`), or raw JSON deserialization errors. This causes user anxiety and provides zero actionable recovery steps.
- **Remediation Plan:**
  - *Batch 1:* Author `CompozyErrorState` with friendly human copy (`title`, `message`), optional collapsed "Details" disclosure, and a high-contrast `Retry` action.
  - *Batch 2 & 3:* Replace all inline error views with `CompozyErrorState`.

### 3. Loading Experience & Layout Stability (Severity: P1)
- **Evidence:**
  - `sessions_list_screen.dart:53`: `CircularProgressIndicator(strokeWidth: 2, color: CompozyColors.fg)`
  - `loops_catalog_screen.dart:68`: `CircularProgressIndicator`
  - `session_chat_screen.dart:600`: Bare spinner while history loads
- **Impact:** Center spinners give no sense of incoming layout geometry. When data arrives, the UI snaps abruptly into view, causing severe Cumulative Layout Shift (CLS).
- **Remediation Plan:**
  - *Batch 1:* Author `CompozySkeleton` (with `MediaQuery.disableAnimations` support) and `CompozySkeletonList`.
  - *Batch 2:* Replace session list spinner with `CompozySkeletonList`.
  - *Batch 3:* Replace loops catalog spinner with skeleton cards matching grid/list geometry.

### 4. Empty State Guidance & Next Actions (Severity: P1)
- **Evidence:**
  - `sessions_list_screen.dart:154-198`: Displays "No sessions found" with an icon and paragraph, but no action button (e.g., "Create Session", "Quick Prompt").
  - `loops_catalog_screen.dart:252-297`: Displays "No loops found" with no action or filter reset.
- **Impact:** Leaves users at a dead end without direction on how to populate or recover from the empty state.
- **Remediation Plan:**
  - *Batch 1:* Author `CompozyEmptyState` featuring standard CompozyOS iconography, high-contrast inverted action buttons, and clear hierarchy.
  - *Batch 2 & 3:* Adopt `CompozyEmptyState` across all catalog and list views.

### 5. Touch Target Sizes & Accessibility (WCAG 2.5.5) (Severity: P1)
- **Evidence:**
  - `session_chat_screen.dart:755`: `_buildSendButton` has a hardcoded `width: 32, height: 32`. Tap area is significantly below the 48×48dp mobile touch target threshold.
  - `theme_mode_toggle.dart:57`: Compact toggle previously had `minWidth: 32, minHeight: 32` constraints.
  - `tool_execution_pill.dart:94`: Chevron toggle button lacks semantics and has cramped padding.
- **Impact:** High miss-tap rates on mobile touchscreens, especially when typing quickly or one-handed. Screen readers announce bare icon buttons without action intent.
- **Remediation Plan:**
  - *Batch 1:* Enforce 48dp minimum constraints and destination-naming tooltips in `ThemeModeToggle` and `AppNavigationShell`.
  - *Batch 2:* Expand chat send button to 48dp tap target (with visual pill sizing) and attach full `Semantics` descriptors.

### 6. Text Scaling & Responsive Layout Risks (Severity: P1)
- **Evidence:**
  - `loops_catalog_screen.dart:218`: Desktop/tablet `GridView` hardcodes `mainAxisExtent: 180`. At 1.5× or 2.0× text scale (`MediaQuery.textScaler`), card titles and description lines overflow or clip.
  - `app_shell.dart:70`: Fixed `preferredSize: const Size.fromHeight(52)` previously risked clipping app bar text under extreme font scales.
- **Impact:** Users who rely on larger accessibility font sizes experience text truncation, broken container borders, or yellow/black overflow stripes.
- **Remediation Plan:**
  - *Batch 1:* Make `AppNavigationShell` app bar responsive to `MediaQuery.textScalerOf(context)`.
  - *Batch 3:* Replace fixed `mainAxisExtent` in loops grid with adaptive sizing or flexible card constraints.

### 7. User Feedback, Haptics & Notification Polarity (Severity: P2)
- **Evidence:**
  - `settings_screen.dart:104, 172`: Uses standard `ScaffoldMessenger.showSnackBar(SnackBar(content: Text(...)))` without theme styling, semantic color coding, or haptics.
  - Absence of distinction between destructive actions (e.g., stopping a session, clearing history) and neutral confirmations.
- **Impact:** System messages look generic and detach from the dark/light design system; users miss tactile confirmation of critical operations on mobile.
- **Remediation Plan:**
  - *Batch 1:* Provide `showCompozySnack()` and `compozyHaptic()`.
  - *Batch 2 & 3:* Replace all raw `SnackBar` calls with `showCompozySnack`.

### 8. Sessions List Information Architecture & Prioritization (Severity: P1)
- **Evidence:**
  - `sessions_list_screen.dart:306`: Card header renders `session.id` (`Text(session.id, style: monospace, 11px)`) prominently, pushing human-friendly session name lower.
  - `sessions_list_screen.dart:78`: Filter chips only include `All`, `Active`, `Idle`, `Stopped`. No dedicated chip or section for `Needs you` (the primary CompozyOS triage signal pinned in `board.jpg`).
  - No search bar or quick filter by agent role (`designer`, `dispatcher`, `fixer`).
- **Impact:** When dozens of sessions exist, finding a session blocked on user approval requires scanning down the entire list rather than surfacing the urgent items at the top.
- **Remediation Plan:**
  - *Batch 2:* Prioritize "Needs you" attention items at top of list; demote raw UUID to metadata footer; add search / agent filter.

### 9. Session Chat Ergonomics & Interaction States (Severity: P1)
- **Evidence:**
  - `session_chat_screen.dart`: When the user scrolls up through conversation history, there is no "Scroll to Latest" floating action button.
  - No prompt draft persistence: navigating away from a session discards partially typed input.
  - Chat bubbles lack a quick-copy action or message context menu.
  - Active turn streaming indicator is merely a pulsing dot, lacking clear phase indicators (e.g., Thinking vs Tool Call vs Responding).
- **Impact:** Friction in long sessions; lost drafts cause frustration; users cannot easily copy code blocks or agent answers.
- **Remediation Plan:**
  - *Batch 2:* Implement scroll-to-latest FAB with unread badge, per-session draft persistence, code-block copy buttons, and enhanced streaming progress indicators.

### 10. Form Validation & Mutation Safety in Loops & Settings (Severity: P2)
- **Evidence:**
  - `run_loop_sheet.dart`: Parameter form validation occurs only upon pressing "Run Loop". No live or on-blur validation feedback.
  - `settings_screen.dart`: Changing Base URL or clearing workspace lacks a confirmation dialog or diff summary before applying changes.
- **Impact:** Users inadvertently trigger failed loop runs due to malformed JSON or invalid parameter syntax; accidental changes to daemon host disrupt connectivity.
- **Remediation Plan:**
  - *Batch 3:* Add live form validation to `run_loop_sheet.dart` and confirmation dialogs for destructive settings adjustments.

---

## Roadmap Allocation

### Wave Batch 1: Theme Foundation & Shared UX Primitives (Done)
- [x] Defined `CompozyPalette` ThemeExtension with complete Dark and Light token contracts.
- [x] Added `context.palette` extension.
- [x] Registered palettes in `darkTheme` and `lightTheme` inside `CompozyTheme`.
- [x] Migrated `AppNavigationShell` to full theme-aware palette, eliminating hardcoded colors.
- [x] Migrated `ThemeModeToggle` with destination-naming tooltips and 48dp touch targets.
- [x] Migrated `ConnectionBanner` to palette tokens with actionable retry state and 48dp buttons.
- [x] Implemented `showCompozySnack()` with severity styling and `compozyHaptic()`.
- [x] Implemented `CompozyEmptyState` with semantic labels and action affordances.
- [x] Implemented `CompozyErrorState` with collapsed technical details disclosure.
- [x] Implemented `CompozySkeleton` (animation-safe) and `CompozySkeletonList`.
- [x] Authored full test coverage in `test/core/`.

### Wave Batch 2: Sessions & Chat Experience (Done)
- [x] Migrate `sessions_list_screen.dart` and `session_chat_screen.dart` to `context.palette`.
- [x] Replace bare spinners with `CompozySkeletonList`.
- [x] Adopt `CompozyErrorState` and `CompozyEmptyState`.
- [x] Restructure session cards to prioritize "Needs you" attention badges over UUIDs.
- [x] Enlarge prompt send button to 48dp minimum touch target.
- [x] Add scroll-to-latest button and message copy affordances.

### Wave Batch 3: Loops, Settings & Form Ergonomics (Done)
- [x] Migrate `loops_catalog_screen.dart`, `loop_card.dart`, `run_loop_sheet.dart`, and `settings_screen.dart` to `context.palette`.
- [x] Replace raw `error.toString()` with `CompozyErrorState`.
- [x] Remove fixed `mainAxisExtent` on loop grid to eliminate text-scaling clipping.
- [x] Add live validation and run confirmation to loop parameters.
- [x] Wire `showCompozySnack` across settings and loop execution.

---

## Wave 2 — Information Architecture

- **Primary Destinations (4 tabs):** `Sessions` (`Icons.chat_bubble_outline` / `Icons.chat_bubble`), `Agents` (`Icons.hub_outlined` / `Icons.hub`), `Loops` (`Icons.all_inclusive`), and `Automations` (`Icons.schedule_outlined` / `Icons.schedule`).
- **Settings Relocation:** Settings moved out of `BottomNavigationBar` and `NavigationRail` into a dedicated workspace menu sheet (`workspace_menu_sheet.dart`) opened via the tappable header title row (`app_workspace_menu_button`, ≥48dp touch target). This keeps high-frequency agent interaction surfaces at hand while grouping workspace identity, connection health, theme switcher, and daemon settings into a single cohesive management drawer.
- **Discovered Daemon Surfaces (Not Yet Built):**
  - `/api/marketplace`: Agent extension catalog and capability discovery.
  - `/api/tasks`: Cross-session task leases and orchestration boards.
  - `/api/automation/suggestions`: Context-aware trigger suggestions and scheduled run recommendations.
