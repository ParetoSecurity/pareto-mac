//
//  ParetoSecurityTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 11/08/2021.
//

import Defaults
@testable import Pareto_Security
import XCTest

class ParetoSecurityTests: XCTestCase {
    func testThatUUIDsAreUnique() throws {
        var uuids: [String] = []
        for claim in Claims.global.all {
            for check in claim.checksSorted {
                if uuids.contains(check.UUID) {
                    XCTFail("Duplicate UUID found \(check.UUID)")
                }
                uuids.append(check.UUID)
            }
        }
    }

    func testAppInfo() throws {
        XCTAssertTrue(AppInfo.bugReportURL().absoluteString.contains("paretosecurity.com"))
    }

    func testPackageManagerSupplyChainPassesWithoutConfigs() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertTrue(check.checkPasses())
    }

    func testPackageManagerSupplyChainDoesNotRunWithoutConfigsOrBinaries() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])
        check.configure()

        XCTAssertFalse(check.isRunnable)
    }

    func testPackageManagerSupplyChainRunsWithDetectedBinary() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["npm"])
        check.configure()

        XCTAssertTrue(check.isRunnable)
        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.npmrc is missing")
    }

    func testPackageManagerSupplyChainRunsWithDetectedPnpmBinary() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["pnpm"])
        check.configure()

        XCTAssertTrue(check.isRunnable)
        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- pnpm config is missing (checked ~/Library/Preferences/pnpm/rc, ~/Library/Preferences/pnpm/config.yaml, ~/.config/pnpm/rc, ~/.config/pnpm/config.yaml)")
    }

    func testPackageManagerSupplyChainPassesWithProtectedConfigs() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pnpmDirectory = temporaryDirectory.appendingPathComponent("Library/Preferences/pnpm")
        let uvDirectory = temporaryDirectory.appendingPathComponent(".config/uv")
        try FileManager.default.createDirectory(at: pnpmDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: uvDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        # npm accepts standard ini comments
        min-release-age=7 # trailing comment
        save-exact=true ; trailing comment
        """.write(to: temporaryDirectory.appendingPathComponent(".npmrc"), atomically: true, encoding: .utf8)
        try """
        minimumReleaseAge: 10080
        """.write(to: pnpmDirectory.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try """
        [install]
        minimumReleaseAge = 604800
        """.write(to: temporaryDirectory.appendingPathComponent(".bunfig.toml"), atomically: true, encoding: .utf8)
        try """
        [pip]
        exclude-newer = "7 days"
        """.write(to: uvDirectory.appendingPathComponent("uv.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, """
        - ~/.npmrc delays npm-compatible package releases and pins exact versions
        - ~/Library/Preferences/pnpm/config.yaml delays pnpm package releases
        - ~/.bunfig.toml delays Bun package releases
        - ~/.config/uv/uv.toml excludes Python packages newer than 7 days
        """)
    }

    func testPackageManagerSupplyChainFailsWithUnprotectedConfigs() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pnpmDirectory = temporaryDirectory.appendingPathComponent("Library/Preferences/pnpm")
        let uvDirectory = temporaryDirectory.appendingPathComponent(".config/uv")
        try FileManager.default.createDirectory(at: pnpmDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: uvDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        min-release-age=6
        minimum-release-age=10079
        save-exact=false
        """.write(to: temporaryDirectory.appendingPathComponent(".npmrc"), atomically: true, encoding: .utf8)
        try """
        minimumReleaseAge: 10079
        """.write(to: pnpmDirectory.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try """
        [install]
        minimumReleaseAge = 604799
        """.write(to: temporaryDirectory.appendingPathComponent(".bunfig.toml"), atomically: true, encoding: .utf8)
        try """
        [pip]
        exclude-newer = "6d"
        """.write(to: uvDirectory.appendingPathComponent("uv.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        let failures = check.validationFailures()

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(failures.count, 5)
        XCTAssertTrue(failures.contains("~/Library/Preferences/pnpm/config.yaml minimumReleaseAge is below 10080 minutes"))
    }

    func testPackageManagerSupplyChainPassesWithMinimumReleaseAgeOnly() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        minimum-release-age=10080
        save-exact=true
        """.write(to: temporaryDirectory.appendingPathComponent(".npmrc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.npmrc delays npm-compatible package releases and pins exact versions")
    }

    func testPackageManagerSupplyChainPassesWithMinimumReleaseAgeOnlyAndOldNpm() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        minimum-release-age=10080
        save-exact=true
        """.write(to: temporaryDirectory.appendingPathComponent(".npmrc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["npm"],
            packageManagerVersions: ["npm": "11.13.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.npmrc delays npm-compatible package releases and pins exact versions")
    }

    func testPackageManagerSupplyChainFailsWithUnsupportedNpmVersion() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        min-release-age=7
        save-exact=true
        """.write(to: temporaryDirectory.appendingPathComponent(".npmrc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["npm"],
            packageManagerVersions: ["npm": "11.13.0"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- npm is older than 11.14.0 and does not enforce ~/.npmrc min-release-age")
    }

    func testPackageManagerSupplyChainFailsWithPrereleaseNpmVersion() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        min-release-age=7
        save-exact=true
        """.write(to: temporaryDirectory.appendingPathComponent(".npmrc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["npm"],
            packageManagerVersions: ["npm": "11.14.0-rc.1"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- npm is older than 11.14.0 and does not enforce ~/.npmrc min-release-age")
    }

    func testPackageManagerSupplyChainPassesWithSupportedNpmVersion() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        min-release-age=7
        save-exact=true
        """.write(to: temporaryDirectory.appendingPathComponent(".npmrc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["npm"],
            packageManagerVersions: ["npm": "11.14.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.npmrc delays npm-compatible package releases and pins exact versions")
    }

    func testPackageManagerSupplyChainFailsWithUnknownNpmVersion() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        min-release-age=7
        save-exact=true
        """.write(to: temporaryDirectory.appendingPathComponent(".npmrc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["npm"],
            packageManagerVersions: ["npm": ""]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- npm version could not be determined, so ~/.npmrc min-release-age could not be verified")
    }

    func testPackageManagerSupplyChainComparesNpmVersions() {
        XCTAssertFalse(PackageManagerSupplyChainCheck.isVersion(nil, atLeast: "11.14.0"))
        XCTAssertFalse(PackageManagerSupplyChainCheck.isVersion("", atLeast: "11.14.0"))
        XCTAssertFalse(PackageManagerSupplyChainCheck.isVersion("11.13.0", atLeast: "11.14.0"))
        XCTAssertFalse(PackageManagerSupplyChainCheck.isVersion("11.14.0-rc.1", atLeast: "11.14.0"))
        XCTAssertTrue(PackageManagerSupplyChainCheck.isVersion("11.14.0", atLeast: "11.14.0"))
        XCTAssertTrue(PackageManagerSupplyChainCheck.isVersion("v11.14.0", atLeast: "11.14.0"))
        XCTAssertTrue(PackageManagerSupplyChainCheck.isVersion("12", atLeast: "11.14.0"))
    }

    func testPackageManagerSupplyChainValidatesWhichOutput() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let executable = temporaryDirectory.appendingPathComponent("npm")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        try "".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        XCTAssertEqual(PackageManagerSupplyChainCheck.executablePath(fromWhichOutput: executable.path), executable.path)
        XCTAssertNil(PackageManagerSupplyChainCheck.executablePath(fromWhichOutput: "npm not found"))
        XCTAssertNil(PackageManagerSupplyChainCheck.executablePath(fromWhichOutput: "npm"))
        XCTAssertNil(PackageManagerSupplyChainCheck.executablePath(fromWhichOutput: temporaryDirectory.appendingPathComponent("missing").path))
    }

    func testPackageManagerSupplyChainUsesPnpmXDGConfigHome() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let xdgDirectory = temporaryDirectory.appendingPathComponent("xdg")
        let pnpmDirectory = xdgDirectory.appendingPathComponent("pnpm")
        try FileManager.default.createDirectory(at: pnpmDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        minimumReleaseAge: 10080
        """.write(to: pnpmDirectory.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["pnpm"],
            environment: ["XDG_CONFIG_HOME": xdgDirectory.path]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- $XDG_CONFIG_HOME/pnpm/config.yaml delays pnpm package releases")
    }

    func testPackageManagerSupplyChainUsesDarwinPnpmConfigHomeYamlFallback() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pnpmDirectory = temporaryDirectory.appendingPathComponent(".config/pnpm")
        try FileManager.default.createDirectory(at: pnpmDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        minimumReleaseAge: 10080
        """.write(to: pnpmDirectory.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["pnpm"])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/pnpm/config.yaml delays pnpm package releases")
    }

    func testPackageManagerSupplyChainUsesPnpmXDGConfigHomeRc() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let xdgDirectory = temporaryDirectory.appendingPathComponent("xdg")
        let pnpmDirectory = xdgDirectory.appendingPathComponent("pnpm")
        try FileManager.default.createDirectory(at: pnpmDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        ; pnpm 10 writes rc-style config
        minimum-release-age=10080 # trailing comment
        """.write(to: pnpmDirectory.appendingPathComponent("rc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["pnpm"],
            environment: ["XDG_CONFIG_HOME": xdgDirectory.path]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- $XDG_CONFIG_HOME/pnpm/rc delays pnpm package releases")
    }

    func testPackageManagerSupplyChainUsesActivePnpmConfig() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let xdgDirectory = temporaryDirectory.appendingPathComponent("xdg")
        let pnpmDirectory = xdgDirectory.appendingPathComponent("pnpm")
        try FileManager.default.createDirectory(at: pnpmDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        minimumReleaseAge: 10079
        """.write(to: pnpmDirectory.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try """
        minimum-release-age=10080
        """.write(to: pnpmDirectory.appendingPathComponent("rc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["pnpm"],
            environment: ["XDG_CONFIG_HOME": xdgDirectory.path]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- $XDG_CONFIG_HOME/pnpm/rc delays pnpm package releases")
    }

    func testPackageManagerSupplyChainUsesDarwinPnpmConfigHomeRc() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pnpmDirectory = temporaryDirectory.appendingPathComponent(".config/pnpm")
        try FileManager.default.createDirectory(at: pnpmDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        minimum-release-age=10080
        """.write(to: pnpmDirectory.appendingPathComponent("rc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["pnpm"])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/pnpm/rc delays pnpm package releases")
    }

    func testPackageManagerSupplyChainAcceptsTopLevelUvExcludeNewer() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let uvDirectory = temporaryDirectory.appendingPathComponent(".config/uv")
        try FileManager.default.createDirectory(at: uvDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        exclude-newer = "7 days"
        """.write(to: uvDirectory.appendingPathComponent("uv.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["uv"])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/uv/uv.toml excludes Python packages newer than 7 days")
    }

    func testPackageManagerSupplyChainIgnoresRelativePnpmXDGConfigHome() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaultPnpmDirectory = temporaryDirectory.appendingPathComponent("Library/Preferences/pnpm")
        try FileManager.default.createDirectory(at: defaultPnpmDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        minimumReleaseAge: 10080
        """.write(to: defaultPnpmDirectory.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["pnpm"],
            environment: ["XDG_CONFIG_HOME": "relative/path"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Preferences/pnpm/config.yaml delays pnpm package releases")
    }

    func testPackageManagerSupplyChainFailsWithPypircCredentials() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [distutils]
        index-servers =
            pypi

        [pypi]
        username = __token__
        password = pypi-secret
        """.write(to: temporaryDirectory.appendingPathComponent(".pypirc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.pypirc contains plaintext credentials")
    }

    @MainActor
    func testSnooze() throws {
        let handlers = AppHandlers()

        // Reset snooze before testing
        Defaults[.snoozeTime] = 0

        // Tolerance in milliseconds (2 seconds to account for test execution time)
        let tolerance = 2000

        // Expected durations in milliseconds
        let oneHourMs = 3600 * 1000
        let oneDayMs = 3600 * 24 * 1000
        let oneWeekMs = 3600 * 24 * 7 * 1000

        // Test snoozeOneHour
        var beforeTime = Date().currentTimeMs()
        handlers.snoozeOneHour()
        var expectedMin = beforeTime + oneHourMs - tolerance
        var expectedMax = beforeTime + oneHourMs + tolerance
        XCTAssertGreaterThanOrEqual(Defaults[.snoozeTime], expectedMin,
            "snoozeOneHour should set time to approximately 1 hour in the future")
        XCTAssertLessThanOrEqual(Defaults[.snoozeTime], expectedMax,
            "snoozeOneHour should set time to approximately 1 hour in the future")

        // Test snoozeOneDay
        beforeTime = Date().currentTimeMs()
        handlers.snoozeOneDay()
        expectedMin = beforeTime + oneDayMs - tolerance
        expectedMax = beforeTime + oneDayMs + tolerance
        XCTAssertGreaterThanOrEqual(Defaults[.snoozeTime], expectedMin,
            "snoozeOneDay should set time to approximately 24 hours in the future")
        XCTAssertLessThanOrEqual(Defaults[.snoozeTime], expectedMax,
            "snoozeOneDay should set time to approximately 24 hours in the future")

        // Test snoozeOneWeek
        beforeTime = Date().currentTimeMs()
        handlers.snoozeOneWeek()
        expectedMin = beforeTime + oneWeekMs - tolerance
        expectedMax = beforeTime + oneWeekMs + tolerance
        XCTAssertGreaterThanOrEqual(Defaults[.snoozeTime], expectedMin,
            "snoozeOneWeek should set time to approximately 7 days in the future")
        XCTAssertLessThanOrEqual(Defaults[.snoozeTime], expectedMax,
            "snoozeOneWeek should set time to approximately 7 days in the future")

        // Test unsnooze
        handlers.unsnooze()
        XCTAssertEqual(Defaults[.snoozeTime], 0, "unsnooze should reset snooze time to 0")
    }
}
