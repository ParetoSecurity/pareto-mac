//
//  MiseIntegrationTests.swift
//  Pareto Security
//
//  Runs the sandboxed version lookup against a real mise-managed Node.js.
//  Skipped when mise is not installed; CI installs it with Homebrew.
//

@testable import Pareto_Security
import XCTest

class MiseIntegrationTests: XCTestCase {
    static let nodeVersion = "24.22.3"
    /// npm bundled with `nodeVersion`; above the 11.14.0 min-release-age gate.
    static let npmVersion = "11.19.1"
    static let miseConfigFiles = [".config/mise/config.toml", ".mise.toml", "mise.toml", ".tool-versions"]

    private static var sharedHome: URL?
    private static var setupError: String?

    var home: URL {
        get throws {
            if let error = Self.setupError {
                throw XCTSkip(error)
            }
            return try XCTUnwrap(Self.sharedHome)
        }
    }

    // MARK: - Setup

    /// Installs Node.js once per run into a throwaway home, using a copy of
    /// mise inside it so the shims point at a binary the sandbox may run.
    override class func setUp() {
        super.setUp()
        guard let mise = ["/opt/homebrew/bin/mise", "/usr/local/bin/mise", NSHomeDirectory() + "/.local/bin/mise"]
            .first(where: FileManager.default.isExecutableFile(atPath:))
        else {
            setupError = "mise is not installed"
            return
        }
        do {
            let home = FileManager.default.temporaryDirectory.appendingPathComponent("pareto-mise-\(UUID().uuidString)")
                .resolvingSymlinksInPath()
            let bin = home.appendingPathComponent(".local/bin")
            try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
            try FileManager.default.copyItem(atPath: (mise as NSString).resolvingSymlinksInPath, toPath: bin.appendingPathComponent("mise").path)
            sharedHome = home
            try writeGlobalConfig(in: home)
            try runMise(["install", "node@\(nodeVersion)"], home: home)
            try runMise(["reshim"], home: home)
        } catch {
            setupError = "mise could not install node@\(nodeVersion): \(error)"
        }
    }

    override class func tearDown() {
        if let sharedHome {
            try? FileManager.default.removeItem(at: sharedHome)
        }
        super.tearDown()
    }

    override func setUpWithError() throws {
        let home = try home
        for path in Self.miseConfigFiles {
            try? FileManager.default.removeItem(at: home.appendingPathComponent(path))
        }
        try? FileManager.default.removeItem(at: home.appendingPathComponent("dotfiles"))
        try? FileManager.default.removeItem(at: home.appendingPathComponent(".npmrc"))
    }

    private static func writeGlobalConfig(in home: URL) throws {
        let config = home.appendingPathComponent(".config/mise/config.toml")
        try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "[tools]\nnode = \"\(nodeVersion)\"\n".write(to: config, atomically: true, encoding: .utf8)
    }

    @discardableResult
    private static func runMise(_ args: [String], home: URL) throws -> String {
        let process = Process()
        process.executableURL = home.appendingPathComponent(".local/bin/mise")
        process.arguments = args
        process.currentDirectoryURL = home
        // Downloads are cached across runs; nothing from the host's mise leaks in.
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent("pareto-mise-cache")
        process.environment = [
            "HOME": home.path, "PATH": "\(home.path)/.local/bin:/usr/bin:/bin", "MISE_CACHE_DIR": cache.path,
            "MISE_YES": "1", "TMPDIR": FileManager.default.temporaryDirectory.path,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "mise", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }
        return output
    }

    // MARK: - Helpers

    private func shimVersion(_ name: String) throws -> String? {
        let home = try home
        let shims = home.appendingPathComponent(".local/share/mise/shims")
        let output = CheckCommand.run(
            app: shims.appendingPathComponent(name).path, args: ["--version"], homeDirectory: home,
            path: [shims.path, home.appendingPathComponent(".local/bin").path]
        )
        return output.flatMap(PackageManagerSupplyChainCheck.versionToken)
    }

