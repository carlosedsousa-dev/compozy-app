# Changelog

All notable changes to this project will be documented in this file following [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

<!-- Add unreleased changes here under Added, Changed, Deprecated, Removed, Fixed, or Security. -->

## [0.1.0] - 2026-11-26

### Added

- Theme-aware CompozyOS design system (`CompozyPalette`, `CompozyTheme`) with dark, light, and system modes.
- First-run daemon connection gate (`ConnectionGate`, `DaemonSetupScreen`) with URL validation, live `/api/openapi.json` health check, and offline session bypass.
- Session board and triage with search/filtering, workspace switcher (`WorkspaceMenuSheet`), and live streaming chat over SSE with tool-call badges, subagent hierarchy drawer, and decision/permission approval cards.
- Agent presence hub combining registered agent definitions with cross-workspace session status (`Needs you`, `Working`, `Idle`) and recent activity.
- Loops catalog and run launcher sheet, plus Automations tab for scheduled jobs, triggers, run history, and scheduler status.
- Persistent daemon settings screen (`SettingsScreen`) with Base URL, optional Bearer token, active workspace ID, live connection test, and an About version footer (`lib/core/app_info.dart`).
- Official Compozy app icon, splash screen, and branded header mark.
- Public beta repository packaging (`LICENSE`, `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, CI workflow, issue forms, PR checklist, and synthetic demo screenshots).

### Changed

- Standardized all user-facing copy and connect-screen flows to English for the public beta release.

### Fixed

- Normalized Android emulator loopback hosts (`localhost`, `127.0.0.1`, `[::1]` to `10.0.2.2`) while preserving port and path.
- Resolved mobile bottom navigation bar overflow and aligned light-mode status bar overlay and agent avatar contrast.

### Security

- Added `SECURITY.md` documenting private vulnerability reporting, beta support scope, local-only token storage, and demo-only screenshot rules.
