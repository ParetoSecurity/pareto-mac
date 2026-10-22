//
//  CompromisedCA.swift
//  Pareto Security
//

import CryptoKit
import Foundation

class CompromisedCACheck: ParetoCheck {
    static let sharedInstance = CompromisedCACheck()

    // SHA-256 fingerprints of the DER-encoded certificate, formatted as
    // uppercase colon-separated hex (matches `openssl x509 -fingerprint
    // -sha256`) so entries can be verified manually. Entries are the roots
    // anchoring the compromised eMudhra intermediates disclosed in October
    // 2026, matching the published remediation script's removals. Extend as
    // new incidents are disclosed.

    /// https://emudhra.we-have-a-problem.com
    static let compromisedRootCAs: [String: String] = [
        "86:A1:EC:BA:08:9C:4A:8D:3B:BE:27:34:C6:12:BA:34:1D:81:3E:04:3C:F9:E8:A8:62:CD:5C:57:A3:6B:BE:6B": "emSign ECC Root CA - G3 (eMudhra)",
        "D7:A7:A0:FB:5D:7E:27:31:D7:71:E9:48:4E:BC:DE:F7:1D:5F:0C:3E:0A:29:48:78:2B:C8:3E:E0:EA:69:9E:F4": "AAA Certificate Services (Sectigo)",
    ]

    static let systemBundlePaths = [
        "/etc/ssl/cert.pem",
        "/opt/homebrew/etc/ca-certificates/cert.pem",
        "/usr/local/etc/ca-certificates/cert.pem",
        "/opt/homebrew/etc/openssl@3/cert.pem",
        "/usr/local/etc/openssl@3/cert.pem",
    ]

    let homeDirectory: URL
    let bundlePaths: [String]?
    let bundleContents: [String: String]?
    let blocklist: [String: String]
    let maximumCertifiBundles = 30

