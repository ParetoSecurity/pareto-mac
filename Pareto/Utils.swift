//
//  Utils.swift
//  Utils
//
//  Created by Janez Troha on 30/08/2021.
//

@preconcurrency import Foundation
import os.log
import OSAKit

enum CommandRunnerError: Swift.Error {
    case launchFailed(String)
    case timedOut
    case unsuccessfulExit(Int32)
}

private final class ProcessBox {
    var process: Process?
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func output() -> String {
        lock.lock()
        let value = String(data: data, encoding: .utf8) ?? ""
        lock.unlock()
        return value
    }
}

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func run(_ block: () -> Void) {
        lock.lock()
        guard !resumed else {
            lock.unlock()
            return
        }
        resumed = true
        lock.unlock()
        block()
    }
}

func runCMDAsync(app: String, args: [String], timeout: TimeInterval = 15.0,
                 includeStandardError: Bool = true, requireSuccessfulExit: Bool = false,
                 environment: [String: String]? = nil, directory: URL? = nil) async throws -> String
{
    let processBox = ProcessBox()
    let outputBuffer = OutputBuffer()
    let resumeGate = ResumeGate()

    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()

            @Sendable func resumeOnce(_ result: Result<String, Swift.Error>) {
                resumeGate.run {
                    continuation.resume(with: result)
                }
            }

            task.standardOutput = pipe
            if includeStandardError {
                task.standardError = pipe
            } else {
                task.standardError = FileHandle.nullDevice
            }
            task.arguments = args
            task.launchPath = app
            task.environment = environment
            task.currentDirectoryURL = directory
            task.standardInput = FileHandle.nullDevice
            processBox.process = task

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                outputBuffer.append(data)
            }

            task.terminationHandler = { process in
                pipe.fileHandleForReading.readabilityHandler = nil
                let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
                if !remaining.isEmpty {
                    outputBuffer.append(remaining)
                }
                if requireSuccessfulExit, process.terminationReason != .exit || process.terminationStatus != 0 {
                    resumeOnce(.failure(CommandRunnerError.unsuccessfulExit(process.terminationStatus)))
                } else {
                    resumeOnce(.success(outputBuffer.output()))
                }
            }

            do {
                try task.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                resumeOnce(.failure(CommandRunnerError.launchFailed(error.localizedDescription)))
                return
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                if task.isRunning {
                    resumeOnce(.failure(CommandRunnerError.timedOut))
                    task.terminate()
                }
            }
        }
    } onCancel: {
        if let process = processBox.process, process.isRunning {
            process.terminate()
        }
    }
}

enum CheckCommand {
    private static func canonicalPath(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    static func run(app: String, args: [String], homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
                    path: [String] = [], readFiles: [String] = [], readDirectories: [String] = [],
                    timeout: TimeInterval = 5, includeStandardError: Bool = false,
                    requireSuccessfulExit: Bool = true) -> String?
    {
        let home = URL(fileURLWithPath: canonicalPath(homeDirectory.path))
        let systemDirectories = ["/Library/Apple", "/Library/Developer", "/Library/Frameworks", "/Library/Python", "/Library/Ruby", "/System", "/bin", "/nix/store", "/opt/homebrew", "/opt/local", "/sbin", "/usr"]
        let toolDirectories = [".asdf", ".bun", ".cache/node/corepack", ".cargo", ".config/conda", ".config/mise", ".config/pdm", ".config/pip", ".config/pypoetry", ".deno", ".local/bin", ".local/lib", ".local/pipx", ".local/share/mise", ".local/share/pipx", ".local/share/uv", ".npm-global", ".nvm", ".pyenv", ".rbenv", ".rvm", ".volta", ".yarn", "Library/Application Support/fnm", "Library/Application Support/pdm", "Library/Application Support/pypoetry", "Library/Python", "Library/pnpm", "anaconda3", "miniconda3", "miniforge3"]
        let configFiles = [".bundle/config", ".condarc", ".config/git/config", ".gitconfig", ".npmrc", ".python-version", ".ruby-version", ".tool-versions", ".yarnrc.yml"]
        let directories = systemDirectories + toolDirectories.map { home.appendingPathComponent($0).path } + readDirectories
        let systemFiles = ["/etc/bashrc", "/etc/passwd", "/etc/paths", "/etc/profile", "/etc/zprofile", "/etc/zshenv", "/etc/zshrc"].map(canonicalPath)
        var files = ["/", "/dev/null", "/dev/random", "/dev/urandom", "/dev/zero", app, canonicalPath(app)]
            + systemFiles + configFiles.map { home.appendingPathComponent($0).path }
            + readFiles.map(canonicalPath)
        // Runtimes need to traverse installation paths, without reading sibling files.
        var parents = Set<String>()
        for path in directories + files {
            let components = (path as NSString).pathComponents
            for count in 1 ..< components.count {
                parents.insert(NSString.path(withComponents: Array(components.prefix(count))))
            }
        }
        files += parents.sorted()
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("pareto-check-\(UUID().uuidString)")
        guard (try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: false,
                                                        attributes: [.posixPermissions: 0o700])) != nil
        else {
            return nil
        }
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let temporaryPath = canonicalPath(temporaryDirectory.path)
        var profile = """
        (version 1)
        (deny default)
        (allow process-exec process-fork sysctl-read file-read-metadata)
        (allow file-write-data (literal "/dev/null"))
        (allow mach-lookup (global-name "com.apple.system.opendirectoryd.libinfo"))
        (allow file-read* file-write* (subpath (param "TMPDIR")))
        """
        var parameters = ["-D", "TMPDIR=\(temporaryPath)"]
        for (index, directory) in directories.enumerated() {
            profile += "\n(allow file-read* file-map-executable (subpath (param \"DIR\(index)\")))"
            parameters += ["-D", "DIR\(index)=\(directory)"]
        }
        for (index, file) in files.enumerated() {
            profile += "\n(allow file-read* file-map-executable (literal (param \"FILE\(index)\")))"
            parameters += ["-D", "FILE\(index)=\(file)"]
        }

        let environment = ["HOME": home.path, "LANG": "C", "LOGNAME": NSUserName(), "PATH": (path + ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]).joined(separator: ":"), "TMPDIR": temporaryPath + "/", "USER": NSUserName()]
        let output = OSAllocatedUnfairLock<String?>(initialState: nil)
        let done = DispatchSemaphore(value: 0)
        let sandboxArgs = parameters + ["-p", profile, app] + args
        let task = Task.detached {
            defer { done.signal() }
            let result = try? await runCMDAsync(
                app: "/usr/bin/sandbox-exec", args: sandboxArgs,
                timeout: timeout, includeStandardError: includeStandardError,
                requireSuccessfulExit: requireSuccessfulExit, environment: environment, directory: home
            )
            output.withLock { $0 = result }
        }
        guard done.wait(timeout: .now() + timeout + 1) == .success else {
            task.cancel()
            return nil
        }
        return output.withLock { $0 }
    }
}

