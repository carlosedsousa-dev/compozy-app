# Security Policy

> **Beta Notice:** `compozy-app` is early beta software. Interfaces, storage formats, and daemon protocol expectations may change before a stable release.

## Supported Versions

Only the latest state of the `main` branch is currently supported with security updates.

| Version | Supported |
| --- | --- |
| `main` (beta) | Yes |
| Older commits | No |

## Reporting a Vulnerability

Please **do not open a public GitHub issue** for suspected security vulnerabilities.

Instead, report vulnerabilities privately through GitHub Private Vulnerability Reporting (the repository's **Security > Advisories** tab) or by contacting the repository maintainers directly.

Include as much of the following as possible:

- A clear description of the vulnerability and its potential impact.
- Steps to reproduce the issue or a minimal proof of concept.
- Affected platform(s) (Android, desktop, web), app version (`pubspec.yaml`), and CompozyOS daemon version.
- Any suggested remediation, if known.

## Scope & Architecture Notes

- **Local daemon communication:** `compozy-app` communicates directly over HTTP/SSE with a CompozyOS daemon URL configured and controlled by the user (defaulting to `http://localhost:2123`, or `http://10.0.2.2:2123` on Android).
- **Local credential storage:** When an optional daemon app token is provided, it is stored locally on-device using `shared_preferences`. Avoid sharing device backups or screenshots containing real tokens or private workspace data.
- **No telemetry:** This client does not collect or transmit analytics, crash telemetry, or usage data to third-party services.