    private var certifiCache: [String]?

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        bundlePaths: [String]? = nil,
        bundleContents: [String: String]? = nil,
        blocklist: [String: String] = CompromisedCACheck.compromisedRootCAs
    ) {
        self.homeDirectory = homeDirectory
        self.bundlePaths = bundlePaths
        self.bundleContents = bundleContents
        self.blocklist = blocklist
    }

    override var UUID: String {
        "9af95e09-1aa3-464b-8c32-d760c21e7f51"
    }

    override var TitleON: String {
        "CA bundles contain no compromised certificates"
    }

    override var TitleOFF: String {
        "CA bundles contain compromised certificates"
    }

    override var isInstalled: Bool {
        return !resolvedBundlePaths().isEmpty
    }

    override var isRunnable: Bool {
        return isActive && !resolvedBundlePaths().isEmpty
    }

    override var showInMenu: Bool {
        return isActive && !resolvedBundlePaths().isEmpty
    }

    override var showDetailsWhenPassing: Bool {
        return true
    }

    override var details: String {
        var failures: [String] = []
        var scannedPaths: [String] = []
        for bundle in scannedBundles() {
            scannedPaths.append(bundle.path)
            for ca in Self.compromisedCAs(in: bundle.contents, blocklist: blocklist) {
                failures.append("- \(ca) is present in \(bundle.path)")
            }
        }
        if failures.isEmpty {
            return "- Scanned \(scannedPaths.count) CA bundle(s)"
        }
        return failures.joined(separator: "\n")
    }

    override func checkPasses() -> Bool {
        return scannedBundles().allSatisfy { bundle in
            Self.compromisedCAs(in: bundle.contents, blocklist: blocklist).isEmpty
        }
    }

    func resolvedBundlePaths() -> [String] {
        if let bundlePaths {
            return Self.uniqueBundlePaths(bundlePaths)
        }
        let fileManager = FileManager.default
        let paths = Self.systemBundlePaths.filter { fileManager.fileExists(atPath: $0) } + certifiBundlePaths()
        return Self.uniqueBundlePaths(paths)
    }

    /// Homebrew's openssl@3/cert.pem is a symlink to ca-certificates/cert.pem;
    /// keep the first path for each underlying file so it is reported once.
    static func uniqueBundlePaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { path in
            seen.insert(URL(fileURLWithPath: path).resolvingSymlinksInPath().path).inserted
        }
    }

    func scannedBundles() -> [(path: String, contents: String)] {
        if let bundleContents {
            return bundleContents
                .map { (path: $0.key, contents: $0.value) }
                .sorted { $0.path < $1.path }
        }
        return resolvedBundlePaths().compactMap { path in
            guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
            return (path: path, contents: contents)
        }
    }

    static func compromisedCAs(in contents: String, blocklist: [String: String]) -> [String] {
        var found: [String] = []
        for der in certificateDERs(in: contents) {
            if let name = blocklist[fingerprint(of: der)] {
                found.append(name)
            }
        }
        return found
    }

    static func fingerprint(of der: Data) -> String {
        SHA256.hash(data: der).map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    static func certificateDERs(in contents: String) -> [Data] {
        var ders: [Data] = []
        for chunk in contents.components(separatedBy: "-----END CERTIFICATE-----") {
            guard let beginRange = chunk.range(of: "-----BEGIN CERTIFICATE-----") else { continue }
            let body = chunk[beginRange.upperBound...].filter { !$0.isWhitespace }
            if let der = Data(base64Encoded: String(body)) {
                ders.append(der)
            }
        }
        return ders
    }

    func certifiBundlePaths() -> [String] {
        if let certifiCache {
            return certifiCache
        }
        var paths: [String] = []
        let fileManager = FileManager.default
        for root in Self.certifiLibraryRoots(homeDirectory: homeDirectory) {
            if paths.count >= maximumCertifiBundles {
                break
            }
            guard let entries = try? fileManager.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries {
                if paths.count >= maximumCertifiBundles {
                    break
                }
                let entryPath = (root as NSString).appendingPathComponent(entry)
                let candidates = Self.certifiCandidates(root: root, entry: entry, entryPath: entryPath)
                paths.append(contentsOf: candidates.filter { fileManager.fileExists(atPath: $0) })
            }
        }
        certifiCache = paths
        return paths
    }

    private static func certifiLibraryRoots(homeDirectory: URL) -> [String] {
        return [
            "/opt/homebrew/lib",
            "/usr/local/lib",
            homeDirectory.appendingPathComponent("Library/Python").path,
            homeDirectory.appendingPathComponent("anaconda3/lib").path,
            homeDirectory.appendingPathComponent("miniconda3/lib").path,
            homeDirectory.appendingPathComponent(".local/pipx/venvs").path,
            "/Library/Frameworks/Python.framework/Versions",
            "/opt/anaconda3/lib",
            "/opt/miniconda3/lib",
        ]
    }

    private static func certifiCandidates(root: String, entry: String, entryPath: String) -> [String] {
        let fileManager = FileManager.default
        if root.hasSuffix("/pipx/venvs") {
            let libPath = (entryPath as NSString).appendingPathComponent("lib")
            guard let pythons = try? fileManager.contentsOfDirectory(atPath: libPath) else { return [] }
            return pythons.filter { $0.hasPrefix("python3") }.map {
                let pythonPath = (libPath as NSString).appendingPathComponent($0)
                return (pythonPath as NSString).appendingPathComponent("site-packages/certifi/cacert.pem")
            }
        }
        // python.org installer: Versions/3.12/lib/python3.12/site-packages
        if root.hasSuffix("Python.framework/Versions") {
            guard entry.hasPrefix("3.") else { return [] }
            return [(entryPath as NSString).appendingPathComponent("lib/python\(entry)/site-packages/certifi/cacert.pem")]
        }
        if entry.hasPrefix("python3") {
            return [(entryPath as NSString).appendingPathComponent("site-packages/certifi/cacert.pem")]
        }
        if entry.hasPrefix("3.") {
            return [(entryPath as NSString).appendingPathComponent("lib/python/site-packages/certifi/cacert.pem")]
        }
        return []
    }
}
