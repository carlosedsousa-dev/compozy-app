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
- **Build metadata (`+N`):** The `+N` build number in `pubspec.yaml` applies only to local builds; CI release builds override the Android `versionCode` with the GitHub Actions run number.

### Releasing

1. Bump the version in `pubspec.yaml` and `kAppVersion` in [`lib/core/app_info.dart`](lib/core/app_info.dart), and move [`CHANGELOG.md`](CHANGELOG.md) entries from `## [Unreleased]` to `## [X.Y.Z]` (or `## [X.Y.Z-suffix]` for a pre-release) in a single PR. [`CHANGELOG.md`](CHANGELOG.md) must contain that exact heading before tagging — the release workflow fails without it.
2. After the PR merges to `main`, create an annotated tag (`git tag -a vX.Y.Z -m "Release vX.Y.Z"` or `vX.Y.Z-<suffix>`) on a commit reachable from `main` and push it (`git push origin vX.Y.Z`). Lightweight tags and tags pointing outside `main` are refused by the workflow.
3. [`.github/workflows/release.yml`](.github/workflows/release.yml) validates the tag and commit, runs `flutter analyze` and `flutter test`, builds the artifacts (setting the Android `versionCode` to the CI run number rather than `+N` from `pubspec.yaml`, which is only for local builds), and publishes the GitHub Release. A `vX.Y.Z-<suffix>` tag publishes a GitHub pre-release; a plain `vX.Y.Z` tag publishes a normal release.
4. **Signing & patch-forward rollback:** Release APKs are signed with the project release keystore supplied through four repository secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`), and the build verifies the signature and fails rather than publishing an improperly signed APK. Losing the release keystore means installed users must uninstall the app before any future update, so the keystore must be backed up outside the repository. Release tags are immutable and must never be moved or deleted once pushed; rollback is patch-forward only (fix the issue and publish the next patch version).

## Guidelines

- **Keep changes scoped:** Focus each pull request on a single bug fix, feature, or documentation improvement. Avoid unrelated refactoring.
- **Follow architecture conventions:** Core infrastructure lives in `lib/core/` and feature modules follow `lib/features/<feature>/{domain,data,presentation}` with Riverpod. Visual tokens and screen specs live in `docs/design/REFERENCE_GUIDE.md`.
- **Use conventional commits:** Prefix commit messages with types such as `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, or `chore:`.
- **Protect secrets and local data:** Never commit API/app tokens, `.env` files, personal workspace IDs, local logs, or real session transcripts.
- **Demo data only in screenshots:** Any screenshots added or updated in PRs or docs must use sanitized, synthetic demo data—never real workspaces, tokens, or private prompts.
