//
//  CompromisedCATests.swift
//  Pareto Security
//

@testable import Pareto_Security
import XCTest

class CompromisedCACheckTests: XCTestCase {
    let testCertificatePEM = """
    -----BEGIN CERTIFICATE-----
    MIIDmTCCAoGgAwIBAgIUHSu6JT/dze5yiOhho2Wp6jImRv0wDQYJKoZIhvcNAQEL
    BQAwWzELMAkGA1UEBhMCVVMxFDASBgNVBAoMC1BhcmV0byBUZXN0MRgwFgYDVQQL
    DA9QYXJldG8gVGVzdCBQS0kxHDAaBgNVBAMME1BhcmV0byBUZXN0IFJvb3QgQ0Ew
    IBcNMjYxMDIxMTMzMjU0WhgPMjEyNjA5MjcxMzMyNTRaMFsxCzAJBgNVBAYTAlVT
    MRQwEgYDVQQKDAtQYXJldG8gVGVzdDEYMBYGA1UECwwPUGFyZXRvIFRlc3QgUEtJ
    MRwwGgYDVQQDDBNQYXJldG8gVGVzdCBSb290IENBMIIBIjANBgkqhkiG9w0BAQEF
    AAOCAQ8AMIIBCgKCAQEA6lvo28nbDH6tjE9XiwKdGLwQXe+jaaCwtesIHAMT8F+o
    TY9hKW65sgmZTcHOLocl0n3wkgFu5oEUKh58p/kqymSqYnkJSfW7SN2mVXC7HHLu
    sOk/CDsoUhwdHNeJhYvRaTwMuG5teKHH0ceZ4yF8b+Ty+/SwUNi35II/0gJ/MNTQ
    gYSqgAnm96Vh+VBdeahOscdrVJdPXSEoxtSc3LerMAsyKAeyDdsiPmsk9UryPZdf
    Izi6ZWWLPUXZuiYCpXg9q6AXq73yjPZE4839PaXHQRqhEMlzFg/256a6aHDeJ6pr
    +NdJtGFlkkZSs3vFhkB8JoqATQa7LCzqrCdK4EH7OQIDAQABo1MwUTAdBgNVHQ4E
    FgQUtTpFJjetHLKxUHUGmYOIDqW7VFMwHwYDVR0jBBgwFoAUtTpFJjetHLKxUHUG
    mYOIDqW7VFMwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAAYiM
    nbn79LbqCfP56eqMlo4W4W9OK80amG0Rl+zBoArNpeAhFjsPwEnRYl/xnaBdjfJ7
    CAkjUpw9pxdF3hVJlsd35Grj9ASrnrx9KBkHatzjfHlKbpFF6LY/5s6vbnBoRb6u
    YIt23qpKj+f12priADR9fMCo7P7hWV/T7vZlFVDzVm7JxoJXQRmYTX52PzWtUt4V
    VG5ERbDoL0SzribM61hrOcQf0EcgGoPreZRvpDsEHUID3ttQRdvjWWTQfDjcbm0Q/
    hXNbq+tjroYDjAZu40+H0qRUPduoX2idluAGEK4ecwI5ppt1CYjhlXlzbgPob5w+
    yV9DnRXffa2Xyjo2Lg==
    -----END CERTIFICATE-----
    """

    let testCertificateFingerprint = "4A:EC:BD:0C:84:DD:A2:68:59:FA:BD:9D:F4:E7:E8:EB:B8:07:E0:83:35:1F:59:70:AB:C3:03:68:AA:78:F8:AD"

    lazy var testBlocklist: [String: String] = [testCertificateFingerprint: "Pareto Test Root CA"]

    func testCertificateDERsParsesPEMBlock() {
        let ders = CompromisedCACheck.certificateDERs(in: testCertificatePEM)
        XCTAssertEqual(ders.count, 1)
        XCTAssertEqual(CompromisedCACheck.fingerprint(of: ders[0]), testCertificateFingerprint)
    }

    func testCertificateDERsSkipsMalformedBlocks() {
        let contents = "not a pem\n\(testCertificatePEM)\n-----BEGIN CERTIFICATE-----\n!!!invalid base64!!!\n-----END CERTIFICATE-----"
        let ders = CompromisedCACheck.certificateDERs(in: contents)
        XCTAssertEqual(ders.count, 1)
    }

    func testCompromisedCAsMatchesBlocklistedFingerprint() {
        let found = CompromisedCACheck.compromisedCAs(in: testCertificatePEM, blocklist: testBlocklist)
        XCTAssertEqual(found, ["Pareto Test Root CA"])
    }

    func testCompromisedCAsIgnoresUnknownCertificates() {
        let found = CompromisedCACheck.compromisedCAs(in: testCertificatePEM, blocklist: CompromisedCACheck.compromisedRootCAs)
        XCTAssertTrue(found.isEmpty)
    }

    func testCheckFailsWhenBundleContainsCompromisedCA() {
        let check = CompromisedCACheck(
            bundlePaths: ["/opt/homebrew/etc/ca-certificates/cert.pem"],
            bundleContents: ["/opt/homebrew/etc/ca-certificates/cert.pem": testCertificatePEM],
            blocklist: testBlocklist
        )
        XCTAssertFalse(check.checkPasses())
        XCTAssertTrue(check.details == "- /opt/homebrew/etc/ca-certificates/cert.pem: Pareto Test Root CA")
    }