func runCMD(app: String, args: [String], environment: [String: String]? = nil) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = args
    task.launchPath = app
    if let environment {
        task.environment = environment
    }
    do {
        try task.run()
    } catch {
        os_log("Failed to launch %{public}@: %{public}@", log: Log.app, app, error.localizedDescription)
        return ""
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}

func runShell(args: [String]) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.arguments = args
    task.standardInput = nil
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    do {
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    } catch {
        return error.localizedDescription
    }
}

func runOSAAsync(appleScript: String, timeout: TimeInterval = 10.0) async -> String? {
    let resumeGate = ResumeGate()

    return await withCheckedContinuation { continuation in
        let timeoutWork = DispatchWorkItem {
            os_log("NSAppleScript timed out after %{public}f seconds", timeout)
            resumeGate.run {
                continuation.resume(returning: nil)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: appleScript) else {
                os_log("NSAppleScript init failed")
                timeoutWork.cancel()
                resumeGate.run { continuation.resume(returning: nil) }
                return
            }
            let result = script.executeAndReturnError(&error)
            timeoutWork.cancel()
            if let error {
                os_log("NSAppleScript error: %{public}s", error.debugDescription)
                resumeGate.run { continuation.resume(returning: nil) }
                return
            }

            if let s = result.stringValue {
                resumeGate.run { continuation.resume(returning: s) }
                return
            }

            let rawData = result.data
            if let text = String(data: rawData, encoding: .utf8) ?? String(data: rawData, encoding: .macOSRoman) {
                resumeGate.run { continuation.resume(returning: text) }
                return
            }

            resumeGate.run { continuation.resume(returning: result.description) }
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
    }
}

func runOSA(appleScript: String, timeout: TimeInterval = 10.0) -> String? {
    let semaphore = DispatchSemaphore(value: 0)
    var scriptResult: String?

    DispatchQueue.global(qos: .userInitiated).async {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: appleScript) else {
            os_log("NSAppleScript init failed")
            semaphore.signal()
            return
        }
        let result = script.executeAndReturnError(&error)
        if let error {
            os_log("NSAppleScript error: %{public}s", error.debugDescription)
            semaphore.signal()
            return
        }

        if let s = result.stringValue {
            scriptResult = s
        } else {
            let rawData = result.data
            if let text = String(data: rawData, encoding: .utf8) ?? String(data: rawData, encoding: .macOSRoman) {
                scriptResult = text
            } else {
                scriptResult = result.description
            }
        }
        semaphore.signal()
    }

    if semaphore.wait(timeout: .now() + timeout) == .timedOut {
        os_log("NSAppleScript timed out after %{public}f seconds", timeout)
        return nil
    }

    return scriptResult
}

func lsof(withCommand cmd: String, withPort port: Int) -> Bool {
    let out = runCMD(app: "/usr/sbin/lsof", args: ["-i", "TCP:\(port)", "-P", "+L", "-O", "-T", "+c", "0", "-nPM"])
    for line in out.components(separatedBy: "\n") {
        if line.hasPrefix(cmd), line.hasSuffix("*:\(port)") {
            return true
        }
    }
    return false
}

func memoize<Input: Hashable, Output>(_ function: @escaping (Input) -> Output) -> (Input) -> Output {
    // our item cache
    var storage = [Input: Output]()

    // send back a new closure that does our calculation
    return { input in
        if let cached = storage[input] {
            return cached
        }

        let result = function(input)
        storage[input] = result
        return result
    }
}

func viaEdgeCache(_ url: String) -> String {
    if AppInfo.Flags.useEdgeCache {
        return url.replacingOccurrences(of: "https://", with: "https://pareto-cache.team-niteo.workers.dev/")
    }
    return url
}
