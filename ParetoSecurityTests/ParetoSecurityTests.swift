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
    func testThatUUIDsAreUnique() {
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

    func testAppInfo() {
        XCTAssertTrue(AppInfo.bugReportURL().absoluteString.contains("paretosecurity.com"))
    }

    func testPackageManagerSupplyChainPassesWithoutConfigs() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertTrue(check.checkPasses())
    }

    func testNoUnusedUsersSkipsAccountsMissingFromLocalNode() {
        let users = NoUnusedUsers.provisionedUsers(
            ["local", "cachedDomainUser"],
            provisioned: ["local", "mobileAccount"]
        )

        XCTAssertEqual(users, ["local"])
    }

    func testNoUnusedUsersKeepsAllAccountsWhenLocalNodeLookupFails() {
        let users = NoUnusedUsers.provisionedUsers(["local", "other"], provisioned: [])

        XCTAssertEqual(users, ["local", "other"])
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
        - ~/.npmrc delays npm-compatible package releases
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
        XCTAssertEqual(failures.count, 4)
        XCTAssertTrue(failures.contains("~/Library/Preferences/pnpm/config.yaml minimumReleaseAge is below 10080 minutes"))
    }

    func testPackageManagerSupplyChainPassesWithExplicitSaveExactFalse() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        min-release-age=7
        save-exact=false
        """.write(to: temporaryDirectory.appendingPathComponent(".npmrc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.npmrc delays npm-compatible package releases")
    }

    func testPackageManagerSupplyChainFailsWithoutSaveExact() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        min-release-age=7
        """.write(to: temporaryDirectory.appendingPathComponent(".npmrc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.npmrc save-exact is not set; set it to true or false")
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
        XCTAssertEqual(check.details, "- ~/.npmrc delays npm-compatible package releases")
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
        XCTAssertEqual(check.details, "- ~/.npmrc delays npm-compatible package releases")
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
            packageManagerVersions: ["npm": "11.9.0"]
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
            packageManagerVersions: ["npm": "11.10.0-rc.1"]
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
        XCTAssertEqual(check.details, "- ~/.npmrc delays npm-compatible package releases")
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
        XCTAssertFalse(PackageManagerSupplyChainCheck.isVersion("11.10.0", atLeast: "11.14.0"))
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

    func testPackageManagerSupplyChainSearchesKnownInstallPrefixes() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        // Only the well-known hardcoded prefixes are searched; the inherited
        // PATH must not influence the list.
        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: [],
            environment: ["PATH": "/some/injected/path"]
        )
        let directories = check.searchDirectories()

        XCTAssertTrue(directories.contains("/usr/bin"))
        XCTAssertTrue(directories.contains("/opt/homebrew/bin"))
        XCTAssertTrue(directories.contains("/usr/local/bin"))
        XCTAssertTrue(directories.contains(temporaryDirectory.appendingPathComponent(".bun/bin").path))
        XCTAssertTrue(directories.contains(temporaryDirectory.appendingPathComponent("Library/pnpm").path))
        XCTAssertFalse(directories.contains("/some/injected/path"))
        XCTAssertEqual(directories.count, Set(directories).count)
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

    func testPackageManagerSupplyChainRequiresYarnrcForYarn() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["yarn"])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.yarnrc.yml is missing")
    }

    func testPackageManagerSupplyChainPassesWithYarnAgeGate() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        npmMinimalAgeGate: "7d"
        """.write(to: temporaryDirectory.appendingPathComponent(".yarnrc.yml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["yarn"],
            packageManagerVersions: ["yarn": "4.11.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.yarnrc.yml delays Yarn package releases")
    }

    func testPackageManagerSupplyChainPassesWithYarnAgeGateInMinutes() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        npmMinimalAgeGate: 10080
        """.write(to: temporaryDirectory.appendingPathComponent(".yarnrc.yml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["yarn"],
            packageManagerVersions: ["yarn": "4.11.0"]
        )

        XCTAssertTrue(check.checkPasses())
    }

    func testPackageManagerSupplyChainFailsWithLowYarnAgeGate() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        npmMinimalAgeGate: "6d"
        """.write(to: temporaryDirectory.appendingPathComponent(".yarnrc.yml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.yarnrc.yml npmMinimalAgeGate is below 7 days; set it to at least 7d or 10080")
    }

    func testPackageManagerSupplyChainFailsWithLegacyYarn() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        npmMinimalAgeGate: "7d"
        """.write(to: temporaryDirectory.appendingPathComponent(".yarnrc.yml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["yarn"],
            packageManagerVersions: ["yarn": "1.22.22"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- yarn is older than 4.11.0 and does not enforce ~/.yarnrc.yml npmMinimalAgeGate")
    }

    func testPackageManagerSupplyChainRequiresPipConfForPip() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["pip"])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/pip/pip.conf is missing")
    }

    func testPackageManagerSupplyChainPassesWithPipCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipDirectory = temporaryDirectory.appendingPathComponent(".config/pip")
        try FileManager.default.createDirectory(at: pipDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [install]
        uploaded-prior-to = P7D
        """.write(to: pipDirectory.appendingPathComponent("pip.conf"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["pip"],
            packageManagerVersions: ["pip": "pip 26.1.0 from /usr/lib/pip (python 3.13)"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/pip/pip.conf delays pip package releases")
    }

    func testPackageManagerSupplyChainFailsWithLowPipCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipDirectory = temporaryDirectory.appendingPathComponent(".config/pip")
        try FileManager.default.createDirectory(at: pipDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [install]
        uploaded-prior-to = P6D
        """.write(to: pipDirectory.appendingPathComponent("pip.conf"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/pip/pip.conf uploaded-prior-to is below 7 days; set it to at least P7D")
    }

    func testPackageManagerSupplyChainFailsWithStalePipTimestamp() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipDirectory = temporaryDirectory.appendingPathComponent(".config/pip")
        try FileManager.default.createDirectory(at: pipDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [install]
        uploaded-prior-to = 2026-03-27
        """.write(to: pipDirectory.appendingPathComponent("pip.conf"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/pip/pip.conf uploaded-prior-to is an absolute timestamp that goes stale; set it to a duration like P7D")
    }

    func testPackageManagerSupplyChainFailsWithOldPip() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pipDirectory = temporaryDirectory.appendingPathComponent(".config/pip")
        try FileManager.default.createDirectory(at: pipDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [install]
        uploaded-prior-to = P7D
        """.write(to: pipDirectory.appendingPathComponent("pip.conf"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["pip"],
            packageManagerVersions: ["pip": "pip 26.0.0 from /usr/lib/pip (python 3.13)"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- pip is older than 26.1.0 and does not enforce ~/.config/pip/pip.conf uploaded-prior-to")
    }

    func testPackageManagerSupplyChainPassesWithPoetryCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let poetryDirectory = temporaryDirectory.appendingPathComponent(".config/pypoetry")
        try FileManager.default.createDirectory(at: poetryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [solver]
        min-release-age = 7
        """.write(to: poetryDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["poetry"],
            packageManagerVersions: ["poetry": "Poetry 2.4.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/pypoetry/config.toml delays Poetry package releases")
    }

    func testPackageManagerSupplyChainFailsWithLowPoetryCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let poetryDirectory = temporaryDirectory.appendingPathComponent(".config/pypoetry")
        try FileManager.default.createDirectory(at: poetryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [solver]
        min-release-age = 6
        """.write(to: poetryDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/pypoetry/config.toml solver.min-release-age is below 7 days; set it to at least 7")
    }

    func testPackageManagerSupplyChainPassesWithPdmCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pdmDirectory = temporaryDirectory.appendingPathComponent(".config/pdm")
        try FileManager.default.createDirectory(at: pdmDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [strategy]
        exclude-newer = "7d"
        """.write(to: pdmDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["pdm"],
            packageManagerVersions: ["pdm": "PDM 2.27.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/pdm/config.toml delays PDM package releases")
    }

    func testPackageManagerSupplyChainFailsWithLowPdmCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pdmDirectory = temporaryDirectory.appendingPathComponent(".config/pdm")
        try FileManager.default.createDirectory(at: pdmDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [strategy]
        exclude-newer = "6d"
        """.write(to: pdmDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/pdm/config.toml strategy.exclude-newer is below 7 days; set it to at least 7d")
    }

    func testPackageManagerSupplyChainPassesWithCondaCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        solver: classic
        exclude_newer: 7d
        """.write(to: temporaryDirectory.appendingPathComponent(".condarc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["conda"],
            packageManagerVersions: ["conda": "conda 26.9.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.condarc delays conda package releases")
    }

    func testPackageManagerSupplyChainFailsWithLowCondaCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        solver: classic
        exclude_newer: 6d
        """.write(to: temporaryDirectory.appendingPathComponent(".condarc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.condarc exclude_newer is below 7 days; set it to at least 7d")
    }

    func testPackageManagerSupplyChainFailsWithCondaDefaultSolver() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        exclude_newer: 7d
        """.write(to: temporaryDirectory.appendingPathComponent(".condarc"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["conda"],
            packageManagerVersions: ["conda": "conda 26.9.0"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.condarc solver must be classic; the default solver does not support exclude_newer")
    }

    func testPackageManagerSupplyChainPassesWithBundlerCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundleDirectory = temporaryDirectory.appendingPathComponent(".bundle")
        try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        ---
        BUNDLE_COOLDOWN: 7
        """.write(to: bundleDirectory.appendingPathComponent("config"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedBinaries: ["bundle"],
            packageManagerVersions: ["bundle": "Bundler version 4.0.13"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.bundle/config delays Bundler package releases")
    }

    func testPackageManagerSupplyChainFailsWithLowBundlerCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundleDirectory = temporaryDirectory.appendingPathComponent(".bundle")
        try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        ---
        BUNDLE_COOLDOWN: 6
        """.write(to: bundleDirectory.appendingPathComponent("config"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.bundle/config BUNDLE_COOLDOWN is below 7 days; set it to at least 7 with bundle config set --global cooldown 7")
    }

    func testPackageManagerSupplyChainPassesWithHexCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let hexDirectory = temporaryDirectory.appendingPathComponent(".hex")
        try FileManager.default.createDirectory(at: hexDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        {cooldown,<<"7d">>}.
        """.write(to: hexDirectory.appendingPathComponent("hex.config"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["mix"])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.hex/hex.config delays Hex package releases")
    }

    func testPackageManagerSupplyChainFailsWithLowHexCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let hexDirectory = temporaryDirectory.appendingPathComponent(".hex")
        try FileManager.default.createDirectory(at: hexDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        {cooldown,<<"3d">>}.
        """.write(to: hexDirectory.appendingPathComponent("hex.config"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.hex/hex.config cooldown is below 7 days; set it to at least 7d with mix hex.config cooldown 7d")
    }

    func testPackageManagerSupplyChainPassesWithMiseCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let miseDirectory = temporaryDirectory.appendingPathComponent(".config/mise")
        try FileManager.default.createDirectory(at: miseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [settings]
        minimum_release_age = "7d"
        """.write(to: miseDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["mise"])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/mise/config.toml delays mise package releases")
    }

    func testPackageManagerSupplyChainFailsWithLowMiseCooldown() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let miseDirectory = temporaryDirectory.appendingPathComponent(".config/mise")
        try FileManager.default.createDirectory(at: miseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [settings]
        minimum_release_age = "6d"
        """.write(to: miseDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: [])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/mise/config.toml settings.minimum_release_age is below 7 days; set it to at least 7d")
    }

    func testPackageManagerSupplyChainAcceptsUvIsoDuration() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let uvDirectory = temporaryDirectory.appendingPathComponent(".config/uv")
        try FileManager.default.createDirectory(at: uvDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        exclude-newer = "P7D"
        """.write(to: uvDirectory.appendingPathComponent("uv.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["uv"])

        XCTAssertTrue(check.checkPasses())
    }

    func testPackageManagerSupplyChainFailsWithStaleUvTimestamp() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let uvDirectory = temporaryDirectory.appendingPathComponent(".config/uv")
        try FileManager.default.createDirectory(at: uvDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        exclude-newer = "2026-03-27T00:00:00Z"
        """.write(to: uvDirectory.appendingPathComponent("uv.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["uv"])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.config/uv/uv.toml exclude-newer is an absolute timestamp that goes stale; set it to a relative duration like 7 days")
    }

    func testPackageManagerSupplyChainAcceptsBunfigDurations() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try """
        [install]
        minimumReleaseAge = "7d"
        """.write(to: temporaryDirectory.appendingPathComponent(".bunfig.toml"), atomically: true, encoding: .utf8)

        let check = PackageManagerSupplyChainCheck(homeDirectory: temporaryDirectory, installedBinaries: ["bun"])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/.bunfig.toml delays Bun package releases")
    }

    func testPackageManagerSupplyChainExtractsVersionTokens() {
        XCTAssertEqual(PackageManagerSupplyChainCheck.versionToken(from: "11.10.0"), "11.10.0")
        XCTAssertEqual(PackageManagerSupplyChainCheck.versionToken(from: "pip 26.1.0 from /usr/lib/pip (python 3.13)"), "26.1.0")
        XCTAssertEqual(PackageManagerSupplyChainCheck.versionToken(from: "Bundler version 2.6.7"), "2.6.7")
        XCTAssertEqual(PackageManagerSupplyChainCheck.versionToken(from: "conda 26.9.0"), "26.9.0")
        XCTAssertEqual(PackageManagerSupplyChainCheck.versionToken(from: "Poetry 2.4.0"), "2.4.0")
        XCTAssertNil(PackageManagerSupplyChainCheck.versionToken(from: "  \n"))
    }

    @MainActor
    func testSnooze() {
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
