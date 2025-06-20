# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Pareto Security Development Guide

## Build & Test Commands
- Build: `make build`
- Run tests: `make test`
- Run single test: `NSUnbufferedIO=YES xcodebuild -project "Pareto Security.xcodeproj" -scheme "Pareto Security" -test-timeouts-enabled NO -only-testing:ParetoSecurityTests/TestClassName/testMethodName -destination platform=macOS test`
- Lint: `make lint` or `mint run swiftlint .`
- Format: `make fmt` or `mint run swiftformat --swiftversion 5 . && mint run swiftlint . --fix`
- Archive builds: `make archive-debug`, `make archive-release`, `make archive-debug-setapp`, `make archive-release-setapp`
- Create DMG: `make dmg`
- Create PKG: `make pkg`

## Application Architecture

### Core Components
- **Main App (`/Pareto/`)**: SwiftUI-based status bar application
- **Helper Tool (`/ParetoSecurityHelper/`)**: XPC service for privileged operations requiring admin access
- **Security Checks (`/Pareto/Checks/`)**: Modular security check system organized by category

### Security Checks System
The app uses a modular check architecture with these categories:
- **Access Security**: Autologin, password policies, SSH keys, screensaver
- **System Integrity**: FileVault, Gatekeeper, Boot security, Time Machine
- **Firewall & Sharing**: Firewall settings, file sharing, remote access
- **macOS Updates**: System updates, automatic updates
- **Application Updates**: Third-party app update checks

Key files:
- `ParetoCheck.swift` - Base class for all security checks
- `Checks.swift` - Central registry organizing checks into claims
- `Claim.swift` - Groups related checks together

### XPC Helper Tool
The `ParetoSecurityHelper` is a privileged helper tool that:
- Handles firewall configuration checks
- Performs system-level operations requiring admin privileges
- Communicates with the main app via XPC

### Distribution Targets
- **Direct distribution**: Standard macOS app with auto-updater
- **SetApp**: Subscription service integration with separate build target
- **Team/Enterprise**: JWT-based licensing for organization management

## Code Style
- **Imports**: Group imports alphabetically, Foundation/SwiftUI first, then third-party libraries
- **Naming**: Use camelCase for variables/functions, PascalCase for types; be descriptive
- **Error Handling**: Use Swift's do/catch with specific error enums
- **Types**: Prefer explicit typing, especially for collections
- **Formatting**: Max line length 120 chars, use Swift's standard indentation (4 spaces)
- **Comments**: Only add comments for complex logic; include header comment for files
- **Code Organization**: Group related functionality with MARK comments
- **Testing**: All new features should include tests
- **Logging**: Use `os_log` for logging, with appropriate log levels

This project uses SwiftLint for style enforcement and SwiftFormat for auto-formatting.

## Key Dependencies
- **Defaults**: User preferences management
- **LaunchAtLogin**: Auto-launch functionality
- **Alamofire**: HTTP networking for update checks
- **JWTDecode**: Team licensing authentication
- **Cache**: Response caching layer

## URL Scheme Support
The app supports custom URL scheme `paretosecurity://` for:
- `reset` - Reset to default settings
- `showMenu` - Open status bar menu
- `update` - Force update check
- `welcome` - Show welcome window
- `runChecks` - Trigger security checks
- `debug` - Output detailed check status
- `logs` - Copy system logs

## Testing Strategy
- Unit tests in `ParetoSecurityTests/` cover core functionality
- UI tests in `ParetoSecurityUITests/` test user flows
- Tests are organized by feature area (checks, settings, team, updater, welcome)
- Use `make test` for full test suite with formatted output via xcbeautify

## Development Notes
- The app runs as a status bar utility (`LSUIElement: true`)
- Requires Apple Events permission for system automation
- No sandboxing to allow system security checks
- Uses privileged helper tool for admin operations
- Supports both individual and team/enterprise deployments