//
//  FirewallExceptionsCheckTests.swift
//  ParetoSecurityTests
//
//  Created by ArchitektApx on 06/11/2026.
//

import Defaults
@testable import Pareto_Security
import XCTest

class FirewallExceptionsCheckTests: XCTestCase {
    private var savedIgnoredApps: [String] = []

    override func setUp() {
        super.setUp()
        savedIgnoredApps = Defaults[.ignoredFirewallApps]
        Defaults.reset(.ignoredFirewallApps)
    }

    override func tearDown() {
        if savedIgnoredApps.isEmpty {
            Defaults.reset(.ignoredFirewallApps)
        } else {
            Defaults[.ignoredFirewallApps] = savedIgnoredApps
        }
        super.tearDown()
    }

    /// Captured verbatim from `socketfilterfw --listapps` on a macOS 13.7.4 VM.
    private let venturaListApps = [
        "ALF: total number of apps = 2 ",
        "",
        "1 :  /System/Applications/Calculator.app ",
        " \t ( Allow incoming connections ) ",
        "",
        "2 :  /System/Applications/Font Book.app ",
        " \t ( Block incoming connections ) ",
        "",
        "",
    ].joined(separator: "\n")

    /// Captured verbatim from `socketfilterfw --listapps` on a macOS 26.6.2 VM.
    private let tahoeListApps = [
        "Total number of apps = 10 ",
        "1 : /usr/local/libexec/remotepairingdeviced ",
        "             (Allow incoming connections)",
        "2 : /usr/libexec/remoted ",
        "             (Allow incoming connections)",
        "3 : /usr/bin/python3 ",
        "             (Allow incoming connections)",
        "4 : /usr/bin/ruby ",
        "             (Allow incoming connections)",
        "5 : /usr/sbin/cupsd ",
        "             (Allow incoming connections)",
        "6 : /usr/libexec/sharingd ",
        "             (Allow incoming connections)",
        "7 : /usr/libexec/sshd-keygen-wrapper ",
        "             (Allow incoming connections)",
        "8 : /usr/sbin/smbd ",
        "             (Allow incoming connections)",
        "9 : /System/Applications/Calculator.app ",
        "             (Allow incoming connections)",
        "10 : /System/Applications/Font Book.app ",
        "             (Block incoming connections)",
        "",
    ].joined(separator: "\n")

    private let tahoeAllowedPaths = [
        "/usr/local/libexec/remotepairingdeviced",
        "/usr/libexec/remoted",
        "/usr/bin/python3",
        "/usr/bin/ruby",
        "/usr/sbin/cupsd",
        "/usr/libexec/sharingd",
        "/usr/libexec/sshd-keygen-wrapper",
        "/usr/sbin/smbd",
        "/System/Applications/Calculator.app",
    ]

    private func makeCheck(
        _ output: String?,
        requiresHeader: Bool = true,
        signers: [String: FirewallExceptionsCheck.Signer] = [:]
    ) -> FirewallExceptionsCheck {
        FirewallExceptionsCheck(
            listAppsProvider: { output },
            requiresHeader: requiresHeader,
            signerProvider: { signers[$0] ?? .other }
        )
    }

