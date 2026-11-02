//
//  EditorExtensionsSupplyChainTests.swift
//  Pareto Security
//

@testable import Pareto_Security
import XCTest

class EditorExtensionsSupplyChainTests: XCTestCase {
    func testEditorExtensionsSupplyChainPassesWithoutEditors() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = EditorExtensionsSupplyChainCheck(homeDirectory: temporaryDirectory, installedApps: [])

        XCTAssertTrue(check.checkPasses())
    }

    func testEditorExtensionsSupplyChainDoesNotRunWithoutAppsOrSettings() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = EditorExtensionsSupplyChainCheck(homeDirectory: temporaryDirectory, installedApps: [])
        check.configure()

        XCTAssertFalse(check.isRunnable)
    }

    func testEditorExtensionsSupplyChainRunsWithDetectedApp() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = EditorExtensionsSupplyChainCheck(homeDirectory: temporaryDirectory, installedApps: ["Visual Studio Code"])
        check.configure()

        XCTAssertTrue(check.isRunnable)
        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Code/User/settings.json is missing")
    }

    func testEditorExtensionsSupplyChainRunsWithoutDetectedAppWhenSettingsExist() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{}".write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(homeDirectory: temporaryDirectory, installedApps: [])
        check.configure()

        XCTAssertTrue(check.isRunnable)
        XCTAssertFalse(check.checkPasses())
    }

    func testEditorExtensionsSupplyChainPassesWithConfiguredDelay() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdateDelay": 168,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code"],
            appVersions: ["Visual Studio Code": "1.126.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Code/User/settings.json delays Visual Studio Code extension updates")
    }

    func testEditorExtensionsSupplyChainFailsWithBelowThresholdDelay() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdateDelay": 72,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code"],
            appVersions: ["Visual Studio Code": "1.126.0"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Code/User/settings.json extensions.autoUpdateDelay is below 168 hours; set it to at least 168")
    }

    func testEditorExtensionsSupplyChainFailsWithoutSetting() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "workbench.colorTheme": "Default Dark Modern",
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code"],
            appVersions: ["Visual Studio Code": "1.124.0"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Code/User/settings.json extensions.autoUpdateDelay is not set; set it to at least 168 hours")
    }

    func testEditorExtensionsSupplyChainPassesWithDisabledAutoUpdate() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdate": false,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code"],
            appVersions: ["Visual Studio Code": "1.124.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Code/User/settings.json has automatic extension updates disabled")
    }

    func testEditorExtensionsSupplyChainPassesWithAutoUpdateOff() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdate": "off"
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code"],
            appVersions: ["Visual Studio Code": "1.124.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Code/User/settings.json has automatic extension updates disabled")
    }

    func testEditorExtensionsSupplyChainFailsWithOnlyEnabledExtensionsAutoUpdate() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdate": "onlyEnabledExtensions",
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code"],
            appVersions: ["Visual Studio Code": "1.126.0"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Code/User/settings.json extensions.autoUpdateDelay is not set; set it to at least 168 hours")
    }

    func testEditorExtensionsSupplyChainFailsWithUnsupportedVSCodeVersion() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdateDelay": 168,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code"],
            appVersions: ["Visual Studio Code": "1.124.0"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- Visual Studio Code is older than 1.125.0 and does not enforce extensions.autoUpdateDelay")
    }

    func testEditorExtensionsSupplyChainPassesWithSupportedVSCodeVersion() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdateDelay": 168,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code"],
            appVersions: ["Visual Studio Code": "1.125.0"]
        )

        XCTAssertTrue(check.checkPasses())
    }

    func testEditorExtensionsSupplyChainFailsWithUnknownVSCodeVersion() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdateDelay": 168,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(homeDirectory: temporaryDirectory, installedApps: ["Visual Studio Code"])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- Visual Studio Code version could not be determined, so extensions.autoUpdateDelay could not be verified")
    }

    func testEditorExtensionsSupplyChainIgnoresCommentedOutSettings() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            // "extensions.autoUpdateDelay": 168,
            /* "extensions.autoUpdateDelay": 336 */
            "workbench.colorTheme": "Default Dark Modern",
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code"],
            appVersions: ["Visual Studio Code": "1.126.0"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Code/User/settings.json extensions.autoUpdateDelay is not set; set it to at least 168 hours")
    }

    func testEditorExtensionsSupplyChainParsesJSONCSettings() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            // The theme stays untouched
            "workbench.colorTheme": "Default Dark Modern", /* trailing comment */
            "extensions.autoUpdateDelay": 336,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code"],
            appVersions: ["Visual Studio Code": "1.126.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Code/User/settings.json delays Visual Studio Code extension updates")
    }

    func testEditorExtensionsSupplyChainValidatesVSCodium() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/VSCodium/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdateDelay": 168,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["VSCodium"],
            appVersions: ["VSCodium": "1.126.0"]
        )

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/VSCodium/User/settings.json delays VSCodium extension updates")
    }

    func testEditorExtensionsSupplyChainValidatesInsiders() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Code - Insiders/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdateDelay": 24,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(
            homeDirectory: temporaryDirectory,
            installedApps: ["Visual Studio Code - Insiders"],
            appVersions: ["Visual Studio Code - Insiders": "1.126.0"]
        )

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Code - Insiders/User/settings.json extensions.autoUpdateDelay is below 168 hours; set it to at least 168")
    }

    func testEditorExtensionsSupplyChainValidatesCursor() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let check = EditorExtensionsSupplyChainCheck(homeDirectory: temporaryDirectory, installedApps: ["Cursor"])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Cursor/User/settings.json is missing")

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Cursor/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.installCooldownHours": 24,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Cursor/User/settings.json extensions.installCooldownHours is below 168 hours; set it to at least 168")

        try """
        {
            "extensions.installCooldownHours": 168,
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Cursor/User/settings.json delays Cursor extension updates")
    }

    func testEditorExtensionsSupplyChainPassesWithCursorAutoUpdateOff() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let settings = temporaryDirectory.appendingPathComponent("Library/Application Support/Cursor/User/settings.json", isDirectory: false)
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
            "extensions.autoUpdate": "off"
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let check = EditorExtensionsSupplyChainCheck(homeDirectory: temporaryDirectory, installedApps: ["Cursor"])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- ~/Library/Application Support/Cursor/User/settings.json has automatic extension updates disabled")
    }
}
