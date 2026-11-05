//
//  ShellPath.swift
//  Pareto Security
//
//  Resolves the PATH the user's interactive login shell would use.
//

import Foundation
import os.log

/// A LaunchServices-launched app only inherits launchd's default PATH, so it
/// cannot tell which `pip3` or `npm` the user actually runs. This asks the
/// user's own shell (with their rc files) once and caches the answer for the
/// duration of a check run. Outside a run nothing is cached and nothing is
/// spawned, so UI code never blocks on a shell.
final class ShellPath {
    static let shared = ShellPath()

    /// Upper bound for a slow `.zshrc`; the scan falls back to the static
    /// prefix list when the shell does not answer in time.
    static let timeout: TimeInterval = 5

    private let lock = NSLock()
    private var runDepth = 0
    private var resolved = false
    private var cachedDirectories: [String]?
    private let resolver: () -> [String]?

    init(resolver: @escaping () -> [String]? = { ShellPath.resolveFromLoginShell() }) {
        self.resolver = resolver
    }

    /// Starts a cached scope. Nested scopes (a single re-check during a full
    /// scan) share the same cache; it is dropped when the outermost ends.
    func beginRun() {
        lock.lock()
        runDepth += 1
        lock.unlock()
    }

    func endRun() {
        lock.lock()
        defer { lock.unlock() }
        runDepth = max(0, runDepth - 1)
        if runDepth == 0 {
            resolved = false
            cachedDirectories = nil
        }
    }

    func withRun<T>(_ body: () -> T) -> T {
        beginRun()
        defer { endRun() }
        return body()
    }

    /// The user's shell PATH entries, or nil outside a run or when the shell
    /// could not be queried.
    var directories: [String]? {
        // UI code (menu, isRunnable) must never wait for a shell: on the main
        // thread only an already-resolved answer is used.
        if Thread.isMainThread {
            guard lock.try() else { return nil }
            defer { lock.unlock() }
            return runDepth > 0 && resolved ? cachedDirectories : nil
        }
        lock.lock()
        defer { lock.unlock() }
        guard runDepth > 0 else { return nil }
        if !resolved {
            // Resolved under the lock so concurrent callers in one run spawn
            // the shell once.
            cachedDirectories = resolver()
            resolved = true
        }
        return cachedDirectories
    }

    // MARK: - Resolution

    static func resolveFromLoginShell() -> [String]? {
        let shell = userShell()
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("pareto-path-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: output) }

        // The PATH goes to a file rather than stdout: rc files may print
        // banners, and a background process they start could keep a pipe open
        // forever. `printenv` prints a colon-joined PATH in sh, bash, zsh and
        // fish alike.
        let command = "/usr/bin/printenv PATH > '\(output.path)'"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-i", "-l", "-c", command]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            os_log("ShellPath: failed to launch %{public}@: %{public}@", log: Log.app, shell, error.localizedDescription)
            return nil
        }

        if finished.wait(timeout: .now() + timeout) == .timedOut {
            // Interactive shells ignore SIGTERM.
            kill(process.processIdentifier, SIGKILL)
            os_log("ShellPath: %{public}@ timed out, using fallback search paths", log: Log.app, shell)
            return nil
        }

        guard let contents = try? String(contentsOf: output, encoding: .utf8) else {
            os_log("ShellPath: %{public}@ did not report a PATH", log: Log.app, shell)
            return nil
        }
        let directories = parse(contents)
        return directories.isEmpty ? nil : directories
    }

    static func parse(_ path: String) -> [String] {
        var seen = Set<String>()
        return path.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")
            .map(String.init)
            .filter { ($0 as NSString).isAbsolutePath && seen.insert($0).inserted }
    }

    private static func userShell() -> String {
        if let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell {
            let path = String(cString: shell)
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return "/bin/zsh"
    }
}