    private func write(_ contents: String, to path: String) throws {
        let file = try home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: file, atomically: true, encoding: .utf8)
    }

    // MARK: - Scenarios

    func testShimsResolveGlobalConfig() throws {
        try Self.writeGlobalConfig(in: home)
        XCTAssertEqual(try shimVersion("node"), "v\(Self.nodeVersion)")
        XCTAssertEqual(try shimVersion("npm"), Self.npmVersion)
    }

    /// Dotfiles managers such as GNU Stow symlink the config out of a repository.
    func testShimsResolveSymlinkedGlobalConfig() throws {
        let home = try home
        try write("[tools]\nnode = \"\(Self.nodeVersion)\"\n", to: "dotfiles/mise/config.toml")
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".config/mise"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: home.appendingPathComponent(".config/mise/config.toml"),
            withDestinationURL: home.appendingPathComponent("dotfiles/mise/config.toml")
        )
        XCTAssertEqual(try shimVersion("npm"), Self.npmVersion)
    }

    func testShimsResolveSymlinkedConfigDirectory() throws {
        let home = try home
        try FileManager.default.removeItem(at: home.appendingPathComponent(".config/mise"))
        defer { try? FileManager.default.removeItem(at: home.appendingPathComponent(".config/mise")) }
        try write("[tools]\nnode = \"\(Self.nodeVersion)\"\n", to: "dotfiles/mise/config.toml")
        try FileManager.default.createSymbolicLink(
            at: home.appendingPathComponent(".config/mise"), withDestinationURL: home.appendingPathComponent("dotfiles/mise")
        )
        XCTAssertEqual(try shimVersion("npm"), Self.npmVersion)
    }

    func testShimsResolveHomeRootConfig() throws {
        for path in [".mise.toml", "mise.toml"] {
            try write("[tools]\nnode = \"\(Self.nodeVersion)\"\n", to: path)
            XCTAssertEqual(try shimVersion("npm"), Self.npmVersion, path)
            try FileManager.default.removeItem(at: home.appendingPathComponent(path))
        }
    }

    /// `mise config ls` lists ~/.env when mise is told to load it; the
    /// sandbox must keep blocking it, yet the shims must still answer.
    func testShimsResolveConfigThatLoadsDotEnv() throws {
        let home = try home
        try write("SECRET=private-marker\n", to: ".env")
        defer { try? FileManager.default.removeItem(at: home.appendingPathComponent(".env")) }
        let variants = [
            "[settings]\nenv_file = \".env\"\n",
            "[env]\n_.file = \".env\"\n",
        ]
        for variant in variants {
            try write("[tools]\nnode = \"\(Self.nodeVersion)\"\n\n\(variant)", to: ".config/mise/config.toml")
            XCTAssertEqual(try shimVersion("npm"), Self.npmVersion, variant)
        }
        try Self.writeGlobalConfig(in: home)
    }

    func testShimsResolveToolVersions() throws {
        try write("node \(Self.nodeVersion)\n", to: ".tool-versions")
        XCTAssertEqual(try shimVersion("npm"), Self.npmVersion)
    }

    /// The whole check, with the login shell unavailable so the mise shims
    /// fallback is what finds npm.
    func testCheckDeterminesNpmVersionThroughMiseShims() throws {
        let home = try home
        try write("[tools]\nnode = \"\(Self.nodeVersion)\"\n", to: "dotfiles/mise/config.toml")
        try FileManager.default.createSymbolicLink(
            at: home.appendingPathComponent(".mise.toml"), withDestinationURL: home.appendingPathComponent("dotfiles/mise/config.toml")
        )
        try write("min-release-age=7\nsave-exact=true\n", to: ".npmrc")
        let check = PackageManagerSupplyChainCheck(
            homeDirectory: home,
            shellPath: ShellPath(resolver: { nil }),
            appleBundledDirectories: [],
            systemInstallPrefixes: []
        )

        let npmFailures = check.run { check.validationFailures() }.filter { $0.contains("npm") || $0.contains(".npmrc") }
        XCTAssertEqual(npmFailures, [])
        XCTAssertFalse(check.hasError, check.details)
    }
}

private extension PackageManagerSupplyChainCheck {
    func run<T>(_ body: () -> T) -> T {
        shellPath.withRun(body)
    }
}