    private func listApps(_ entries: [(String, Bool)]) -> String {
        var lines = ["Total number of apps = \(entries.count) "]
        for (index, entry) in entries.enumerated() {
            lines.append("\(index + 1) : \(entry.0) ")
            let status = entry.1 ? "(Allow incoming connections)" : "(Block incoming connections)"
            lines.append("             \(status)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func app(_ path: String, allows: Bool) -> FirewallExceptionsCheck.App {
        FirewallExceptionsCheck.App(path: path, allowsIncoming: allows)
    }

    // MARK: - Parser

    func testParsesVenturaCapture() {
        XCTAssertEqual(FirewallExceptionsCheck.parseListApps(venturaListApps, requiresHeader: false), [
            app("/System/Applications/Calculator.app", allows: true),
            app("/System/Applications/Font Book.app", allows: false),
        ])
    }

    func testParsesTahoeCapture() throws {
        let apps = try XCTUnwrap(FirewallExceptionsCheck.parseListApps(tahoeListApps, requiresHeader: true))

        XCTAssertEqual(apps.count, 10)
        XCTAssertEqual(apps.filter(\.allowsIncoming).map(\.path), tahoeAllowedPaths)
        XCTAssertEqual(apps.last, app("/System/Applications/Font Book.app", allows: false))
    }

    /// Captured verbatim with no apps: nothing on macOS 13.7.4 and 14.8.7 VMs, the header on 15.7.7 and 26.6.2.
    func testParsesEmptyListOnMacOS13And14() {
        XCTAssertEqual(FirewallExceptionsCheck.parseListApps("", requiresHeader: false), [])
        XCTAssertEqual(FirewallExceptionsCheck.parseListApps("\n", requiresHeader: false), [])
    }

    func testParsesEmptyListOnMacOS15AndLater() {
        XCTAssertEqual(FirewallExceptionsCheck.parseListApps("Total number of apps = 0 \n", requiresHeader: true), [])
        XCTAssertNil(FirewallExceptionsCheck.parseListApps("", requiresHeader: true))
        XCTAssertNil(FirewallExceptionsCheck.parseListApps("\n", requiresHeader: true))
    }

    func testParsesPathsWithSpacesAndParentheses() {
        let output = "Total number of apps = 1 \n1 : /Applications/My App (Beta) 2.app \n (Allow incoming connections)\n"

        XCTAssertEqual(
            FirewallExceptionsCheck.parseListApps(output, requiresHeader: true),
            [app("/Applications/My App (Beta) 2.app", allows: true)]
        )
    }

    func testParsesPathsWithUnicodeLineSeparators() {
        let output = "Total number of apps = 1 \n1 : /Applications/A\u{2028}B\u{85}C.app \n (Block incoming connections)\n"

        XCTAssertEqual(
            FirewallExceptionsCheck.parseListApps(output, requiresHeader: true),
            [app("/Applications/A\u{2028}B\u{85}C.app", allows: false)]
        )
    }

    func testStatusTextInsidePathDoesNotChangeEntries() {
        let output = [
            "Total number of apps = 2 ",
            "1 : /Applications/(Allow incoming connections).app ",
            "             (Block incoming connections)",
            "2 : (Allow incoming connections) ",
            "             (Block incoming connections)",
        ].joined(separator: "\n")

        XCTAssertEqual(FirewallExceptionsCheck.parseListApps(output, requiresHeader: true), [
            app("/Applications/(Allow incoming connections).app", allows: false),
            app("(Allow incoming connections)", allows: false),
        ])
    }

    func testParsesCRLF() {
        let output = venturaListApps.replacingOccurrences(of: "\n", with: "\r\n")

        XCTAssertEqual(FirewallExceptionsCheck.parseListApps(output, requiresHeader: false)?.count, 2)
    }

    func testRejectsUnreadableOutput() {
        let unreadable = [
            "socketfilterfw: command not found",
            "Total number of apps = many \n",
            "Total number of apps = -1 \n",
            "Total number of apps = \(Int.max) \n",
            "1 : /System/Applications/Calculator.app \n (Allow incoming connections)\n",
            tahoeListApps.replacingOccurrences(of: "= 10 ", with: "= 11 "),
            tahoeListApps.replacingOccurrences(of: "= 10 ", with: "= 9 "),
            venturaListApps.replacingOccurrences(of: "( Block incoming connections )", with: "( Unknown )"),
            venturaListApps.replacingOccurrences(of: "( Allow incoming connections )", with: "Allow incoming connections"),
            venturaListApps.replacingOccurrences(of: "2 :  /System", with: "3 :  /System"),
            "Total number of apps = 1 \n1 : \n (Allow incoming connections)\n",
            "Total number of apps = 1 \n (Allow incoming connections)\n1 : /usr/sbin/smbd \n",
            "warning: something went wrong\n" + tahoeListApps,
        ]

        for output in unreadable {
            XCTAssertNil(FirewallExceptionsCheck.parseListApps(output, requiresHeader: true), output)
        }
    }

    // MARK: - Check result

    func testFailsWithAllowedAppOnVentura() {
        let check = makeCheck(venturaListApps)

        XCTAssertFalse(check.checkPasses())
        XCTAssertFalse(check.hasError)
        XCTAssertEqual(check.details, "- /System/Applications/Calculator.app")
    }

    func testFailsWithAllowedAppsOnTahoe() {
        let check = makeCheck(tahoeListApps)

        XCTAssertFalse(check.checkPasses())
        XCTAssertFalse(check.hasError)
        XCTAssertEqual(check.details, tahoeAllowedPaths.map { "- \($0)" }.joined(separator: "\n"))
    }

    func testPassesWithBlockedAppsOnly() {
        let check = makeCheck(tahoeListApps.replacingOccurrences(of: "(Allow", with: "(Block"))

        XCTAssertTrue(check.checkPasses())
        XCTAssertFalse(check.hasError)
        XCTAssertEqual(check.details, "None")
    }

    func testPassesWithoutAppsOnMacOS13And14() {
        let check = makeCheck("", requiresHeader: false)

        XCTAssertTrue(check.checkPasses())
        XCTAssertFalse(check.hasError)
        XCTAssertEqual(check.details, "None")
    }

    func testErrorsWithEmptyOutputOnMacOS15AndLater() {
        let check = makeCheck("", requiresHeader: true)

        XCTAssertFalse(check.checkPasses())
        XCTAssertTrue(check.hasError)
    }

    func testErrorsWhenCommandFails() {
        let check = makeCheck(nil, requiresHeader: false)

        XCTAssertFalse(check.checkPasses())
        XCTAssertTrue(check.hasError)
    }

    func testListAppsReturnsNilWhenToolIsMissingOrFails() {
        XCTAssertNil(FirewallExceptionsCheck.listApps(app: "/nonexistent/socketfilterfw"))
        XCTAssertNil(FirewallExceptionsCheck.listApps(app: "/usr/bin/false"))
    }

    func testErrorsWhenOutputIsUnreadable() {
        let check = makeCheck("Total number of apps = 3 \n")

        XCTAssertFalse(check.checkPasses())
        XCTAssertTrue(check.hasError)
    }

    // MARK: - Ignore list

    func testIgnoredAllowedAppPasses() {
        Defaults[.ignoredFirewallApps] = ["/System/Applications/Calculator.app"]
        let check = makeCheck(venturaListApps)

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "None")
    }

    func testIgnoredAppIsRemovedFromDetails() {
        Defaults[.ignoredFirewallApps] = ["/usr/bin/python3", "/usr/bin/ruby"]
        let check = makeCheck(tahoeListApps)

        XCTAssertFalse(check.checkPasses())
        XCTAssertFalse(check.details.contains("/usr/bin/python3"))
        XCTAssertFalse(check.details.contains("/usr/bin/ruby"))
        XCTAssertTrue(check.details.contains("- /usr/sbin/smbd"))
    }

    func testIgnoredPathsNotInListHaveNoEffect() {
        Defaults[.ignoredFirewallApps] = ["/Applications/Other.app", "Calculator.app", "/System/Applications/Calculator"]
        let check = makeCheck(venturaListApps)

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- /System/Applications/Calculator.app")
    }

    // MARK: - Trusted apps

    func testAppleSignedAppsPass() {
        let output = listApps([("/usr/libexec/sharingd", true), ("/System/Applications/Calculator.app", true)])
        let check = makeCheck(output, signers: [
            "/usr/libexec/sharingd": .apple,
            "/System/Applications/Calculator.app": .apple,
        ])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.evaluate()?.map(\.trust), [.apple, .apple])
    }

