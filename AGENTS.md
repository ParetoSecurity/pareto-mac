# Repository Guidelines

## Project Structure & Module Organization
- `Pareto/`: Main app source (Swift/SwiftUI), checks, views, status bar, models.
- `Pareto Security.xcodeproj/`: Xcode project and build settings.
- `ParetoSecurityTests/` and `ParetoSecurityUITests/`: Unit and UI tests (XCTest).
- `assets/`: App icons and screenshots. `SourcePackages/`: SwiftPM cache.
- `.github/workflows/`: CI for lint, test, and release.

## Build, Test, and Development Commands
- Install tooling once: `brew install mint && mint bootstrap` (installs SwiftFormat, SwiftLint, xcbeautify).
- Build: `make build` (Debug build via xcodebuild + xcbeautify).
- Test: `make test` (runs XCTest, produces `junit.xml`).
- Lint: `make lint`; Format: `make fmt` (SwiftFormat + SwiftLint --fix).
- Archive (local): `make archive-debug`; DMG (release tooling): `make dmg`.

## Coding Style & Naming Conventions
- Formatting is enforced by SwiftFormat; run `make fmt` before committing.
- Linting uses SwiftLint with project overrides in `.swiftlint.yml` (several complexity/length rules disabled to reduce noise).
- Naming: Types in PascalCase; properties/methods in camelCase; files match the primary type (e.g., `UpdateService.swift`).
- Tests follow `*Test.swift` or `*Tests.swift` and `test...` method names.

## Testing Guidelines
- Framework: XCTest. Place unit tests in `ParetoSecurityTests/`, UI tests in `ParetoSecurityUITests/`.
- Run locally with `make test`; CI reports coverage to Codecov (`codecov.yml`). Aim to keep coverage stable or improving.
- Prefer fast, deterministic tests; mock external services where possible.

## Commit & Pull Request Guidelines
- Use Conventional Commits style: `feat:`, `fix:`, `chore:`, etc. Keep subjects imperative and concise.
- PRs: include a clear description, linked issues (`Fixes #123`), and screenshots for UI changes.
- Ensure `make fmt`, `make lint`, and `make test` pass locally; CI must be green.

## Security & Release Notes
- Release, notarization, and symbol upload require Apple signing certificates and secrets configured in GitHub Actions. Do not commit or share credentials.
- Local contributors can skip release targets; focus on build, format, lint, and tests.