    func testCheckPassesWithCleanBundles() {
        let check = CompromisedCACheck(
            bundlePaths: ["/etc/ssl/cert.pem", "/opt/homebrew/etc/ca-certificates/cert.pem"],
            bundleContents: [
                "/etc/ssl/cert.pem": testCertificatePEM,
                "/opt/homebrew/etc/ca-certificates/cert.pem": testCertificatePEM,
            ],
            blocklist: CompromisedCACheck.compromisedRootCAs
        )
        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "- Scanned 2 CA bundle(s)")
    }

    func testCheckReportsEachOffendingBundle() {
        let check = CompromisedCACheck(
            bundlePaths: ["/a/cert.pem", "/b/cert.pem"],
            bundleContents: [
                "/a/cert.pem": testCertificatePEM,
                "/b/cert.pem": "",
            ],
            blocklist: testBlocklist
        )
        XCTAssertFalse(check.checkPasses())
        XCTAssertTrue(check.details == "- /a/cert.pem: Pareto Test Root CA")
        XCTAssertFalse(check.details.contains("/b/cert.pem"))
    }

    func testIsRunnableRequiresBundlesAndActiveState() {
        let check = CompromisedCACheck(bundlePaths: [], bundleContents: [:])
        check.isActive = true
        XCTAssertFalse(check.isInstalled)
        XCTAssertFalse(check.isRunnable)

        let enabled = CompromisedCACheck(bundlePaths: ["/etc/ssl/cert.pem"], bundleContents: ["x": "y"])
        enabled.isActive = true
        XCTAssertTrue(enabled.isInstalled)
        XCTAssertTrue(enabled.isRunnable)
        XCTAssertTrue(enabled.showInMenu)
        XCTAssertTrue(enabled.showDetailsWhenPassing)
        XCTAssertEqual(enabled.TitleON, "No compromised CAs are trusted")
        XCTAssertEqual(enabled.TitleOFF, "Compromised CAs are trusted")
    }

    func testResolvedBundlePathsOnlyListsExistingFiles() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let check = CompromisedCACheck(homeDirectory: home)
        for path in check.resolvedBundlePaths() {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), path)
        }
    }

    func testFindsUserSiteCertifiBundle() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let certifi = home.appendingPathComponent("Library/Python/3.12/lib/python/site-packages/certifi")
        try FileManager.default.createDirectory(at: certifi, withIntermediateDirectories: true)
        let bundle = certifi.appendingPathComponent("cacert.pem")
        try testCertificatePEM.write(to: bundle, atomically: true, encoding: .utf8)

        let check = CompromisedCACheck(homeDirectory: home, blocklist: testBlocklist)
        XCTAssertTrue(check.resolvedBundlePaths().contains(bundle.path))
        XCTAssertFalse(check.checkPasses())
    }

    func testScansCurrentNixBundlesOnly() {
        let nixPaths = CompromisedCACheck.systemBundlePaths.filter { $0.contains("nix") || $0.hasPrefix("/etc/ssl/certs") }
        XCTAssertEqual(nixPaths, [
            "/etc/ssl/certs/ca-certificates.crt",
            "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt",
        ])
        XCTAssertFalse(CompromisedCACheck.systemBundlePaths.contains { $0.hasPrefix("/nix/store") })
    }

    func testSymlinkedBundleIsScannedOnce() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let bundle = dir.appendingPathComponent("cert.pem")
        let link = dir.appendingPathComponent("openssl-cert.pem")
        try testCertificatePEM.write(to: bundle, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: bundle)

        let check = CompromisedCACheck(bundlePaths: [bundle.path, link.path], blocklist: testBlocklist)
        XCTAssertEqual(check.resolvedBundlePaths(), [bundle.path])
        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "- \(bundle.path): Pareto Test Root CA")
    }

    func testDetailsGroupRootsPerBundleAndShortenHome() {
        let home = URL(fileURLWithPath: "/Users/test")
        let bundle = "/Users/test/.local/pipx/venvs/tool/lib/python3.11/site-packages/certifi/cacert.pem"
        let check = CompromisedCACheck(
            homeDirectory: home,
            bundlePaths: [bundle],
            bundleContents: [bundle: testCertificatePEM + "\n" + testCertificatePEM],
            blocklist: testBlocklist
        )
        XCTAssertEqual(
            check.details,
            "- ~/.local/pipx/venvs/tool/lib/python3.11/site-packages/certifi/cacert.pem: Pareto Test Root CA"
        )
        XCTAssertEqual(check.displayPath("/Users/tester/cert.pem"), "/Users/tester/cert.pem")
    }

    func testScannedBundlesSortsPathsForStableDetails() {
        let check = CompromisedCACheck(
            bundlePaths: ["/b/cert.pem", "/a/cert.pem"],
            bundleContents: [
                "/b/cert.pem": "",
                "/a/cert.pem": "",
            ]
        )
        XCTAssertEqual(check.scannedBundles().map { $0.path }, ["/a/cert.pem", "/b/cert.pem"])
    }
}