    func testAppStoreAppsPass() {
        let output = listApps([("/Applications/WireGuard.app", true)])
        let check = makeCheck(output, signers: ["/Applications/WireGuard.app": .appStore])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.evaluate()?.first?.trust, .appStore)
    }

    func testDeveloperIDAppsFail() {
        let output = listApps([("/Applications/Transmission.app", true), ("/usr/libexec/sharingd", true)])
        let check = makeCheck(output, signers: ["/usr/libexec/sharingd": .apple])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- /Applications/Transmission.app")
    }

    func testAppleSignedInterpretersStillFail() {
        let python = "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/"
            + "Resources/Python.app"
        let output = listApps([("/usr/bin/python3", true), ("/usr/bin/ruby", true), (python, true)])
        let check = makeCheck(output, signers: ["/usr/bin/python3": .apple, "/usr/bin/ruby": .apple, python: .apple])

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.exceptions(), ["/usr/bin/python3", "/usr/bin/ruby", python])
    }

    func testInterpreterNames() {
        for path in ["/usr/bin/python3", "/opt/homebrew/bin/python3.12", "/usr/bin/ruby", "/usr/bin/perl5.34",
                     "/usr/local/bin/node", "/bin/zsh", "/usr/bin/osascript", "/a/Python.app"]
        {
            XCTAssertTrue(FirewallExceptionsCheck.isInterpreter(path), path)
        }
        for path in ["/usr/libexec/sharingd", "/Applications/Node Studio.app", "/usr/sbin/smbd", "/a/pythonista"] {
            XCTAssertFalse(FirewallExceptionsCheck.isInterpreter(path), path)
        }
    }

    // MARK: - Helpers inside app bundles

    func testOwningBundle() {
        XCTAssertEqual(
            FirewallExceptionsCheck.owningBundle(
                of: "/Applications/Arc.app/Contents/Frameworks/ArcCore.framework/Versions/A/Helpers/Browser Helper.app"
            ),
            "/Applications/Arc.app"
        )
        XCTAssertEqual(
            FirewallExceptionsCheck.owningBundle(of: "/Applications/WiFiman.app/Wrapper/WiFiman.app/WiFiman"),
            "/Applications/WiFiman.app"
        )
        XCTAssertEqual(FirewallExceptionsCheck.owningBundle(of: "/usr/sbin/smbd"), "/usr/sbin/smbd")
        XCTAssertEqual(
            FirewallExceptionsCheck.owningBundle(of: "/Applications/Spotify.app"),
            "/Applications/Spotify.app"
        )
    }

    func testHelpersGroupUnderTheirApp() {
        let helper = "/Applications/Arc.app/Contents/Frameworks/ArcCore.framework/Versions/A/Helpers/Browser Helper.app"
        let output = listApps([("/Applications/Arc.app/Contents/MacOS/Arc", true), (helper, true)])
        let check = makeCheck(output)

        let exceptions = check.evaluate()
        XCTAssertEqual(exceptions?.count, 1)
        XCTAssertEqual(exceptions?.first?.bundle, "/Applications/Arc.app")
        XCTAssertEqual(exceptions?.first?.paths, ["/Applications/Arc.app/Contents/MacOS/Arc", helper])
        XCTAssertEqual(check.details, "- /Applications/Arc.app")
    }

    func testAllowingAnAppCoversItsHelpers() {
        Defaults[.ignoredFirewallApps] = ["/Applications/Arc.app"]
        let helper = "/Applications/Arc.app/Contents/Frameworks/ArcCore.framework/Versions/A/Helpers/Browser Helper.app"
        let output = listApps([("/Applications/Arc.app/Contents/MacOS/Arc", true), (helper, true)])
        let check = makeCheck(output)

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.evaluate()?.first?.trust, .user)
    }

    func testAllowingAnAppDoesNotCoverSimilarNames() {
        Defaults[.ignoredFirewallApps] = ["/Applications/Arc.app"]
        let check = makeCheck(listApps([("/Applications/Arc.app Beta.app", true)]))

        XCTAssertFalse(check.checkPasses())
    }

    func testUnsignedHelperInsideTrustedAppFails() {
        let main = "/Applications/Tool.app/Contents/MacOS/Tool"
        let helper = "/Applications/Tool.app/Contents/Helpers/agent"
        let check = makeCheck(listApps([(main, true), (helper, true)]), signers: [main: .appStore])

        XCTAssertFalse(check.checkPasses())
        XCTAssertNil(check.evaluate()?.first?.trust)
    }

    func testMissingAppsPass() {
        let output = listApps([("/Applications/Gone.app", true), ("/usr/libexec/sharingd", true)])
        let check = makeCheck(output, signers: ["/Applications/Gone.app": .missing, "/usr/libexec/sharingd": .apple])

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.evaluate()?.map(\.trust), [.notInstalled, .apple])
    }

    func testAppsOnUnmountedVolumesStillFail() {
        XCTAssertEqual(FirewallExceptionsCheck.signer(of: "/Volumes/NotMounted-\(UUID())/Tool.app"), .other)
    }

    func testSystemProtectedLocations() {
        XCTAssertTrue(FirewallExceptionsCheck.isSystemProtected("/usr/sbin/cupsd"))
        XCTAssertTrue(FirewallExceptionsCheck.isSystemProtected("/System/Applications/Calculator.app"))
        XCTAssertFalse(FirewallExceptionsCheck.isSystemProtected("/usr/local/bin/tool"))
        XCTAssertFalse(FirewallExceptionsCheck.isSystemProtected("/Applications/Tool.app"))
        XCTAssertFalse(FirewallExceptionsCheck.isSystemProtected("/opt/homebrew/bin/tool"))
    }

    func testMainExecutableIsNotAHelper() {
        let exception = FirewallExceptionsCheck.Exception(
            bundle: "/Applications/Arc.app",
            paths: [
                "/Applications/Arc.app/Contents/MacOS/Arc",
                "/Applications/Arc.app/Contents/Frameworks/ArcCore.framework/Helpers/Browser Helper.app",
            ],
            trust: nil
        )
        XCTAssertEqual(FirewallExceptionsCheck.helpers(of: exception).count, 1)
    }

    func testSignerOfRealBinaries() {
        XCTAssertEqual(FirewallExceptionsCheck.signer(of: "/usr/libexec/sharingd"), .apple)
        XCTAssertEqual(FirewallExceptionsCheck.signer(of: "/System/Applications/Calculator.app"), .apple)
        XCTAssertEqual(FirewallExceptionsCheck.signer(of: "/nonexistent/app"), .missing)
        XCTAssertEqual(FirewallExceptionsCheck.signer(of: "/bin/sh"), .apple)
    }

    // MARK: - Dependency and registration

    func testIsRunnableFollowsFirewallCheck() {
        let firewall = FirewallCheck.sharedInstance
        let check = makeCheck("")
        let stored = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        defer {
            for key in [firewall.EnabledKey, check.EnabledKey] {
                UserDefaults.standard.set(stored[key], forKey: key)
            }
        }

        check.isActive = true
        firewall.isActive = false
        XCTAssertFalse(check.isRunnable)
        XCTAssertFalse(check.showSettings)

        firewall.isActive = true
        XCTAssertTrue(check.isRunnable)
        XCTAssertTrue(check.showSettings)

        check.isActive = false
        XCTAssertFalse(check.isRunnable)
    }

    func testIsRegisteredAfterFirewallStealthCheck() throws {
        let claim = try XCTUnwrap(Claims.global.all.first { $0.title == "Firewall & Sharing" })
        let stealth = try XCTUnwrap(claim.checks.firstIndex { $0 === FirewallStealthCheck.sharedInstance })

        XCTAssertEqual(claim.checks.firstIndex { $0 === FirewallExceptionsCheck.sharedInstance }, stealth + 1)
    }

    // MARK: - Live socketfilterfw on this Mac

    func testParsesLiveListApps() throws {
        let output = try XCTUnwrap(FirewallExceptionsCheck.listApps())
        XCTAssertNotNil(FirewallExceptionsCheck.parseListApps(output))
    }

    func testLiveEvaluationKeepsEveryAllowedEntry() throws {
        let output = try XCTUnwrap(FirewallExceptionsCheck.listApps())
        let allowed = try XCTUnwrap(FirewallExceptionsCheck.parseListApps(output)).filter(\.allowsIncoming).map(\.path)
        let check = FirewallExceptionsCheck(listAppsProvider: { output })
        let exceptions = try XCTUnwrap(check.evaluate())

        XCTAssertEqual(exceptions.flatMap(\.paths).sorted(), allowed.sorted())
    }

    func testListAppsOutputIsNotLocalized() throws {
        let english = try FirewallExceptionsCheck.parseListApps(XCTUnwrap(FirewallExceptionsCheck.listApps()))
        let french = try FirewallExceptionsCheck.parseListApps(runCMD(
            app: "/usr/libexec/ApplicationFirewall/socketfilterfw",
            args: ["--listapps"],
            environment: ["LANG": "fr_FR.UTF-8", "LC_ALL": "fr_FR.UTF-8", "AppleLanguages": "(fr)"]
        ))

        XCTAssertNotNil(french)
        XCTAssertEqual(french, english)
    }
}
