# Pareto Security Development Guide

## Build & Test Commands
- Build: `make build`
- Run tests: `make test`
- Run single test: `NSUnbufferedIO=YES xcodebuild -project "Pareto Security.xcodeproj" -scheme "Pareto Security" -test-timeouts-enabled NO -only-testing:ParetoSecurityTests/TestClassName/testMethodName -destination platform=macOS test`
- Lint: `make lint` or `mint run swiftlint .`
- Format: `make fmt` or `mint run swiftformat --swiftversion 5 . && mint run swiftlint . --fix`

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