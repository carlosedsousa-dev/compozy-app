# Contributing to compozy-app

Thank you for contributing to `compozy-app`, the Flutter client for a local CompozyOS daemon. This project is currently in **beta**, so expect active iteration across screens and daemon integration.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, compatible with Dart SDK `^3.14.0` per `pubspec.yaml`)
- A local CompozyOS daemon reachable on port `2123` (optional for running mocked widget/unit tests, required for live testing)

## Setup

```bash
flutter pub get
```

## Required Verification Gate

Before opening a pull request, both checks must pass with zero issues:

```bash
flutter analyze
flutter test
```

## Versioning

- **Bump in the same PR:** Update the version in both `pubspec.yaml` and `lib/core/app_info.dart` in the same PR as the change, following the pre-1.0 SemVer rules in [`README.md#versioning`](README.md#versioning).
- **Update the changelog:** Add an entry under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md) for every user-visible change.
- **Docs/CI-only exception:** Documentation-only or CI-only PRs may skip the version bump, but must explicitly state why in the PR description.
- **Do not edit build metadata:** Never hand-edit the `+N` build number in `pubspec.yaml`; it is reserved for CI and store builds.

## Guidelines

- **Keep changes scoped:** Focus each pull request on a single bug fix, feature, or documentation improvement. Avoid unrelated refactoring.
- **Follow architecture conventions:** Core infrastructure lives in `lib/core/` and feature modules follow `lib/features/<feature>/{domain,data,presentation}` with Riverpod. Visual tokens and screen specs live in `docs/design/REFERENCE_GUIDE.md`.
- **Use conventional commits:** Prefix commit messages with types such as `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, or `chore:`.
- **Protect secrets and local data:** Never commit API/app tokens, `.env` files, personal workspace IDs, local logs, or real session transcripts.
- **Demo data only in screenshots:** Any screenshots added or updated in PRs or docs must use sanitized, synthetic demo data—never real workspaces, tokens, or private prompts.
